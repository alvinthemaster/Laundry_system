class UserEntity {
  final String uid;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String address;
  final String role;
  final DateTime createdAt;
  
  const UserEntity({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.address,
    required this.role,
    required this.createdAt,
  });
}
