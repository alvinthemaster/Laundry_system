class ChatRoomEntity {
  final String bookingId;
  final String customerId;
  final String driverId;
  final String customerName;
  final String driverName;
  final bool locked;
  final DateTime createdAt;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastSenderId;
  final String? lastSenderRole;
  final DateTime? customerLastReadAt;
  final DateTime? driverLastReadAt;

  const ChatRoomEntity({
    required this.bookingId,
    required this.customerId,
    required this.driverId,
    required this.customerName,
    required this.driverName,
    required this.locked,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageAt,
    this.lastSenderId,
    this.lastSenderRole,
    this.customerLastReadAt,
    this.driverLastReadAt,
  });
}
