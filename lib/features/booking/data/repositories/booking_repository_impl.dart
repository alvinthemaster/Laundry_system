import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/booking/data/datasources/booking_data_source.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/domain/repositories/booking_repository.dart';

class BookingRepositoryImpl implements BookingRepository {
  final BookingDataSource dataSource;
  
  const BookingRepositoryImpl(this.dataSource);
  
  @override
  Future<Either<Failure, BookingEntity>> createBooking({
    required String userId,
    required String serviceType,
    required double weight,
    required DateTime pickupDate,
    required String pickupTime,
    String? specialInstructions,
  }) async {
    try {
      final booking = await dataSource.createBooking(
        userId: userId,
        serviceType: serviceType,
        weight: weight,
        pickupDate: pickupDate,
        pickupTime: pickupTime,
        specialInstructions: specialInstructions,
      );
      return Either.right(booking);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, List<BookingEntity>>> getUserBookings(String userId) async {
    try {
      final bookings = await dataSource.getUserBookings(userId);
      return Either.right(bookings);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, BookingEntity>> getBookingById(String bookingId) async {
    try {
      final booking = await dataSource.getBookingById(bookingId);
      return Either.right(booking);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
  
  @override
  Future<Either<Failure, void>> cancelBooking(String bookingId) async {
    try {
      await dataSource.cancelBooking(bookingId);
      return Either.right(null);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
  
  @override
  double calculateTotalAmount({
    required String serviceType,
    required double weight,
    required double bookingFee,
  }) {
    final servicePrice = AppConstants.serviceTypes[serviceType] ?? 0.0;
    return (weight * servicePrice) + bookingFee;
  }
}
