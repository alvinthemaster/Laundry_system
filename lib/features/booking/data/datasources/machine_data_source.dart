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

  // ── Quota-saving in-memory caches (process lifetime) ──────────────────────
  /// Prevents seedMachines from hitting Firestore on every provider access.
  static bool _machinesSeeded = false;

  /// bookingIds confirmed terminal (Completed / Cancelled). Once known, never
  /// re-read — the status won't go backwards.
  static final Set<String> _terminalBookingIds = {};

  /// machineId|date keys for which slots have already been ensured this session.
  static final Set<String> _ensuredSlotKeys = {};

  /// Cached machine ids per machineType for use inside stream asyncMap so we
  /// don't hit Firestore on every stream event.
  static final Map<String, Set<String>> _machineIdsByType = {};
  // ──────────────────────────────────────────────────────────────────────────

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
      final machines = snapshot.docs
          .map((doc) => MachineModel.fromFirestore(doc))
          .where((m) => m.isAvailable)
          .toList();
      // Cache machine ids for this type so the stream asyncMap doesn't
      // re-query Firestore on every emission.
      _machineIdsByType[machineType] = machines.map((m) => m.machineId).toSet();
      return machines;
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
      // Heal stale slots: release slots whose bookings are already terminal.
      return await _releaseStaleSlots(slots);
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
        // Use in-memory cache so we don't hit Firestore on every stream event.
        // If cache is warm (populated by a prior getMachinesByType call), use it;
        // otherwise fall back to a one-time fetch and populate the cache.
        Set<String> machineIds;
        if (_machineIdsByType.containsKey(machineType)) {
          machineIds = _machineIdsByType[machineType]!;
        } else {
          final machines = await getMachinesByType(machineType); // populates cache
          machineIds = machines.map((m) => m.machineId).toSet();
        }
        var filtered = slots.where((s) => machineIds.contains(s.machineId)).toList();
        filtered.sort((a, b) {
          final cmp = a.machineId.compareTo(b.machineId);
          return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
        });
        // NOTE: _releaseStaleSlots is intentionally NOT called here.
        // Calling it inside the stream causes a read loop: release write →
        // stream fires again → reads bookings again → repeat.
        // Stale-slot healing happens once in getSlotsForMachine (one-time fetch).
        return filtered;
      }

      slots.sort((a, b) {
        final cmp = a.machineId.compareTo(b.machineId);
        return cmp != 0 ? cmp : a.startTime.compareTo(b.startTime);
      });
      // NOTE: _releaseStaleSlots intentionally not called here (see above).
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

  /// Terminal booking statuses — slots associated with these should be freed.
  static const _terminalStatuses = {'Completed', 'Cancelled', 'completed', 'cancelled'};

  /// For every booked slot that has a bookingId, check whether the booking has
  /// reached a terminal state. If so, release the slot in Firestore so it
  /// becomes bookable again, and return an updated list with those slots marked
  /// as available. This heals stale slot state caused by admin-side status
  /// updates that don't touch machine_slots.
  /// Only called from getSlotsForMachine (one-time fetch), NOT from the stream,
  /// to prevent Firestore write → stream emission → re-read loops.
  Future<List<MachineSlotModel>> _releaseStaleSlots(
      List<MachineSlotModel> slots) async {
    // Collect slots that are marked as booked and have a bookingId.
    final staleCheck = slots
        .where((s) => !s.isAvailable && s.bookingId != null && s.bookingId!.isNotEmpty)
        .toList();

    if (staleCheck.isEmpty) return slots;

    // Skip bookingIds we already know are terminal (cached from prior checks).
    final unchecked = staleCheck
        .where((s) => !_terminalBookingIds.contains(s.bookingId))
        .toList();

    if (unchecked.isNotEmpty) {
      // Batch-fetch only the unchecked bookings.
      final bookingIds = unchecked.map((s) => s.bookingId!).toSet().toList();
      const chunkSize = 30;
      for (int i = 0; i < bookingIds.length; i += chunkSize) {
        final chunk = bookingIds.skip(i).take(chunkSize).toList();
        try {
          final snap = await _firestore
              .collection('bookings')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final doc in snap.docs) {
            final status = (doc.data()['status'] as String?) ?? '';
            if (_terminalStatuses.contains(status)) {
              _terminalBookingIds.add(doc.id);
            }
          }
        } catch (_) {
          // If the fetch fails, skip — better to show a slot as unavailable than crash.
        }
      }
    }

    // Determine which slots need releasing (now includes cached terminal ids).
    final toRelease = staleCheck
        .where((s) => _terminalBookingIds.contains(s.bookingId))
        .toList();

    if (toRelease.isEmpty) return slots;

    // Release in Firestore concurrently (fire-and-forget).
    await Future.wait(
      toRelease.map((s) => _firestore.collection('machine_slots').doc(s.slotId).update({
            'isAvailable': true,
            'status': 'available',
            'bookingId': FieldValue.delete(),
            'bookedAt': FieldValue.delete(),
          }).catchError((_) => null)),
    );

    // Return updated list with released slots marked available.
    final releasedIds = toRelease.map((s) => s.slotId).toSet();
    return slots.map((s) {
      if (releasedIds.contains(s.slotId)) {
        return MachineSlotModel(
          slotId: s.slotId,
          machineId: s.machineId,
          date: s.date,
          startTime: s.startTime,
          endTime: s.endTime,
          isAvailable: true,
          status: 'available',
          bookingId: null,
        );
      }
      return s;
    }).toList();
  }

  @override
  Future<void> ensureSlotsExist({
    required String machineId,
    required String date,
  }) async {
    // Skip if already ensured this session — avoids repeated Firestore reads.
    final key = '$machineId|$date';
    if (_ensuredSlotKeys.contains(key)) return;

    try {
      // Check if slots already exist for this machine + date
      // First try string-based date query
      final existing = await _firestore
          .collection('machine_slots')
          .where('machineId', isEqualTo: machineId)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        _ensuredSlotKeys.add(key); // Cache: don't re-check next time
        return;
      }

      // Also check via machineId-only query and client-side date filter
      // This handles Timestamp-stored dates that won't match string queries
      final byMachine = await _firestore
          .collection('machine_slots')
          .where('machineId', isEqualTo: machineId)
          .get();
      final hasMatchingSlots = byMachine.docs.any((doc) {
        final rawDate = (doc.data())['date'];
        String slotDate;
        if (rawDate is Timestamp) {
          final dt = rawDate.toDate().toLocal();
          slotDate =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
        } else if (rawDate is String) {
          slotDate = rawDate;
        } else {
          slotDate = '';
        }
        return slotDate == date;
      });

      if (hasMatchingSlots) {
        _ensuredSlotKeys.add(key); // Cache: don't re-check next time
        return;
      }

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
      _ensuredSlotKeys.add(key); // Cache after successful creation
    } catch (e) {
      throw Exception('Failed to ensure slots exist: $e');
    }
  }

  @override
  Future<void> seedMachines() async {
    // In-memory guard: skip Firestore check if already seeded this session.
    if (_machinesSeeded) return;
    try {
      final existing = await _firestore.collection('machines').limit(1).get();
      if (existing.docs.isNotEmpty) {
        _machinesSeeded = true;
        return;
      }

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
      _machinesSeeded = true;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Permission denied - machines need to be created by admin
        // This is expected if rules don't allow user to write
        print('Machines need to be created by admin. Permission denied for user seeding.');
        _machinesSeeded = true; // Don't retry — admin manages machines
        return; // Don't throw, just return silently
      }
      throw Exception('Failed to seed machines: ${e.message}');
    } catch (e) {
      throw Exception('Failed to seed machines: $e');
    }
  }
}
