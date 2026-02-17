import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';

class BookingModel extends BookingEntity {
  const BookingModel({
    required super.bookingId,
    required super.userId,
    required super.categories,
    required super.categoryTotal,
    required super.selectedServices,
    required super.selectedAddOns,
    required super.weight,
    required super.servicesTotal,
    required super.addOnsTotal,
    required super.bookingFee,
    required super.totalAmount,
    required super.bookingType,
    super.deliveryAddress,
    super.pickupDate,
    super.pickupTime,
    required super.status,
    required super.paymentStatus,
    super.paymentMethod,
    super.specialInstructions,
    required super.createdAt,
    super.category,
    super.serviceType,
    super.servicePrice,
    super.basePrice,
  });
  
  // From JSON with backwards compatibility
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    // Handle legacy bookings that don't have new fields
    final categories = json['categories'] != null
        ? List<Map<String, dynamic>>.from(
            (json['categories'] as List).map((e) => Map<String, dynamic>.from(e as Map))
          )
        : [
            {
              'name': json['category'] as String? ?? 'Clothes',
              'weight': (json['weight'] as num?)?.toDouble() ?? 0.0,
              'computedPrice': (json['basePrice'] as num?)?.toDouble() ?? 200.0,
            }
          ];
    
    final categoryTotal = json['categoryTotal'] != null
        ? (json['categoryTotal'] as num).toDouble()
        : (json['basePrice'] as num?)?.toDouble() ?? 200.0;
    
    final selectedServices = json['selectedServices'] != null 
        ? List<String>.from(json['selectedServices'] as List)
        : [json['serviceType'] as String? ?? 'Wash & Fold'];
    
    final selectedAddOns = json['selectedAddOns'] != null
        ? List<Map<String, dynamic>>.from(
            (json['selectedAddOns'] as List).map((e) => Map<String, dynamic>.from(e as Map))
          )
        : <Map<String, dynamic>>[];
    
    final servicesTotal = json['servicesTotal'] != null
        ? (json['servicesTotal'] as num).toDouble()
        : (json['servicePrice'] as num?)?.toDouble() ?? 0.0;
    
    final addOnsTotal = json['addOnsTotal'] != null
        ? (json['addOnsTotal'] as num).toDouble()
        : 0.0;
    
    final bookingType = json['bookingType'] as String? ?? 'pickup';
    
    return BookingModel(
      bookingId: json['bookingId'] as String,
      userId: json['userId'] as String,
      categories: categories,
      categoryTotal: categoryTotal,
      selectedServices: selectedServices,
      selectedAddOns: selectedAddOns,
      weight: (json['weight'] as num).toDouble(),
      servicesTotal: servicesTotal,
      addOnsTotal: addOnsTotal,
      bookingFee: (json['bookingFee'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      bookingType: bookingType,
      deliveryAddress: json['deliveryAddress'] as String?,
      pickupDate: json['pickupDate'] != null ? DateTime.parse(json['pickupDate'] as String) : null,
      pickupTime: json['pickupTime'] as String?,
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String,
      paymentMethod: json['paymentMethod'] as String?,
      specialInstructions: json['specialInstructions'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      category: json['category'] as String?,
      serviceType: json['serviceType'] as String?,
      servicePrice: json['servicePrice'] != null ? (json['servicePrice'] as num).toDouble() : null,
      basePrice: json['basePrice'] != null ? (json['basePrice'] as num).toDouble() : null,
    );
  }
  
  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'categories': categories,
      'categoryTotal': categoryTotal,
      'selectedServices': selectedServices,
      'selectedAddOns': selectedAddOns,
      'weight': weight,
      'servicesTotal': servicesTotal,
      'addOnsTotal': addOnsTotal,
      'bookingFee': bookingFee,
      'totalAmount': totalAmount,
      'bookingType': bookingType,
      'deliveryAddress': deliveryAddress,
      'pickupDate': pickupDate?.toIso8601String(),
      'pickupTime': pickupTime,
      'status': status,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'specialInstructions': specialInstructions,
      'createdAt': createdAt.toIso8601String(),
      // Legacy fields for backwards compatibility
      'category': categories.isNotEmpty ? categories.first['name'] : null,
      'serviceType': selectedServices.isNotEmpty ? selectedServices.first : null,
      'servicePrice': servicesTotal,
      'basePrice': categoryTotal,
    };
  }
  
  // From Entity
  factory BookingModel.fromEntity(BookingEntity entity) {
    return BookingModel(
      bookingId: entity.bookingId,
      userId: entity.userId,
      categories: entity.categories,
      categoryTotal: entity.categoryTotal,
      selectedServices: entity.selectedServices,
      selectedAddOns: entity.selectedAddOns,
      weight: entity.weight,
      servicesTotal: entity.servicesTotal,
      addOnsTotal: entity.addOnsTotal,
      bookingFee: entity.bookingFee,
      totalAmount: entity.totalAmount,
      bookingType: entity.bookingType,
      deliveryAddress: entity.deliveryAddress,
      pickupDate: entity.pickupDate,
      pickupTime: entity.pickupTime,
      status: entity.status,
      paymentStatus: entity.paymentStatus,
      paymentMethod: entity.paymentMethod,
      specialInstructions: entity.specialInstructions,
      createdAt: entity.createdAt,
      category: entity.category,
      serviceType: entity.serviceType,
      servicePrice: entity.servicePrice,
      basePrice: entity.basePrice,
    );
  }
}

