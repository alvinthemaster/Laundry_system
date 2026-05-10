class ReceiptEntity {
  final String receiptId;
  final String userId;
  final String bookingId;
  final String? machineId;
  final String? machineName;
  final String? timeSlot;
  final DateTime? bookingDate;
  final String? bookingType;
  final String? serviceType;

  // People
  final String? customerName;
  final String? driverName;
  final String? deliveryAddress;

  // Delivery proof photo uploaded by driver
  final String? deliveryProofUrl;

  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> addOns;

  final double totalAmount;
  final double slotFee;
  final double deliveryFee;
  final double bookingFee;
  final double addOnsTotal;

  final String status; // Paid, Unpaid, Half Paid
  final String? paymentMethod;
  final DateTime createdAt;

  const ReceiptEntity({
    required this.receiptId,
    required this.userId,
    required this.bookingId,
    this.machineId,
    this.machineName,
    this.timeSlot,
    this.bookingDate,
    this.bookingType,
    this.serviceType,
    this.customerName,
    this.driverName,
    this.deliveryAddress,
    this.deliveryProofUrl,
    this.categories = const [],
    this.addOns = const [],
    required this.totalAmount,
    this.slotFee = 0.0,
    this.deliveryFee = 0.0,
    this.bookingFee = 0.0,
    this.addOnsTotal = 0.0,
    required this.status,
    this.paymentMethod,
    required this.createdAt,
  });
}
