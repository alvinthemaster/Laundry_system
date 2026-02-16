import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/domain/repositories/booking_repository.dart';

class CreateBookingUseCase {
  final BookingRepository repository;
  
  const CreateBookingUseCase(this.repository);
  
  Future<Either<dynamic, BookingEntity>> call({
    required String userId,
    required String serviceType,
    required double weight,
    required DateTime pickupDate,
    required String pickupTime,
    String? specialInstructions,
  }) {
    return repository.createBooking(
      userId: userId,
      serviceType: serviceType,
      weight: weight,
      pickupDate: pickupDate,
      pickupTime: pickupTime,
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

class CalculateTotalAmountUseCase {
  final BookingRepository repository;
  
  const CalculateTotalAmountUseCase(this.repository);
  
  double call({
    required String serviceType,
    required double weight,
    required double bookingFee,
  }) {
    return repository.calculateTotalAmount(
      serviceType: serviceType,
      weight: weight,
      bookingFee: bookingFee,
    );
  }
}
