import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:uuid/uuid.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/services/delivery_price_service.dart';
import 'package:laundry_system/core/services/pricing_service.dart';
import 'package:laundry_system/features/booking/data/models/booking_model.dart';

abstract class BookingDataSource {
  Future<BookingModel> createBooking({
    required String userId,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> selectedAddOns,
    required String bookingType,
    String? deliveryAddress,
    DateTime? pickupDate,
    String? timeSlot,
    required String paymentMethod,
    String? specialInstructions,
    String? machineId,
    String? machineName,
    String? slotId,
    double? totalAmount,
    double? slotFee,
    double? deliveryFee,
    String? customerName,
    String? customerPhone,
    String? serviceType,
  });

  Future<List<String>> getBookedSlots({
    required DateTime date,
    required String time,
  });

  Future<List<BookingModel>> getUserBookings(String userId);
  Future<List<BookingModel>> getDriverBookings(String driverId);
  Future<void> updateDeliveryStatus({
    required String bookingId,
    required String status,
  });

  /// Uploads proof photo and creates COD receipt atomically.
  Future<void> generateDeliveryReceipt({
    required String bookingId,
    required List<int> imageBytes,
    required String imageFileName,
  });
  Future<BookingModel> getBookingById(String bookingId);
  Future<void> cancelBooking(String bookingId);
  Future<void> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
    String? newSlot,
    String? oldSlotId,
  });
  Future<void> createPaymentRecord({
    required String bookingId,
    required String userId,
    required double amount,
    required String method,
  });
  Future<void> notifyCustomerArrived({
    required String bookingId,
    required String customerId,
  });
}

class BookingDataSourceImpl implements BookingDataSource {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;
  
  BookingDataSourceImpl({
    FirebaseFirestore? firestore,
    Uuid? uuid,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = uuid ?? const Uuid();
  
  @override
  Future<BookingModel> createBooking({
    required String userId,
    required List<Map<String, dynamic>> categories,
    required List<Map<String, dynamic>> selectedAddOns,
    required String bookingType,
    String? deliveryAddress,
    DateTime? pickupDate,
    String? timeSlot,
    required String paymentMethod,
    String? specialInstructions,
    String? machineId,
    String? machineName,
    String? slotId,
    double? totalAmount,
    double? slotFee,
    double? deliveryFee,
    String? customerName,
    String? customerPhone,
    String? serviceType,
  }) async {
    try {
      // Enrich each category with its computed price
      final enrichedCategories = categories.map((cat) {
        final name = cat['name'] as String? ?? '';
        final weight = (cat['weight'] as num?)?.toDouble() ?? 0.0;
        final computedPrice = (cat['computedPrice'] as num?)?.toDouble() ??
            PricingService.calculateCategoryPrice(category: name, weight: weight);
        return {...cat, 'computedPrice': computedPrice};
      }).toList();

      final computedCategoryTotal = enrichedCategories.fold<double>(
        0.0,
        (sum, cat) => sum + ((cat['computedPrice'] as num?)?.toDouble() ?? 0.0),
      );

      final isDelivery = bookingType == AppConstants.bookingTypeDelivery;
      final providedDeliveryFee = deliveryFee ?? 0.0;
      final resolvedDeliveryFee = isDelivery
          ? await DeliveryPriceService.getDeliveryFeeForAddress(
              deliveryAddress ?? '',
              fallback: providedDeliveryFee > 0
                  ? providedDeliveryFee
                  : AppConstants.deliveryFee,
            )
          : 0.0;

      final providedSlotFee = slotFee ?? 0.0;

      final addOnsTotal = selectedAddOns.fold<double>(
        0.0,
        (sum, e) => sum + ((e['price'] as num?)?.toDouble() ?? 0.0),
      );

      final computedTotal = computedCategoryTotal +
          addOnsTotal +
          AppConstants.bookingFee +
          providedSlotFee +
          resolvedDeliveryFee;

      final resolvedTotal = totalAmount == null
          ? computedTotal
          : totalAmount +
              (isDelivery ? (resolvedDeliveryFee - providedDeliveryFee) : 0.0);

      final paymentStatus = paymentMethod == AppConstants.paymentGCash
          ? AppConstants.paymentPaid
          : AppConstants.paymentUnpaid;

      final bookingId = _uuid.v4();

      final bookingModel = BookingModel(
        bookingId: bookingId,
        userId: userId,
        categories: enrichedCategories,
        categoryTotal: computedCategoryTotal,
        selectedAddOns: selectedAddOns,
        addOnsTotal: addOnsTotal,
        bookingFee: AppConstants.bookingFee,
        totalAmount: resolvedTotal,
        bookingType: bookingType,
        deliveryAddress: deliveryAddress,
        pickupDate: pickupDate,
        timeSlot: timeSlot,
        serviceType: serviceType,
        status: AppConstants.statusPending,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
        specialInstructions: specialInstructions,
        createdAt: DateTime.now(),
        machineId: machineId,
        machineName: machineName,
        slotId: slotId,
        slotFee: providedSlotFee,
        deliveryFee: resolvedDeliveryFee,
        customerName: customerName,
        customerPhone: customerPhone,
      );

      final bookingRef = _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId);

      if (slotId != null && slotId.isNotEmpty) {
        // Write the booking document.
        await bookingRef.set(bookingModel.toJson());

        // Then mark the slot as booked with a simple update.
        // Avoids runTransaction which causes "Dart exception from converted
        // Future" on Flutter Web even when rules allow the write.
        try {
          final slotRef =
              _firestore.collection('machine_slots').doc(slotId);
          await slotRef.update({
            'isAvailable': false,
            'status': 'booked',
            'bookingId': bookingId,
            'bookedAt': DateTime.now().toIso8601String(),
          });
        } catch (_) {
          // Slot update failed (permission denied, doc missing, etc.)
          // Booking is already saved — admin can manage slot status.
        }
      } else {
        // No slot involved — plain write.
        await bookingRef.set(bookingModel.toJson());
      }

      return bookingModel;
    } on FirebaseException catch (e) {
      developer.log(
        'FirebaseException creating booking: ${e.code} - ${e.message}',
        name: 'BookingDataSource',
      );
      throw Exception('Failed to create booking: [${e.code}] ${e.message}');
    } catch (e, stack) {
      developer.log(
        'Error creating booking: $e (type: ${e.runtimeType})',
        name: 'BookingDataSource',
        error: e,
        stackTrace: stack,
      );
      // Re-throw SLOT_UNAVAILABLE so callers can show a specific message.
      if (e.toString().contains('SLOT_UNAVAILABLE')) rethrow;
      throw Exception('Failed to create booking: $e');
    }
  }

  @override
  Future<List<String>> getBookedSlots({
    required DateTime date,
    required String time,
  }) async {
    try {
      final dateStr = date.toIso8601String().split('T').first;
      // Query only by pickupTime to avoid composite-index requirement.
      // Status and date are filtered client-side.
      final snapshot = await _firestore
          .collection(AppConstants.bookingsCollection)
          .where('timeSlot', isEqualTo: time)
          .get();

      final booked = snapshot.docs
          .where((doc) {
            final data = doc.data();
            final status = data['status'] as String?;
            if (status == AppConstants.statusCancelled) return false;
            final pd = data['pickupDate'] as String?;
            return pd != null && pd.startsWith(dateStr);
          })
          .map((doc) => doc.data()['slotId'] as String?)
          .whereType<String>()
          .toList();

      return booked;
    } catch (e) {
      throw Exception('Failed to fetch booked slots: $e');
    }
  }
  
  @override
  Future<void> createPaymentRecord({
    required String bookingId,
    required String userId,
    required double amount,
    required String method,
  }) async {
    try {
      final paymentId = _uuid.v4();
      await _firestore.collection('payments').doc(paymentId).set({
        'paymentId': paymentId,
        'bookingId': bookingId,
        'userId': userId,
        'amount': amount,
        'method': method,
        'status': 'Success',
        'paidAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Failed to create payment record: $e');
    }
  }
  
  @override
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(AppConstants.bookingsCollection)
          .where('userId', isEqualTo: userId)
          .get();
      
      // Get bookings and sort client-side (no Firestore index needed)
      final bookings = querySnapshot.docs
          .map((doc) => BookingModel.fromJson(doc.data()))
          .toList();
      
      // Sort by createdAt descending (newest first)
      bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return bookings;
    } catch (e) {
      print('Error loading user bookings: $e');
      // Return empty list instead of throwing to prevent app crashes
      return [];
    }
  }
  
  @override
  Future<BookingModel> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .get();
      
      if (!doc.exists) {
        throw Exception('Booking not found');
      }
      
      return BookingModel.fromJson(doc.data()!);
    } catch (e) {
      throw Exception('Failed to get booking: $e');
    }
  }
  
  @override
  Future<void> cancelBooking(String bookingId) async {
    try {
      // Read the booking first to get slotId (outside the transaction).
      final bookingSnap = await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .get();
      final slotId = bookingSnap.data()?['slotId'] as String?;

      await _firestore.runTransaction<void>((tx) async {
        final bookingRef = _firestore
            .collection(AppConstants.bookingsCollection)
            .doc(bookingId);

        tx.update(bookingRef, {'status': AppConstants.statusCancelled});

        // Release the time slot so it becomes bookable again.
        if (slotId != null && slotId.isNotEmpty) {
          final slotRef =
              _firestore.collection('machine_slots').doc(slotId);
          tx.update(slotRef, {
            'isAvailable': true,
            'status': 'available',
            'bookingId': FieldValue.delete(),
            'bookedAt': FieldValue.delete(),
          });
        }
      });
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }
  
  @override
  Future<void> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
    String? newSlot,
    String? oldSlotId,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .update({
        'pickupDate': newPickupDate.toIso8601String(),
        'pickupTime': newPickupTime,
      });
    } catch (e) {
      throw Exception('Failed to reschedule pickup: $e');
    }
  }

  @override
  Future<List<BookingModel>> getDriverBookings(String driverId) async {
    if (driverId.isEmpty) return [];

    // Query ONLY on driverId — single-field index, no composite index needed.
    // Filter for delivery client-side to handle both 'bookingType' and
    // 'orderType' field names (older bookings use orderType).
    final querySnapshot = await _firestore
        .collection(AppConstants.bookingsCollection)
        .where('driverId', isEqualTo: driverId)
        .get();

    final bookings = querySnapshot.docs
        .where((doc) {
          final data = doc.data();
          final type = (data['bookingType'] ?? data['orderType'] ?? '').toString();
          return type == 'delivery';
        })
        .map((doc) => BookingModel.fromJson({...doc.data(), 'bookingId': doc.id}))
        .toList();

    bookings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return bookings;
  }

  @override
  Future<void> updateDeliveryStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .update({
        'status': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Lock the chat room when delivery is completed.
      if (status.trim().toLowerCase() == 'completed') {
        try {
          await _firestore.collection('chats').doc(bookingId).update({
            'locked': true,
          });
        } catch (_) {
          // Chat room may not exist — ignore
        }
      }
    } catch (e) {
      throw Exception('Failed to update delivery status: $e');
    }
  }

  @override
  Future<void> generateDeliveryReceipt({
    required String bookingId,
    required List<int> imageBytes,
    required String imageFileName,
  }) async {
    try {
      // 1. Encode proof photo as base64 data URI (no Firebase Storage needed)
      final ext = imageFileName.contains('.')
          ? imageFileName.split('.').last
          : 'jpg';
      final base64Image = base64Encode(imageBytes);
      final proofUrl = 'data:image/$ext;base64,$base64Image';

      // 2. Fetch booking data
      final bookingRef = _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId);
      final snap = await bookingRef.get();
      final data = snap.data();
      if (data == null) throw Exception('Booking not found');

      final customerId = data['userId'] as String? ?? '';

      // 3. Batch: create receipt, update booking, notify customer
      final batch = _firestore.batch();

      final receiptRef = _firestore
          .collection(AppConstants.receiptsCollection)
          .doc(bookingId);
      batch.set(receiptRef, {
        'receiptId': bookingId,
        'userId': customerId,
        'bookingId': bookingId,
        'categories': data['categories'] ?? [],
        'addOns': data['selectedAddOns'] ?? [],
        'totalAmount': data['totalAmount'] ?? 0,
        'slotFee': data['slotFee'] ?? 0,
        'deliveryFee': data['deliveryFee'] ?? 0,
        'bookingFee': data['bookingFee'] ?? 0,
        'addOnsTotal': data['addOnsTotal'] ?? 0,
        'paymentStatus': data['paymentStatus'] ?? 'Unpaid',
        'paymentMethod': data['paymentMethod'] ?? AppConstants.paymentCash,
        'bookingType': data['bookingType'] ?? data['orderType'] ?? 'delivery',
        'machineId': data['machineId'],
        'machineName': data['machineName'],
        'timeSlot': data['timeSlot'],
        'bookingDate': data['pickupDate'],
        'deliveryAddress': data['deliveryAddress'],
        'customerName': data['customerName'],
        'driverName': data['driverName'],
        'serviceType': data['serviceType'],
        'deliveryProofUrl': proofUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update booking with proof URL
      batch.update(bookingRef, {'deliveryProofUrl': proofUrl});

      // Notify customer
      if (customerId.isNotEmpty) {
        final notifRef = _firestore
            .collection(AppConstants.usersCollection)
            .doc(customerId)
            .collection('notifications')
            .doc();
        batch.set(notifRef, {
          'type': 'receipt_ready',
          'bookingId': bookingId,
          'receiptId': bookingId,
          'title': '🧾 Your E-Receipt is Ready!',
          'body': 'Your COD delivery is complete. View your receipt in the app.',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to generate delivery receipt: $e');
    }
  }

  @override
  Future<void> notifyCustomerArrived({
    required String bookingId,
    required String customerId,
  }) async {
    try {
      final batch = _firestore.batch();

      // Mark booking with riderArrivedAt timestamp
      final bookingRef = _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId);
      batch.update(bookingRef, {
        'riderArrivedAt': FieldValue.serverTimestamp(),
      });

      // Write a notification document for the customer
      final notifRef = _firestore
          .collection(AppConstants.usersCollection)
          .doc(customerId)
          .collection('notifications')
          .doc();
      batch.set(notifRef, {
        'type': 'rider_arrived',
        'bookingId': bookingId,
        'title': 'Rider Has Arrived!',
        'body': 'Your rider has arrived at your location. Please prepare your laundry.',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      await batch.commit();
    } catch (e) {
      throw Exception('Failed to send arrived notification: $e');
    }
  }
}

