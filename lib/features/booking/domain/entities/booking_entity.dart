class BookingEntity {
  final String bookingId;
  final String userId;

  final List<Map<String, dynamic>> categories; // [{ name, weight, computedPrice }]
  final double categoryTotal;

  final List<Map<String, dynamic>> selectedAddOns;
  final double addOnsTotal;
  final double bookingFee;
  final double totalAmount;

  final String bookingType; // 'pickup' or 'delivery'
  final String? deliveryAddress;

  final DateTime? pickupDate;
  final String? timeSlot;    // machine slot time (original, never changed)
  final String? pickupTime;  // customer-selected pickup time (set on reschedule)

  final String? serviceType; // 'Wash', 'Dry', or 'Wash & Dry'

  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? specialInstructions;
  final DateTime createdAt;

  // Machine & slot selection
  final String? machineId;
  final String? machineName;
  final String? slotId;
  final double slotFee;
  final double deliveryFee;

  // Customer display name (stored for admin visibility)
  final String? customerName;
  final String? customerPhone;

  // Driver info (set by admin/driver for delivery bookings)
  final String? driverId;
  final String? driverName;
  final String? driverContact;
  final bool? driverAccepted; // null = pending, true = accepted, false = declined

  // Delivery proof photo URL (set when driver generates receipt)
  final String? deliveryProofUrl;

  // Customer GCash payment proof screenshot (base64 data URI on Spark plan)
  final String? paymentProofUrl;

  // Second/full payment proof screenshot for follow-up payment flow.
  final String? secondPaymentProofUrl;

  const BookingEntity({
    required this.bookingId,
    required this.userId,
    required this.categories,
    required this.categoryTotal,
    required this.selectedAddOns,
    required this.addOnsTotal,
    required this.bookingFee,
    required this.totalAmount,
    required this.bookingType,
    this.deliveryAddress,
    this.pickupDate,
    this.timeSlot,
    this.pickupTime,
    this.serviceType,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.specialInstructions,
    required this.createdAt,
    this.machineId,
    this.machineName,
    this.slotId,
    this.slotFee = 0.0,
    this.deliveryFee = 0.0,
    this.customerName,
    this.customerPhone,
    this.driverId,
    this.driverName,
    this.driverContact,
    this.driverAccepted,
    this.deliveryProofUrl,
    this.paymentProofUrl,
    this.secondPaymentProofUrl,
  });
}
