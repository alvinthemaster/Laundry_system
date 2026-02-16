import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/features/booking/data/datasources/booking_data_source.dart';
import 'package:laundry_system/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/domain/repositories/booking_repository.dart';
import 'package:laundry_system/features/booking/domain/usecases/booking_usecases.dart';

// Data Source Provider
final bookingDataSourceProvider = Provider<BookingDataSource>((ref) {
  return BookingDataSourceImpl();
});

// Repository Provider
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepositoryImpl(ref.read(bookingDataSourceProvider));
});

// Use Cases Providers
final createBookingUseCaseProvider = Provider<CreateBookingUseCase>((ref) {
  return CreateBookingUseCase(ref.read(bookingRepositoryProvider));
});

final getUserBookingsUseCaseProvider = Provider<GetUserBookingsUseCase>((ref) {
  return GetUserBookingsUseCase(ref.read(bookingRepositoryProvider));
});

final getBookingByIdUseCaseProvider = Provider<GetBookingByIdUseCase>((ref) {
  return GetBookingByIdUseCase(ref.read(bookingRepositoryProvider));
});

final cancelBookingUseCaseProvider = Provider<CancelBookingUseCase>((ref) {
  return CancelBookingUseCase(ref.read(bookingRepositoryProvider));
});

final calculateTotalAmountUseCaseProvider = Provider<CalculateTotalAmountUseCase>((ref) {
  return CalculateTotalAmountUseCase(ref.read(bookingRepositoryProvider));
});

// Booking State
class BookingState {
  final bool isLoading;
  final List<BookingEntity> bookings;
  final BookingEntity? selectedBooking;
  final String? error;
  
  const BookingState({
    this.isLoading = false,
    this.bookings = const [],
    this.selectedBooking,
    this.error,
  });
  
  BookingState copyWith({
    bool? isLoading,
    List<BookingEntity>? bookings,
    BookingEntity? selectedBooking,
    String? error,
  }) {
    return BookingState(
      isLoading: isLoading ?? this.isLoading,
      bookings: bookings ?? this.bookings,
      selectedBooking: selectedBooking ?? this.selectedBooking,
      error: error,
    );
  }
}

// Booking Notifier
class BookingNotifier extends StateNotifier<BookingState> {
  final CreateBookingUseCase _createBookingUseCase;
  final GetUserBookingsUseCase _getUserBookingsUseCase;
  final GetBookingByIdUseCase _getBookingByIdUseCase;
  final CancelBookingUseCase _cancelBookingUseCase;
  final CalculateTotalAmountUseCase _calculateTotalAmountUseCase;
  
  BookingNotifier(
    this._createBookingUseCase,
    this._getUserBookingsUseCase,
    this._getBookingByIdUseCase,
    this._cancelBookingUseCase,
    this._calculateTotalAmountUseCase,
  ) : super(const BookingState());
  
  Future<bool> createBooking({
    required String userId,
    required String serviceType,
    required double weight,
    required DateTime pickupDate,
    required String pickupTime,
    String? specialInstructions,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _createBookingUseCase(
      userId: userId,
      serviceType: serviceType,
      weight: weight,
      pickupDate: pickupDate,
      pickupTime: pickupTime,
      specialInstructions: specialInstructions,
    );
    
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (booking) {
        // Add new booking to list
        final updatedBookings = [booking, ...state.bookings];
        state = state.copyWith(isLoading: false, bookings: updatedBookings);
        return true;
      },
    );
  }
  
  Future<void> getUserBookings(String userId) async {
    if (userId.isEmpty) {
      print('getUserBookings called with empty userId');
      return;
    }
    
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _getUserBookingsUseCase(userId);
    
    result.fold(
      (failure) {
        print('Error loading bookings: ${failure.message}');
        state = state.copyWith(isLoading: false, error: failure.message);
      },
      (bookings) {
        print('Successfully loaded ${bookings.length} bookings for user $userId');
        state = state.copyWith(isLoading: false, bookings: bookings);
      },
    );
  }
  
  Future<void> getBookingById(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _getBookingByIdUseCase(bookingId);
    
    result.fold(
      (failure) => state = state.copyWith(isLoading: false, error: failure.message),
      (booking) => state = state.copyWith(isLoading: false, selectedBooking: booking),
    );
  }
  
  Future<bool> cancelBooking(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _cancelBookingUseCase(bookingId);
    
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        // Update booking in list
        final updatedBookings = state.bookings.map((booking) {
          if (booking.bookingId == bookingId) {
            return BookingEntity(
              bookingId: booking.bookingId,
              userId: booking.userId,
              serviceType: booking.serviceType,
              weight: booking.weight,
              bookingFee: booking.bookingFee,
              servicePrice: booking.servicePrice,
              totalAmount: booking.totalAmount,
              pickupDate: booking.pickupDate,
              pickupTime: booking.pickupTime,
              status: 'Cancelled',
              paymentStatus: booking.paymentStatus,
              specialInstructions: booking.specialInstructions,
              createdAt: booking.createdAt,
            );
          }
          return booking;
        }).toList();
        
        state = state.copyWith(isLoading: false, bookings: updatedBookings);
        return true;
      },
    );
  }
  
  double calculateTotalAmount({
    required String serviceType,
    required double weight,
    required double bookingFee,
  }) {
    return _calculateTotalAmountUseCase(
      serviceType: serviceType,
      weight: weight,
      bookingFee: bookingFee,
    );
  }
}

// Booking Provider
final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  return BookingNotifier(
    ref.read(createBookingUseCaseProvider),
    ref.read(getUserBookingsUseCaseProvider),
    ref.read(getBookingByIdUseCaseProvider),
    ref.read(cancelBookingUseCaseProvider),
    ref.read(calculateTotalAmountUseCaseProvider),
  );
});
