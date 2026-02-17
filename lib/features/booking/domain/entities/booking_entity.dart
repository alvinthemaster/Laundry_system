class BookingEntity {
  final String bookingId;
  final String userId;
  
  // NEW: Multiple categories support
  final List<Map<String, dynamic>> categories; // [{ name, weight, computedPrice }]
  final double categoryTotal; // Sum of all category prices
  
  final List<String> selectedServices; // Multiple services
  final List<Map<String, dynamic>> selectedAddOns; // Optional add-ons
  final double weight; // Total weight (deprecated, kept for compatibility)
  final double servicesTotal; // Total from selected services
  final double addOnsTotal; // Total from add-ons
  final double bookingFee;
  final double totalAmount; // Grand total
  
  // NEW: Delivery/Pickup logic
  final String bookingType; // 'pickup' or 'delivery'
  final String? deliveryAddress; // Required if bookingType = 'delivery'
  
  final DateTime? pickupDate; // Nullable: only for pickup type
  final String? pickupTime; // Nullable: only for pickup type
  
  final String status;
  final String paymentStatus;
  final String? paymentMethod;
  final String? specialInstructions;
  final DateTime createdAt;
  
  // Legacy fields for backwards compatibility (deprecated)
  @Deprecated('Use categories instead')
  final String? category;
  @Deprecated('Use categories instead')
  final String? serviceType;
  @Deprecated('Use servicesTotal instead')
  final double? servicePrice;
  @Deprecated('Use categoryTotal instead')
  final double? basePrice;
  
  const BookingEntity({
    required this.bookingId,
    required this.userId,
    required this.categories,
    required this.categoryTotal,
    required this.selectedServices,
    required this.selectedAddOns,
    required this.weight,
    required this.servicesTotal,
    required this.addOnsTotal,
    required this.bookingFee,
    required this.totalAmount,
    required this.bookingType,
    this.deliveryAddress,
    this.pickupDate,
    this.pickupTime,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.specialInstructions,
    required this.createdAt,
    this.category,
    this.serviceType,
    this.servicePrice,
    this.basePrice,
  });
}
