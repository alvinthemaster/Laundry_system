class ChatMessageEntity {
  final String messageId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'driver' or 'customer'
  final String text;
  final DateTime sentAt;

  const ChatMessageEntity({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.sentAt,
  });
}
