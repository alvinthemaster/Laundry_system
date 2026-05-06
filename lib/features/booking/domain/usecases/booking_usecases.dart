import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/domain/repositories/booking_repository.dart';

class CreateBookingUseCase {
  final BookingRepository repository;
  
  const CreateBookingUseCase(this.repository);
  
  Future<Either<dynamic, BookingEntity>> call({
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
    String? serviceType,
  }) {
    return repository.createBooking(
      userId: userId,
      categories: categories,
      selectedAddOns: selectedAddOns,
      bookingType: bookingType,
      deliveryAddress: deliveryAddress,
      pickupDate: pickupDate,
      timeSlot: timeSlot,
      paymentMethod: paymentMethod,
      specialInstructions: specialInstructions,
      machineId: machineId,
      machineName: machineName,
      slotId: slotId,
      totalAmount: totalAmount,
      slotFee: slotFee,
      deliveryFee: deliveryFee,
      customerName: customerName,
      serviceType: serviceType,
    );
  }
}

class GetBookedSlotsUseCase {
  final BookingRepository repository;

  const GetBookedSlotsUseCase(this.repository);

  Future<Either<dynamic, List<String>>> call({
    required DateTime date,
    required String time,
  }) {
    return repository.getBookedSlots(date: date, time: time);
  }
}

class GetUserBookingsUseCase {
  final BookingRepository repository;
  
  const GetUserBookingsUseCase(this.repository);
  
  Future<Either<dynamic, List<BookingEntity>>> call(String userId) {
    return repository.getUserBookings(userId);
  }
}

class GetBookingByIdUseCase {
  final BookingRepository repository;
  
  const GetBookingByIdUseCase(this.repository);
  
  Future<Either<dynamic, BookingEntity>> call(String bookingId) {
    return repository.getBookingById(bookingId);
  }
}

class CancelBookingUseCase {
  final BookingRepository repository;
  
  const CancelBookingUseCase(this.repository);
  
  Future<Either<dynamic, void>> call(String bookingId) {
    return repository.cancelBooking(bookingId);
  }
}
class ReschedulePickupUseCase {
  final BookingRepository _repository;
  
  ReschedulePickupUseCase(this._repository);
  
  Future<Either<Failure, void>> call({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
    String? newSlot,
    String? oldSlotId,
  }) {
    return _repository.reschedulePickup(
      bookingId: bookingId,
      newPickupDate: newPickupDate,
      newPickupTime: newPickupTime,
      newSlot: newSlot,
      oldSlotId: oldSlotId,
    );
  }
}

class GetDriverBookingsUseCase {
  final BookingRepository repository;

  const GetDriverBookingsUseCase(this.repository);

  Future<Either<dynamic, List<BookingEntity>>> call(String driverId) {
    return repository.getDriverBookings(driverId);
  }
}

class UpdateDeliveryStatusUseCase {
  final BookingRepository repository;

  const UpdateDeliveryStatusUseCase(this.repository);

  Future<Either<dynamic, void>> call({
    required String bookingId,
    required String status,
  }) {
    return repository.updateDeliveryStatus(bookingId: bookingId, status: status);
  }
}

class NotifyCustomerArrivedUseCase {
  final BookingRepository repository;

  const NotifyCustomerArrivedUseCase(this.repository);

  Future<Either<dynamic, void>> call({
    required String bookingId,
    required String customerId,
  }) {
    return repository.notifyCustomerArrived(
      bookingId: bookingId,
      customerId: customerId,
    );
  }
}