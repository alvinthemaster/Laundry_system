import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/features/booking/data/datasources/booking_data_source.dart';
import 'package:laundry_system/features/booking/data/datasources/machine_data_source.dart';
import 'package:laundry_system/features/booking/data/models/machine_model.dart';
import 'package:laundry_system/features/booking/data/models/machine_slot_model.dart';
import 'package:laundry_system/features/booking/data/repositories/booking_repository_impl.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/domain/repositories/booking_repository.dart';
import 'package:laundry_system/features/booking/domain/usecases/booking_usecases.dart';

// Machine Data Source Provider
final machineDataSourceProvider = Provider<MachineDataSource>((ref) {
  return MachineDataSourceImpl();
});

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

final getBookedSlotsUseCaseProvider = Provider<GetBookedSlotsUseCase>((ref) {
  return GetBookedSlotsUseCase(ref.read(bookingRepositoryProvider));
});

final getDriverBookingsUseCaseProvider = Provider<GetDriverBookingsUseCase>((ref) {
  return GetDriverBookingsUseCase(ref.read(bookingRepositoryProvider));
});

final notifyCustomerArrivedUseCaseProvider = Provider<NotifyCustomerArrivedUseCase>((ref) {
  return NotifyCustomerArrivedUseCase(ref.read(bookingRepositoryProvider));
});

final updateDeliveryStatusUseCaseProvider = Provider<UpdateDeliveryStatusUseCase>((ref) {
  return UpdateDeliveryStatusUseCase(ref.read(bookingRepositoryProvider));
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
  final GetBookedSlotsUseCase _getBookedSlotsUseCase;
  final GetDriverBookingsUseCase _getDriverBookingsUseCase;
  final NotifyCustomerArrivedUseCase _notifyCustomerArrivedUseCase;
  final UpdateDeliveryStatusUseCase _updateDeliveryStatusUseCase;
  
  BookingNotifier(
    this._createBookingUseCase,
    this._getUserBookingsUseCase,
    this._getBookingByIdUseCase,
    this._cancelBookingUseCase,
    this._reschedulePickupUseCase,
    this._getBookedSlotsUseCase,
    this._getDriverBookingsUseCase,
    this._notifyCustomerArrivedUseCase,
    this._updateDeliveryStatusUseCase,
  ) : super(const BookingState());
  
  Future<bool> createBooking({
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
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _createBookingUseCase(
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
  
  Future<List<String>> getAvailableSlots({
    required DateTime date,
    required String time,
    required List<String> allSlots,
  }) async {
    final result = await _getBookedSlotsUseCase(date: date, time: time);
    return result.fold(
      (_) => allSlots, // on error, show all slots so user isn't blocked
      (booked) => allSlots.where((s) => !booked.contains(s)).toList(),
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
              selectedAddOns: booking.selectedAddOns,
              addOnsTotal: booking.addOnsTotal,
              bookingFee: booking.bookingFee,
              totalAmount: booking.totalAmount,
              bookingType: booking.bookingType,
              deliveryAddress: booking.deliveryAddress,
              pickupDate: booking.pickupDate,
              timeSlot: booking.timeSlot,
              serviceType: booking.serviceType,
              status: 'Cancelled',
              paymentStatus: booking.paymentStatus,
              paymentMethod: booking.paymentMethod,
              specialInstructions: booking.specialInstructions,
              createdAt: booking.createdAt,
              machineId: booking.machineId,
              machineName: booking.machineName,
              slotId: booking.slotId,
              slotFee: booking.slotFee,
              deliveryFee: booking.deliveryFee,
              customerName: booking.customerName,
              driverId: booking.driverId,
              driverName: booking.driverName,
              driverContact: booking.driverContact,
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
    String? newSlot,
    String? oldSlotId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    final result = await _reschedulePickupUseCase(
      bookingId: bookingId,
      newPickupDate: newPickupDate,
      newPickupTime: newPickupTime,
      newSlot: newSlot,
      oldSlotId: oldSlotId,
    );
    
    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        // Update booking in list — keep timeSlot unchanged, update pickupDate + pickupTime
        final updatedBookings = state.bookings.map((booking) {
          if (booking.bookingId == bookingId) {
            return BookingEntity(
              bookingId: booking.bookingId,
              userId: booking.userId,
              categories: booking.categories,
              categoryTotal: booking.categoryTotal,
              selectedAddOns: booking.selectedAddOns,
              addOnsTotal: booking.addOnsTotal,
              bookingFee: booking.bookingFee,
              totalAmount: booking.totalAmount,
              bookingType: booking.bookingType,
              deliveryAddress: booking.deliveryAddress,
              pickupDate: newPickupDate,
              timeSlot: booking.timeSlot, // unchanged
              pickupTime: newPickupTime,
              serviceType: booking.serviceType,
              status: booking.status,
              paymentStatus: booking.paymentStatus,
              paymentMethod: booking.paymentMethod,
              specialInstructions: booking.specialInstructions,
              createdAt: booking.createdAt,
              machineId: booking.machineId,
              machineName: booking.machineName,
              slotId: newSlot ?? booking.slotId,
              slotFee: booking.slotFee,
              deliveryFee: booking.deliveryFee,
              customerName: booking.customerName,
              driverId: booking.driverId,
              driverName: booking.driverName,
              driverContact: booking.driverContact,
            );
          }
          return booking;
        }).toList();
        
        state = state.copyWith(isLoading: false, bookings: updatedBookings);
        return true;
      },
    );
  }

  Future<void> getDriverBookings(String driverId) async {
    if (driverId.isEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    final result = await _getDriverBookingsUseCase(driverId);
    result.fold(
      (failure) => state = state.copyWith(isLoading: false, error: failure.toString()),
      (bookings) => state = state.copyWith(isLoading: false, bookings: bookings),
    );
  }

  Future<bool> updateDeliveryStatus({
    required String bookingId,
    required String status,
  }) async {
    final result = await _updateDeliveryStatusUseCase(
      bookingId: bookingId,
      status: status,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.toString());
        return false;
      },
      (_) {
        // Update status in local list immediately
        final updated = state.bookings.map((b) {
          if (b.bookingId == bookingId) {
            return BookingEntity(
              bookingId: b.bookingId,
              userId: b.userId,
              categories: b.categories,
              categoryTotal: b.categoryTotal,
              selectedAddOns: b.selectedAddOns,
              addOnsTotal: b.addOnsTotal,
              bookingFee: b.bookingFee,
              totalAmount: b.totalAmount,
              bookingType: b.bookingType,
              deliveryAddress: b.deliveryAddress,
              pickupDate: b.pickupDate,
              timeSlot: b.timeSlot,
              pickupTime: b.pickupTime,
              serviceType: b.serviceType,
              status: status,
              paymentStatus: b.paymentStatus,
              paymentMethod: b.paymentMethod,
              specialInstructions: b.specialInstructions,
              createdAt: b.createdAt,
              machineId: b.machineId,
              machineName: b.machineName,
              slotId: b.slotId,
              slotFee: b.slotFee,
              deliveryFee: b.deliveryFee,
              customerName: b.customerName,
              driverId: b.driverId,
              driverName: b.driverName,
              driverContact: b.driverContact,
            );
          }
          return b;
        }).toList();
        state = state.copyWith(bookings: updated);
        return true;
      },
    );
  }

  Future<bool> notifyCustomerArrived({
    required String bookingId,
    required String customerId,
  }) async {
    final result = await _notifyCustomerArrivedUseCase(
      bookingId: bookingId,
      customerId: customerId,
    );
    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.toString());
        return false;
      },
      (_) => true,
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
    ref.read(getBookedSlotsUseCaseProvider),
    ref.read(getDriverBookingsUseCaseProvider),
    ref.read(notifyCustomerArrivedUseCaseProvider),
    ref.read(updateDeliveryStatusUseCaseProvider),
  );
});

// Machine Providers
final machinesProvider = FutureProvider<List<MachineModel>>((ref) async {
  final ds = ref.read(machineDataSourceProvider);
  await ds.seedMachines(); // Ensure machines exist
  return ds.getMachines();
});

final machinesByTypeProvider =
    FutureProvider.family<List<MachineModel>, String>((ref, type) async {
  final ds = ref.read(machineDataSourceProvider);
  await ds.seedMachines();
  return ds.getMachinesByType(type);
});

final slotsForDateProvider = StreamProvider.family<List<MachineSlotModel>, String>(
  (ref, date) {
    final ds = ref.read(machineDataSourceProvider);
    return ds.watchSlotsForDate(date: date);
  },
);

final slotsForDateAndTypeProvider =
    StreamProvider.family<List<MachineSlotModel>, ({String date, String? machineType})>(
  (ref, params) {
    final ds = ref.read(machineDataSourceProvider);
    return ds.watchSlotsForDate(date: params.date, machineType: params.machineType);
  },
);
