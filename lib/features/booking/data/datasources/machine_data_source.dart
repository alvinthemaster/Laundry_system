import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_system/features/booking/data/models/machine_model.dart';
import 'package:laundry_system/features/booking/data/models/machine_slot_model.dart';

abstract class MachineDataSource {
  Future<List<MachineModel>> getMachines();
  Future<List<MachineModel>> getMachinesByType(String machineType);
  Future<List<MachineSlotModel>> getSlotsForMachine({
    required String machineId,
    required String date,
  });
  Future<List<MachineSlotModel>> getAvailableSlotsForDate({
    required String date,
    String? machineType,
  });
  Stream<List<MachineSlotModel>> watchSlotsForDate({
    required String date,
    String? machineType,
  });
  Future<bool> bookSlot({
    required String slotId,
    required String machineId,
    required String bookingId,
  });
  Future<void> releaseSlot({required String slotId});
  Future<void> ensureSlotsExist({
    required String machineId,
    required String date,
  });
  Future<void> seedMachines();
}

class MachineDataSourceImpl implements MachineDataSource {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  // Operating hours: 8 AM to 8 PM, 1-hour slots
  static const int _operatingStartHour = 8;
  static const int _operatingEndHour = 20; // 8 PM

  MachineDataSourceImpl({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();

  @override
  Future<List<MachineModel>> getMachines() async {
    try {
      final snapshot = await _firestore.collection('machines').get();
      return snapshot.docs
          .map((doc) => MachineModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch machines: $e');
    }
  }

  @override
  Future<List<MachineModel>> getMachinesByType(String machineType) async {
    try {
      // Query by machineType only, then filter isActive client-side
      // (avoids composite index requirement and handles both isActive + status schemas)
      final snapshot = await _firestore
          .collection('machines')
          .where('machineType', isEqualTo: machineType)
          .get();
      return snapshot.docs
          .map((doc) => MachineModel.fromFirestore(doc))
          .where((m) => m.isAvailable)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch machines by type: $e');
    }
  }

  @override
  Future<List<MachineSlotModel>> getSlotsForMachine({
    required String machineId,
    required String date,
  }) async {
    try {
      // Query only by machineId to avoid composite index.
      // Filter by date client-side — handles both Timestamp and String date fields.
      final snapshot = await _firestore
          .collection('machine_slots')
          .where('machineId', isEqualTo: machineId)
          .get();
      final slots = snapshot.docs
          .map((doc) => MachineSlotModel.fromFirestore(doc))
          .where((slot) => slot.date == date)
          .toList();
      slots.sort((a, b) => a.startTime.compareTo(b.startTime));
      return slots;
    } catch (e) {
      throw Exception('Failed to fetch slots: $e');
    }
  }

  @override
  Future<List<MachineSlotModel>> getAvailableSlotsForDate({
    required String date,
    String? machineType,
  }) async {
    try {
      final machines = machineType != null
          ? await getMachinesByType(machineType)
          : await getMachines();

      final availableMachines = machines.where((m) => m.isAvailable).toList();

      // Read slots for all available machines — NO writes (customers read-only)
      final List<MachineSlotModel> allSlots = [];
      for (final machine in availableMachines) {
        final slots = await getSlotsForMachine(
          machineId: machine.machineId,
          date: date,
        );
        allSlots.addAll(slots);
      }
      return allSlots;
    } catch (e) {
      throw Exception('Failed to fetch available slots: $e');
    }
  }

  @override
  Stream<List<MachineSlotModel>> watchSlotsForDate({
    required String date,
    String? machineType,
  }) {
    // Parse the date string to build a Timestamp range for the query.
    // Handles slots stored with Timestamp date fields (existing Firestore schema).
    final parts = date.split('-');
    final dayStart = DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    final startTs = Timestamp.fromDate(dayStart);
    final endTs = Timestamp.fromDate(dayEnd);

    // Query using a range on `date` to match both Timestamp and legacy data.
    // Falls back to client-side string filter via fromFirestore conversion.
    final query = _firestore
        .collection('machine_slots')
        .where('date', isGreaterThanOrEqualTo: startTs)
        .where('date', isLessThan: endTs);

    return query.snapshots().asyncMap((snapshot) async {
      final slots = snapshot.docs
          .map((doc) => MachineSlotModel.fromFirestore(doc))
          // Also filter by parsed date string to handle string-stored dates
          .where((s) => s.date == date || s.date.isEmpty)
          .toList();

      if (machineType != null) {
        final machines = await getMachinesByType(machineType);
        final machineIds = machines.map((m) => m.machineId).toSet();
        final filtered = slots.where((s) => machineIds.contains(s.machineId)).toList();
        filtered.sort((a, b) {
          final cmp = a.machineId.compareTo(b.machineId);
          return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
        });
        return filtered;
      }

      slots.sort((a, b) {
        final cmp = a.machineId.compareTo(b.machineId);
        return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
      });
      return slots;
    });
  }

  @override
  Future<bool> bookSlot({
    required String slotId,
    required String machineId,
    required String bookingId,
  }) async {
    try {
      // Use Firestore transaction to prevent double booking
      return await _firestore.runTransaction<bool>((transaction) async {
        final slotRef = _firestore.collection('machine_slots').doc(slotId);
        final slotDoc = await transaction.get(slotRef);

        if (!slotDoc.exists) {
          throw Exception('Slot does not exist');
        }

        final data = slotDoc.data()!;
        final isAvailable = data['isAvailable'] as bool? ?? false;

        if (!isAvailable) {
          return false; // Slot already booked
        }

        // Atomically mark the slot as booked
        transaction.update(slotRef, {
          'isAvailable': false,
          'status': 'booked',
          'bookingId': bookingId,
          'bookedAt': DateTime.now().toIso8601String(),
        });

        return true;
      });
    } catch (e) {
      if (e.toString().contains('Slot does not exist')) rethrow;
      throw Exception('Failed to book slot: $e');
    }
  }

  @override
  Future<void> releaseSlot({required String slotId}) async {
    try {
      await _firestore.collection('machine_slots').doc(slotId).update({
        'isAvailable': true,
        'status': 'available',
        'bookingId': FieldValue.delete(),
        'bookedAt': FieldValue.delete(),
      });
    } catch (e) {
      throw Exception('Failed to release slot: $e');
    }
  }

  @override
  Future<void> ensureSlotsExist({
    required String machineId,
    required String date,
  }) async {
    try {
      // Check if slots already exist for this machine + date
      final existing = await _firestore
          .collection('machine_slots')
          .where('machineId', isEqualTo: machineId)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) return; // Slots already generated

      // Generate hourly slots for the operating hours
      final batch = _firestore.batch();
      int hour = _operatingStartHour;

      while (hour < _operatingEndHour) {
        final startTime =
            '${hour.toString().padLeft(2, '0')}:00';
        final endHour = hour + 1;
        final endTime =
            '${endHour.toString().padLeft(2, '0')}:00';
        final slotId = _uuid.v4();

        final slotRef = _firestore.collection('machine_slots').doc(slotId);
        batch.set(slotRef, {
          'slotId': slotId,
          'machineId': machineId,
          'date': date,
          'startTime': startTime,
          'endTime': endTime,
          'isAvailable': true,
          'status': 'available',
        });

        // Add buffer: skip the buffer minutes by moving to next hour
        hour++;
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to ensure slots exist: $e');
    }
  }

  @override
  Future<void> seedMachines() async {
    try {
      final existing = await _firestore.collection('machines').limit(1).get();
      if (existing.docs.isNotEmpty) return; // Already seeded

      final machines = [
        MachineModel(
          machineId: _uuid.v4(),
          machineName: 'Washer 1',
          machineType: 'wash',
          status: 'available',
        ),
        MachineModel(
          machineId: _uuid.v4(),
          machineName: 'Washer 2',
          machineType: 'wash',
          status: 'available',
        ),
        MachineModel(
          machineId: _uuid.v4(),
          machineName: 'Dryer 1',
          machineType: 'dry',
          status: 'available',
        ),
        MachineModel(
          machineId: _uuid.v4(),
          machineName: 'Dryer 2',
          machineType: 'dry',
          status: 'available',
        ),
        MachineModel(
          machineId: _uuid.v4(),
          machineName: 'Combo 1',
          machineType: 'wash_dry',
          status: 'available',
        ),
      ];

      final batch = _firestore.batch();
      for (final machine in machines) {
        final ref = _firestore.collection('machines').doc(machine.machineId);
        batch.set(ref, machine.toJson());
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Permission denied - machines need to be created by admin
        // This is expected if rules don't allow user to write
        print('Machines need to be created by admin. Permission denied for user seeding.');
        return; // Don't throw, just return silently
      }
      throw Exception('Failed to seed machines: ${e.message}');
    } catch (e) {
      throw Exception('Failed to seed machines: $e');
    }
  }
}
