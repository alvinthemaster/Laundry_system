# Laundry Management System - Architecture Documentation

## Overview

This project follows **Clean Architecture** principles with clear separation of concerns across three main layers:

1. **Presentation Layer** - UI and State Management
2. **Domain Layer** - Business Logic and Entities
3. **Data Layer** - Data Sources and Repository Implementation

## Architecture Layers

### 1. Presentation Layer

**Purpose**: Handle UI rendering and user interactions

**Components**:
- **Pages/Screens**: Flutter widgets for UI
- **Providers**: Riverpod state management
- **State Classes**: Immutable state objects

**Example Flow**:
```
User Action → Widget Event → Provider Method → Use Case → Repository
```

### 2. Domain Layer

**Purpose**: Contains business logic and rules

**Components**:
- **Entities**: Pure Dart classes representing core business objects
- **Repositories (Abstract)**: Interfaces defining data operations
- **Use Cases**: Single-responsibility business operations

**Key Principles**:
- No Flutter dependencies
- Pure Dart code
- Business rules enforcement

### 3. Data Layer

**Purpose**: Handle data retrieval and storage

**Components**:
- **Models**: Data transfer objects with JSON serialization
- **Data Sources**: Firebase, API, or local database interactions
- **Repository Implementation**: Concrete implementation of domain repositories

## Design Patterns Used

### 1. Repository Pattern

Abstracts data sources from business logic.

```dart
// Domain Layer - Interface
abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({...});
}

// Data Layer - Implementation
class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;
  
  @override
  Future<Either<Failure, UserEntity>> login({...}) {
    // Implementation
  }
}
```

### 2. Use Case Pattern

Each use case represents a single business operation.

```dart
class LoginUseCase {
  final AuthRepository repository;
  
  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
  }) {
    return repository.login(email: email, password: password);
  }
}
```

### 3. Provider Pattern (Riverpod)

State management and dependency injection.

```dart
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(registerUseCaseProvider),
    ref.read(loginUseCaseProvider),
    // ... other dependencies
  );
});
```

### 4. Either Pattern

Functional error handling without exceptions.

```dart
class Either<L, R> {
  // Left = Failure, Right = Success
  T fold<T>(T Function(L) leftFn, T Function(R) rightFn) {
    // Implementation
  }
}
```

## Data Flow

### Authentication Flow

```
LoginPage (Presentation)
    ↓
AuthProvider (Presentation)
    ↓
LoginUseCase (Domain)
    ↓
AuthRepository (Domain - Interface)
    ↓
AuthRepositoryImpl (Data)
    ↓
AuthDataSource (Data)
    ↓
Firebase Auth + Firestore
```

### Booking Creation Flow

```
CreateBookingPage (Presentation)
    ↓
BookingProvider (Presentation)
    ↓
CreateBookingUseCase (Domain)
    ↓
BookingRepository (Domain - Interface)
    ↓
BookingRepositoryImpl (Data)
    ↓
BookingDataSource (Data)
    ↓
Cloud Firestore
```

## State Management

### AuthState

```dart
class AuthState {
  final bool isLoading;
  final UserEntity? user;
  final String? error;
}
```

### BookingState

```dart
class BookingState {
  final bool isLoading;
  final List<BookingEntity> bookings;
  final BookingEntity? selectedBooking;
  final String? error;
}
```

## Data Models

### User Model

**Firestore Collection**: `users`

```dart
{
  "uid": String,
  "fullName": String,
  "email": String,
  "phoneNumber": String,
  "address": String,
  "role": String,
  "createdAt": String (ISO8601)
}
```

### Booking Model

**Firestore Collection**: `bookings`

```dart
{
  "bookingId": String,
  "userId": String,
  "serviceType": String,
  "weight": Number,
  "bookingFee": Number,
  "servicePrice": Number,
  "totalAmount": Number,
  "pickupDate": String (ISO8601),
  "pickupTime": String,
  "status": String,
  "paymentStatus": String,
  "specialInstructions": String?,
  "createdAt": String (ISO8601)
}
```

## Business Rules

### Booking Calculation

```dart
totalAmount = (weight × servicePrice) + bookingFee
```

**Example**:
- Service: Wash & Iron (₱75/kg)
- Weight: 5 kg
- Booking Fee: ₱20
- **Total**: (5 × 75) + 20 = ₱395

### Service Pricing

| Service Type | Price per kg |
|-------------|-------------|
| Wash & Fold | ₱50 |
| Wash & Iron | ₱75 |
| Dry Clean | ₱100 |

### Booking Statuses

1. **Pending** - Initial state after creation
2. **Confirmed** - Admin accepted the booking
3. **Washing** - Laundry in progress
4. **Ready** - Ready for pickup/delivery
5. **Completed** - Service completed
6. **Cancelled** - Cancelled by user or admin

### Cancellation Rules

Users can cancel bookings only when status is:
- Pending
- Confirmed

## Error Handling

### Failure Types

```dart
class Failure {
  final String message;
}

class ServerFailure extends Failure { }
class AuthFailure extends Failure { }
class ValidationFailure extends Failure { }
```

### Error Flow

```dart
try {
  // Operation
  return Either.right(result);
} catch (e) {
  return Either.left(AuthFailure(e.toString()));
}
```

## Security

### Firestore Security Rules

```javascript
// Users: Can only read/write own data
match /users/{userId} {
  allow read, write: if request.auth.uid == userId;
}

// Bookings: Can create own, read all, update/delete own
match /bookings/{bookingId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update, delete: if resource.data.userId == request.auth.uid;
}
```

## Testing Strategy

### Unit Tests
- Test use cases with mocked repositories
- Test entities and business logic
- Test calculators and validators

### Widget Tests
- Test individual widgets
- Test user interactions
- Test navigation

### Integration Tests
- Test complete user flows
- Test Firebase integration
- Test state management

## Scalability Considerations

### Current Implementation
- Clean separation of concerns
- Easy to add new features
- Testable architecture
- Modular structure

### Future Enhancements
1. Add caching layer for offline support
2. Implement real-time updates with Firestore streams
3. Add analytics and crash reporting
4. Implement push notifications
5. Add payment gateway integration

## Performance Optimizations

1. **Pagination**: Load bookings in batches
2. **Caching**: Cache user data locally
3. **Lazy Loading**: Load data only when needed
4. **Image Optimization**: If adding images, use compression
5. **Index Optimization**: Add Firestore indexes for queries

## Mobile App vs Web Admin Differences

### Mobile App (Customer)
- Personal bookings only
- Create and cancel bookings
- View own profile
- Limited to customer role

### Web Admin (Future)
- View all bookings
- Update booking status
- Manage users
- View analytics
- Update prices
- Full admin capabilities

## Conclusion

This architecture provides:
- ✅ Separation of concerns
- ✅ Testability
- ✅ Maintainability
- ✅ Scalability
- ✅ Clean code principles
- ✅ SOLID principles
- ✅ Production-ready structure
