import 'package:cloud_firestore/cloud_firestore.dart';

class MachineSlotModel {
  final String slotId;
  final String machineId;
  final String date; // YYYY-MM-DD
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final bool isAvailable;
  final String status; // available, booked, in_use, maintenance
  final String? bookingId; // set when slot is booked

  const MachineSlotModel({
    required this.slotId,
    required this.machineId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isAvailable,
    this.status = 'available',
    this.bookingId,
  });

  /// Converts a Firestore field (Timestamp or String) to HH:mm format
  static String _toTimeString(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (value is String) return value;
    return '';
  }

  /// Converts a Firestore field (Timestamp or String) to YYYY-MM-DD format
  static String _toDateString(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    }
    if (value is String) return value;
    return '';
  }

  factory MachineSlotModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MachineSlotModel(
      slotId: doc.id,
      machineId: data['machineId'] as String,
      date: _toDateString(data['date']),
      startTime: _toTimeString(data['startTime']),
      endTime: _toTimeString(data['endTime']),
      isAvailable: data['isAvailable'] as bool? ?? true,
      status: data['status'] as String? ?? 'available',
      bookingId: data['bookingId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slotId': slotId,
      'machineId': machineId,
      'date': date,
      'startTime': startTime,
      'endTime': endTime,
      'isAvailable': isAvailable,
      'status': status,
    };
  }

  String get timeRange => '$startTime - $endTime';
}
