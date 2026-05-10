import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';

class ReceiptModel extends ReceiptEntity {
  const ReceiptModel({
    required super.receiptId,
    required super.userId,
    required super.bookingId,
    super.machineId,
    super.machineName,
    super.timeSlot,
    super.bookingDate,
    super.bookingType,
    super.serviceType,
    super.customerName,
    super.driverName,
    super.deliveryAddress,
    super.deliveryProofUrl,
    super.categories,
    super.addOns,
    required super.totalAmount,
    super.slotFee,
    super.deliveryFee,
    super.bookingFee,
    super.addOnsTotal,
    required super.status,
    super.paymentMethod,
    required super.createdAt,
  });

  factory ReceiptModel.fromJson(Map<String, dynamic> json) {
    final categories = json['categories'] != null
        ? List<Map<String, dynamic>>.from(
            (json['categories'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];

    final addOns = json['addOns'] != null
        ? List<Map<String, dynamic>>.from(
            (json['addOns'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map)))
        : <Map<String, dynamic>>[];

    DateTime? bookingDate;
    if (json['bookingDate'] != null) {
      if (json['bookingDate'] is Timestamp) {
        bookingDate = (json['bookingDate'] as Timestamp).toDate();
      } else if (json['bookingDate'] is String) {
        bookingDate = DateTime.tryParse(json['bookingDate'] as String);
      }
    }

    DateTime createdAt;
    if (json['createdAt'] is Timestamp) {
      createdAt = (json['createdAt'] as Timestamp).toDate();
    } else if (json['createdAt'] is String) {
      createdAt = DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return ReceiptModel(
      receiptId: json['receiptId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      bookingId: json['bookingId'] as String? ?? '',
      machineId: json['machineId'] as String?,
      machineName: json['machineName'] as String?,
      timeSlot: json['timeSlot'] as String?,
      bookingDate: bookingDate,
      bookingType: json['bookingType'] as String?,
      serviceType: json['serviceType'] as String?,
      customerName: json['customerName'] as String?,
      driverName: json['driverName'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      deliveryProofUrl: json['deliveryProofUrl'] as String?,
      categories: categories,
      addOns: addOns,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      slotFee: (json['slotFee'] as num?)?.toDouble() ?? 0.0,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      bookingFee: (json['bookingFee'] as num?)?.toDouble() ?? 0.0,
      addOnsTotal: (json['addOnsTotal'] as num?)?.toDouble() ?? 0.0,
      status: json['paymentStatus'] as String?
          ?? json['status'] as String?
          ?? 'Unpaid',
      paymentMethod: json['paymentMethod'] as String?,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiptId': receiptId,
      'userId': userId,
      'bookingId': bookingId,
      if (machineId != null) 'machineId': machineId,
      if (machineName != null) 'machineName': machineName,
      if (timeSlot != null) 'timeSlot': timeSlot,
      if (bookingDate != null) 'bookingDate': bookingDate!.toIso8601String(),
      if (bookingType != null) 'bookingType': bookingType,
      if (serviceType != null) 'serviceType': serviceType,
      if (customerName != null) 'customerName': customerName,
      if (driverName != null) 'driverName': driverName,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress,
      if (deliveryProofUrl != null) 'deliveryProofUrl': deliveryProofUrl,
      'categories': categories,
      'addOns': addOns,
      'totalAmount': totalAmount,
      'slotFee': slotFee,
      'deliveryFee': deliveryFee,
      'bookingFee': bookingFee,
      'addOnsTotal': addOnsTotal,
      'status': status,
      if (paymentMethod != null) 'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
