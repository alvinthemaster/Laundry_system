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

final reschedulePickupUseCaseProvider = Provider<ReschedulePickupUseCase>((ref) {
  return ReschedulePickupUseCase(ref.read(bookingRepositoryProvider));
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
  final ReschedulePickupUseCase _reschedulePickupUseCase;
  
  BookingNotifier(
    this._createBookingUseCase,
    this._getUserBookingsUseCase,
    this._getBookingByIdUseCase,
    this._cancelBookingUseCase,
    this._reschedulePickupUseCase,
  ) : super(const BookingState());
  
  Future<bool> createBooking({
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
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _createBookingUseCase(
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
        print('Error loading bookings: ${failure.toString()}');
        state = state.copyWith(isLoading: false, error: failure.toString());
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
      (failure) => state = state.copyWith(isLoading: false, error: failure.toString()),
      (booking) => state = state.copyWith(isLoading: false, selectedBooking: booking),
    );
  }
  
  Future<bool> cancelBooking(String bookingId) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _cancelBookingUseCase(bookingId);
    
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.toString());
        return false;
      },
      (_) {
        // Update booking in list
        final updatedBookings = state.bookings.map((booking) {
          if (booking.bookingId == bookingId) {
            return BookingEntity(
              bookingId: booking.bookingId,
              userId: booking.userId,
              categories: booking.categories,
              categoryTotal: booking.categoryTotal,
              selectedServices: booking.selectedServices,
              selectedAddOns: booking.selectedAddOns,
              weight: booking.weight,
              servicesTotal: booking.servicesTotal,
              addOnsTotal: booking.addOnsTotal,
              bookingFee: booking.bookingFee,
              totalAmount: booking.totalAmount,
              bookingType: booking.bookingType,
              deliveryAddress: booking.deliveryAddress,
              pickupDate: booking.pickupDate,
              pickupTime: booking.pickupTime,
              status: 'Cancelled',
              paymentStatus: booking.paymentStatus,
              paymentMethod: booking.paymentMethod,
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
  
  Future<bool> reschedulePickup({
    required String bookingId,
    required DateTime newPickupDate,
    required String newPickupTime,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _reschedulePickupUseCase(
      bookingId: bookingId,
      newPickupDate: newPickupDate,
      newPickupTime: newPickupTime,
    );
    
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
              categories: booking.categories,
              categoryTotal: booking.categoryTotal,
              selectedServices: booking.selectedServices,
              selectedAddOns: booking.selectedAddOns,
              weight: booking.weight,
              servicesTotal: booking.servicesTotal,
              addOnsTotal: booking.addOnsTotal,
              bookingFee: booking.bookingFee,
              totalAmount: booking.totalAmount,
              bookingType: booking.bookingType,
              deliveryAddress: booking.deliveryAddress,
              pickupDate: newPickupDate,
              pickupTime: newPickupTime,
              status: booking.status,
              paymentStatus: booking.paymentStatus,
              paymentMethod: booking.paymentMethod,
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
}

// Booking Provider
final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  return BookingNotifier(
    ref.read(createBookingUseCaseProvider),
    ref.read(getUserBookingsUseCaseProvider),
    ref.read(getBookingByIdUseCaseProvider),
    ref.read(cancelBookingUseCaseProvider),
    ref.read(reschedulePickupUseCaseProvider),
  );
});
