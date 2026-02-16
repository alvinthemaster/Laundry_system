import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';

class BookingModel extends BookingEntity {
  const BookingModel({
    required super.bookingId,
    required super.userId,
    required super.serviceType,
    required super.weight,
    required super.bookingFee,
    required super.servicePrice,
    required super.totalAmount,
    required super.pickupDate,
    required super.pickupTime,
    required super.status,
    required super.paymentStatus,
    super.specialInstructions,
    required super.createdAt,
  });
  
  // From JSON
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      bookingId: json['bookingId'] as String,
      userId: json['userId'] as String,
      serviceType: json['serviceType'] as String,
      weight: (json['weight'] as num).toDouble(),
      bookingFee: (json['bookingFee'] as num).toDouble(),
      servicePrice: (json['servicePrice'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      pickupDate: DateTime.parse(json['pickupDate'] as String),
      pickupTime: json['pickupTime'] as String,
      status: json['status'] as String,
      paymentStatus: json['paymentStatus'] as String,
      specialInstructions: json['specialInstructions'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
  
  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'serviceType': serviceType,
      'weight': weight,
      'bookingFee': bookingFee,
      'servicePrice': servicePrice,
      'totalAmount': totalAmount,
      'pickupDate': pickupDate.toIso8601String(),
      'pickupTime': pickupTime,
      'status': status,
      'paymentStatus': paymentStatus,
      'specialInstructions': specialInstructions,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  // From Entity
  factory BookingModel.fromEntity(BookingEntity entity) {
    return BookingModel(
      bookingId: entity.bookingId,
      userId: entity.userId,
      serviceType: entity.serviceType,
      weight: entity.weight,
      bookingFee: entity.bookingFee,
      servicePrice: entity.servicePrice,
      totalAmount: entity.totalAmount,
      pickupDate: entity.pickupDate,
      pickupTime: entity.pickupTime,
      status: entity.status,
      paymentStatus: entity.paymentStatus,
      specialInstructions: entity.specialInstructions,
      createdAt: entity.createdAt,
    );
  }
}
