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
    required List<String> selectedServices,
    required List<Map<String, dynamic>> selectedAddOns,
    required String bookingType,
    String? deliveryAddress,
    DateTime? pickupDate,
    String? pickupTime,
    required String paymentMethod,
    String? specialInstructions,
  }) {
    return repository.createBooking(
      userId: userId,
      categories: categories,
      selectedServices: selectedServices,
      selectedAddOns: selectedAddOns,
      bookingType: bookingType,
      deliveryAddress: deliveryAddress,
      pickupDate: pickupDate,
      pickupTime: pickupTime,
      paymentMethod: paymentMethod,
      specialInstructions: specialInstructions,
    );
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
  }) {
    return _repository.reschedulePickup(
      bookingId: bookingId,
      newPickupDate: newPickupDate,
      newPickupTime: newPickupTime,
    );
  }
}