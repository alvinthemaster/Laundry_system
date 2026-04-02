import 'package:cloud_firestore/cloud_firestore.dart';

class MachineModel {
  final String machineId;
  final String machineName;
  final String machineType; // wash, dry, wash_dry
  final String status; // available, maintenance, out_of_order
  final bool isActive; // Firestore uses isActive boolean

  const MachineModel({
    required this.machineId,
    required this.machineName,
    required this.machineType,
    this.status = 'available',
    this.isActive = true,
  });

  factory MachineModel.fromJson(Map<String, dynamic> json) {
    // Support both 'isActive' (actual Firestore schema) and 'status' (legacy)
    final isActiveField = json['isActive'] as bool?;
    final statusField = json['status'] as String?;
    final resolvedStatus = statusField ?? (isActiveField == true ? 'available' : 'inactive');
    final resolvedIsActive = isActiveField ?? (resolvedStatus == 'available');

    return MachineModel(
      machineId: json['machineId'] as String,
      machineName: json['machineName'] as String,
      machineType: json['machineType'] as String,
      status: resolvedStatus,
      isActive: resolvedIsActive,
    );
  }

  factory MachineModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MachineModel.fromJson({...data, 'machineId': doc.id});
  }

  Map<String, dynamic> toJson() {
    return {
      'machineId': machineId,
      'machineName': machineName,
      'machineType': machineType,
      'status': status,
      'isActive': isActive,
    };
  }

  // Available if the isActive flag is true and not in maintenance
  bool get isAvailable => isActive && status != 'maintenance';
}
