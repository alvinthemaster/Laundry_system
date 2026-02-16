class BookingEntity {
  final String bookingId;
  final String userId;
  final String serviceType;
  final double weight;
  final double bookingFee;
  final double servicePrice;
  final double totalAmount;
  final DateTime pickupDate;
  final String pickupTime;
  final String status;
  final String paymentStatus;
  final String? specialInstructions;
  final DateTime createdAt;
  
  const BookingEntity({
    required this.bookingId,
    required this.userId,
    required this.serviceType,
    required this.weight,
    required this.bookingFee,
    required this.servicePrice,
    required this.totalAmount,
    required this.pickupDate,
    required this.pickupTime,
    required this.status,
    required this.paymentStatus,
    this.specialInstructions,
    required this.createdAt,
  });
}
