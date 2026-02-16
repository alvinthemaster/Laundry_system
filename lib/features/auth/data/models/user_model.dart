import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/features/auth/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.fullName,
    required super.email,
    required super.phoneNumber,
    required super.address,
    required super.role,
    required super.createdAt,
  });

  /// Parse from Firestore document data.
  /// Handles `createdAt` as Timestamp, String, or null.
  factory UserModel.fromFirestore(Map<String, dynamic> json) {
    DateTime createdAt;
    final raw = json['createdAt'];
    if (raw is Timestamp) {
      createdAt = raw.toDate();
    } else if (raw is String) {
      createdAt = DateTime.tryParse(raw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return UserModel(
      uid: (json['uid'] as String?) ?? '',
      fullName: (json['fullName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phoneNumber: (json['phoneNumber'] as String?) ?? '',
      address: (json['address'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'customer',
      createdAt: createdAt,
    );
  }

  /// Serialize for Firestore write (uses FieldValue.serverTimestamp()).
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Plain JSON serialization (e.g., for local cache).
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'phoneNumber': phoneNumber,
      'address': address,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      fullName: entity.fullName,
      email: entity.email,
      phoneNumber: entity.phoneNumber,
      address: entity.address,
      role: entity.role,
      createdAt: entity.createdAt,
    );
  }
}
