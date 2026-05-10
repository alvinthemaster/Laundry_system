import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';

class BookingModel extends BookingEntity {
  const BookingModel({
    required super.bookingId,
    required super.userId,
    required super.categories,
    required super.categoryTotal,
    required super.selectedAddOns,
    required super.addOnsTotal,
    required super.bookingFee,
    required super.totalAmount,
    required super.bookingType,
    super.deliveryAddress,
    super.pickupDate,
    super.timeSlot,
    super.pickupTime,
    super.serviceType,
    required super.status,
    required super.paymentStatus,
    super.paymentMethod,
    super.specialInstructions,
    required super.createdAt,
    super.machineId,
    super.machineName,
    super.slotId,
    super.slotFee,
    super.deliveryFee,
    super.customerName,
    super.customerPhone,
    super.driverId,
    super.driverName,
    super.driverContact,
    super.driverAccepted,
    super.deliveryProofUrl,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'] != null
        ? List<Map<String, dynamic>>.from(
            (json['categories'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)))
        : [
            {
              'name': json['category'] as String? ?? 'Clothes',
              'weight': (json['weight'] as num?)?.toDouble() ?? 0.0,
              'computedPrice': (json['basePrice'] as num?)?.toDouble() ?? 0.0,
            }
          ];

    final categoryTotal = json['categoryTotal'] != null
        ? (json['categoryTotal'] as num).toDouble()
        : (json['basePrice'] as num?)?.toDouble() ?? 0.0;

    final selectedAddOns = json['selectedAddOns'] != null
        ? List<Map<String, dynamic>>.from(
            (json['selectedAddOns'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];

    final addOnsTotal = json['addOnsTotal'] != null
        ? (json['addOnsTotal'] as num).toDouble()
        : 0.0;

    // Support both new 'timeSlot' and legacy 'pickupTime' fields
    final timeSlot =
        json['timeSlot'] as String? ?? json['pickupTime'] as String?;

    return BookingModel(
      bookingId: json['bookingId'] as String,
      userId: json['userId'] as String,
      categories: categories,
      categoryTotal: categoryTotal,
      selectedAddOns: selectedAddOns,
      addOnsTotal: addOnsTotal,
      bookingFee: (json['bookingFee'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      bookingType: (json['orderType'] ?? json['bookingType']) as String? ?? 'pickup',
      deliveryAddress: json['deliveryAddress'] as String?,
      pickupDate: json['pickupDate'] != null
          ? DateTime.parse(json['pickupDate'] as String)
          : null,
      timeSlot: timeSlot,
      pickupTime: json['pickupTime'] as String?,
      serviceType: json['serviceType'] as String?,
      status: json['status'] as String? ?? 'Pending',
      paymentStatus: json['paymentStatus'] as String? ?? 'Unpaid',
      paymentMethod: json['paymentMethod'] as String?,
      specialInstructions: json['specialInstructions'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      machineId: json['machineId'] as String?,
      machineName: json['machineName'] as String?,
      slotId: json['slotId'] as String?,
      slotFee: json['slotFee'] != null
          ? (json['slotFee'] as num).toDouble()
          : 0.0,
      deliveryFee: json['deliveryFee'] != null
          ? (json['deliveryFee'] as num).toDouble()
          : 0.0,
      customerName: json['customerName'] as String?,
        customerPhone: json['customerPhone'] as String?,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      driverContact: json['driverContact'] as String?,
      driverAccepted: json['driverAccepted'] as bool?,
      deliveryProofUrl: json['deliveryProofUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'categories': categories,
      'categoryTotal': categoryTotal,
      'selectedAddOns': selectedAddOns,
      'addOnsTotal': addOnsTotal,
      'bookingFee': bookingFee,
      'totalAmount': totalAmount,
      'bookingType': bookingType,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (pickupDate != null) 'pickupDate': pickupDate!.toIso8601String(),
      if (timeSlot != null) 'timeSlot': timeSlot,
      if (pickupTime != null) 'pickupTime': pickupTime,
      if (serviceType != null) 'serviceType': serviceType,
      'status': status,
      'paymentStatus': paymentStatus,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      if (specialInstructions != null)
        'specialInstructions': specialInstructions,
      if (machineId != null) 'machineId': machineId,
      if (machineName != null) 'machineName': machineName,
      if (slotId != null) 'slotId': slotId,
      'slotFee': slotFee,
      'deliveryFee': deliveryFee,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (driverId != null) 'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (driverContact != null) 'driverContact': driverContact,
      if (driverAccepted != null) 'driverAccepted': driverAccepted,
      if (deliveryProofUrl != null) 'deliveryProofUrl': deliveryProofUrl,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BookingModel.fromEntity(BookingEntity entity) {
    return BookingModel(
      bookingId: entity.bookingId,
      userId: entity.userId,
      categories: entity.categories,
      categoryTotal: entity.categoryTotal,
      selectedAddOns: entity.selectedAddOns,
      addOnsTotal: entity.addOnsTotal,
      bookingFee: entity.bookingFee,
      totalAmount: entity.totalAmount,
      bookingType: entity.bookingType,
      deliveryAddress: entity.deliveryAddress,
      pickupDate: entity.pickupDate,
      timeSlot: entity.timeSlot,
      pickupTime: entity.pickupTime,
      serviceType: entity.serviceType,
      status: entity.status,
      paymentStatus: entity.paymentStatus,
      paymentMethod: entity.paymentMethod,
      specialInstructions: entity.specialInstructions,
      createdAt: entity.createdAt,
      machineId: entity.machineId,
      machineName: entity.machineName,
      slotId: entity.slotId,
      slotFee: entity.slotFee,
      deliveryFee: entity.deliveryFee,
      customerName: entity.customerName,
      customerPhone: entity.customerPhone,
      driverId: entity.driverId,
      driverName: entity.driverName,
      driverContact: entity.driverContact,
      driverAccepted: entity.driverAccepted,
      deliveryProofUrl: entity.deliveryProofUrl,
    );
  }
}