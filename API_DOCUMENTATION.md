# API & Features Documentation

## Table of Contents
1. [Authentication API](#authentication-api)
2. [Booking API](#booking-api)
3. [Business Logic](#business-logic)
4. [UI Components](#ui-components)
5. [State Management](#state-management)

---

## Authentication API

### Register User

**Method**: `register()`

**Parameters**:
```dart
{
  String email,
  String password,
  String fullName,
  String phoneNumber,
  String address,
}
```

**Returns**: `Future<bool>`

**Usage**:
```dart
final success = await ref.read(authProvider.notifier).register(
  email: 'user@example.com',
  password: 'password123',
  fullName: 'John Doe',
  phoneNumber: '09123456789',
  address: '123 Main St, City',
);
```

**Firebase Operations**:
1. Create user with FirebaseAuth
2. Store user profile in Firestore `users` collection
3. Auto-assign role: `customer`

---

### Login User

**Method**: `login()`

**Parameters**:
```dart
{
  String email,
  String password,
}
```

**Returns**: `Future<bool>`

**Usage**:
```dart
final success = await ref.read(authProvider.notifier).login(
  email: 'user@example.com',
  password: 'password123',
);
```

**Firebase Operations**:
1. Authenticate with FirebaseAuth
2. Retrieve user profile from Firestore
3. Update AuthState

---

### Logout User

**Method**: `logout()`

**Returns**: `Future<void>`

**Usage**:
```dart
await ref.read(authProvider.notifier).logout();
```

**Firebase Operations**:
1. Sign out from FirebaseAuth
2. Clear AuthState

---

### Reset Password

**Method**: `resetPassword()`

**Parameters**:
```dart
{
  String email,
}
```

**Returns**: `Future<bool>`

**Usage**:
```dart
final success = await ref.read(authProvider.notifier).resetPassword(
  email: 'user@example.com',
);
```

**Firebase Operations**:
1. Send password reset email via FirebaseAuth

---

### Get Current User

**Method**: `getCurrentUser()`

**Returns**: `Future<void>`

**Usage**:
```dart
await ref.read(authProvider.notifier).getCurrentUser();
```

**Firebase Operations**:
1. Get current user from FirebaseAuth
2. Fetch user data from Firestore
3. Update AuthState

---

## Booking API

### Create Booking

**Method**: `createBooking()`

**Parameters**:
```dart
{
  String userId,
  String serviceType,        // 'Wash & Fold', 'Wash & Iron', 'Dry Clean'
  double weight,              // in kg
  DateTime pickupDate,
  String pickupTime,
  String? specialInstructions,
}
```

**Returns**: `Future<bool>`

**Usage**:
```dart
final success = await ref.read(bookingProvider.notifier).createBooking(
  userId: currentUser.uid,
  serviceType: 'Wash & Iron',
  weight: 5.0,
  pickupDate: DateTime(2024, 12, 25),
  pickupTime: '10:00 AM',
  specialInstructions: 'Please separate whites',
);
```

**Auto-Generated Fields**:
- `bookingId`: UUID v4
- `bookingFee`: ₱20 (constant)
- `servicePrice`: Based on service type
- `totalAmount`: (weight × servicePrice) + bookingFee
- `status`: 'Pending'
- `paymentStatus`: 'Unpaid'
- `createdAt`: Current timestamp

**Firebase Operations**:
1. Generate unique bookingId
2. Calculate totalAmount
3. Store in Firestore `bookings` collection

---

### Get User Bookings

**Method**: `getUserBookings()`

**Parameters**:
```dart
String userId
```

**Returns**: `Future<void>`

**Usage**:
```dart
await ref.read(bookingProvider.notifier).getUserBookings(currentUser.uid);
```

**Firebase Operations**:
1. Query Firestore `bookings` where `userId == currentUser.uid`
2. Order by `createdAt` descending
3. Update BookingState

---

### Get Booking by ID

**Method**: `getBookingById()`

**Parameters**:
```dart
String bookingId
```

**Returns**: `Future<void>`

**Usage**:
```dart
await ref.read(bookingProvider.notifier).getBookingById('booking-id-123');
```

**Firebase Operations**:
1. Fetch booking document from Firestore
2. Update selectedBooking in BookingState

---

### Cancel Booking

**Method**: `cancelBooking()`

**Parameters**:
```dart
String bookingId
```

**Returns**: `Future<bool>`

**Usage**:
```dart
final success = await ref.read(bookingProvider.notifier).cancelBooking(
  'booking-id-123',
);
```

**Firebase Operations**:
1. Update booking status to 'Cancelled'
2. Update local BookingState

**Restrictions**:
- Only bookings with status 'Pending' or 'Confirmed' can be cancelled

---

### Calculate Total Amount

**Method**: `calculateTotalAmount()`

**Parameters**:
```dart
{
  String serviceType,
  double weight,
  double bookingFee,
}
```

**Returns**: `double`

**Usage**:
```dart
final total = ref.read(bookingProvider.notifier).calculateTotalAmount(
  serviceType: 'Wash & Iron',
  weight: 5.0,
  bookingFee: 20.0,
);
// Returns: 395.0 (5 × 75 + 20)
```

---

## Business Logic

### Service Pricing

```dart
const serviceTypes = {
  'Wash & Fold': 50.0,   // ₱50 per kg
  'Wash & Iron': 75.0,   // ₱75 per kg
  'Dry Clean': 100.0,    // ₱100 per kg
};
```

### Booking Fee

```dart
const double bookingFee = 20.0; // Fixed ₱20
```

### Total Amount Calculation

```dart
totalAmount = (weight × servicePrice) + bookingFee
```

**Examples**:

1. **Wash & Fold - 3 kg**
   - Service: 3 × 50 = ₱150
   - Booking Fee: ₱20
   - **Total: ₱170**

2. **Wash & Iron - 5 kg**
   - Service: 5 × 75 = ₱375
   - Booking Fee: ₱20
   - **Total: ₱395**

3. **Dry Clean - 2 kg**
   - Service: 2 × 100 = ₱200
   - Booking Fee: ₱20
   - **Total: ₱220**

---

## State Management

### AuthState

```dart
class AuthState {
  final bool isLoading;      // Loading indicator
  final UserEntity? user;    // Current logged-in user
  final String? error;       // Error message
}
```

**Accessing State**:
```dart
final authState = ref.watch(authProvider);
final currentUser = authState.user;
final isLoading = authState.isLoading;
```

---

### BookingState

```dart
class BookingState {
  final bool isLoading;                  // Loading indicator
  final List<BookingEntity> bookings;    // User's bookings
  final BookingEntity? selectedBooking;  // Currently selected booking
  final String? error;                   // Error message
}
```

**Accessing State**:
```dart
final bookingState = ref.watch(bookingProvider);
final bookings = bookingState.bookings;
final isLoading = bookingState.isLoading;
```

---

## UI Components

### Pages

#### 1. Login Page
**Path**: `lib/features/auth/presentation/pages/login_page.dart`

**Features**:
- Email & password input
- Password visibility toggle
- Form validation
- Navigate to Register page
- Navigate to Forgot Password page
- Auto-navigate to Home on success

---

#### 2. Register Page
**Path**: `lib/features/auth/presentation/pages/register_page.dart`

**Features**:
- Full name input
- Email input
- Phone number input
- Address input (multi-line)
- Password & confirm password
- Form validation
- Navigate back to Login
- Auto-navigate to Home on success

**Validations**:
- Email format validation
- Phone number format (10-11 digits)
- Password minimum 6 characters
- Password confirmation match

---

#### 3. Forgot Password Page
**Path**: `lib/features/auth/presentation/pages/forgot_password_page.dart`

**Features**:
- Email input
- Send reset link via Firebase
- Success message
- Auto-close on success

---

#### 4. Home Page
**Path**: `lib/features/booking/presentation/pages/home_page.dart`

**Features**:
- Welcome banner with user info
- List of all user bookings
- Status color coding
- Pull-to-refresh
- Navigate to Booking Details
- Floating action button to create booking
- Logout button

**Status Colors**:
- Pending: Orange
- Confirmed: Blue
- Washing: Purple
- Ready: Green
- Completed: Grey
- Cancelled: Red

---

#### 5. Create Booking Page
**Path**: `lib/features/booking/presentation/pages/create_booking_page.dart`

**Features**:
- Service type selection (radio buttons)
- Weight input with validation
- Date picker (future dates only)
- Time picker
- Special instructions (optional)
- Real-time price calculation
- Price summary card
- Form validation

**Validations**:
- Service type required
- Weight must be > 0
- Pickup date required (future only)
- Pickup time required

---

#### 6. Booking Details Page
**Path**: `lib/features/booking/presentation/pages/booking_details_page.dart`

**Features**:
- Status banner with icon
- Booking ID display
- Service details
- Pickup date & time
- Special instructions (if any)
- Price breakdown
- Payment status
- Cancel booking button (if eligible)
- Created timestamp

---

## Validation Rules

### Email Validation
```dart
RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
```

### Phone Validation
```dart
RegExp(r'^[0-9]{10,11}$')
```

### Password Rules
- Minimum 6 characters
- Must match confirmation on register

### Weight Rules
- Must be a valid number
- Must be greater than 0

### Date Rules
- Pickup date must be today or future date
- Maximum 30 days in advance

---

## Error Handling

### Error Messages

**Authentication Errors**:
- `weak-password` → "Password is too weak"
- `email-already-in-use` → "Email is already registered"
- `invalid-email` → "Invalid email address"
- `user-not-found` → "No user found with this email"
- `wrong-password` → "Wrong password"
- `user-disabled` → "This account has been disabled"

**Booking Errors**:
- Weight validation: "Please enter a valid weight"
- Service selection: "Please select a service type"
- Date selection: "Please select pickup date"
- Time selection: "Please select pickup time"

---

## Firestore Data Structure

### Users Collection

**Path**: `users/{userId}`

```json
{
  "uid": "string",
  "fullName": "string",
  "email": "string",
  "phoneNumber": "string",
  "address": "string",
  "role": "customer",
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

**Indexes**: None required (queries by document ID)

---

### Bookings Collection

**Path**: `bookings/{bookingId}`

```json
{
  "bookingId": "uuid-v4-string",
  "userId": "string",
  "serviceType": "Wash & Iron",
  "weight": 5.0,
  "bookingFee": 20.0,
  "servicePrice": 75.0,
  "totalAmount": 395.0,
  "pickupDate": "2024-12-25T00:00:00.000Z",
  "pickupTime": "10:00 AM",
  "status": "Pending",
  "paymentStatus": "Unpaid",
  "specialInstructions": "string or null",
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

**Indexes Required**:
- `userId` (ascending) + `createdAt` (descending)

---

## Utility Functions

### Format Currency
```dart
AppUtils.formatCurrency(395.0)
// Returns: "₱395.00"
```

### Show Snackbar
```dart
AppUtils.showSnackBar(context, 'Success message');
AppUtils.showSnackBar(context, 'Error message', isError: true);
```

### Email Validation
```dart
bool isValid = AppUtils.isValidEmail('test@example.com');
```

### Phone Validation
```dart
bool isValid = AppUtils.isValidPhone('09123456789');
```

---

## Testing Scenarios

### 1. User Registration Flow
1. Open app (shows Login page)
2. Click "Register"
3. Fill in all fields with valid data
4. Submit form
5. Verify user created in Firebase Console
6. Verify user data in Firestore
7. Verify navigation to Home page

### 2. Booking Creation Flow
1. Login as customer
2. Click "New Booking" FAB
3. Select "Wash & Iron"
4. Enter weight: 5 kg
5. Select date: Tomorrow
6. Select time: 10:00 AM
7. Add instruction: "Separate whites"
8. Verify total: ₱395
9. Submit booking
10. Verify booking appears in list
11. Verify booking data in Firestore

### 3. Booking Cancellation Flow
1. Login as customer
2. View booking with status "Pending"
3. Click booking card
4. Click "Cancel Booking"
5. Confirm cancellation
6. Verify status changed to "Cancelled"
7. Verify cannot cancel again

---

## Performance Considerations

### Current Implementation
- Real-time Firestore queries
- Automatic state updates
- Pull-to-refresh for manual sync

### Future Optimizations
1. **Pagination**: Load bookings in batches of 20
2. **Caching**: Store recent bookings locally
3. **Streaming**: Use Firestore snapshots for real-time updates
4. **Image Compression**: If adding photo uploads
5. **Lazy Loading**: Load booking details on demand

---

## Next Phase: Admin Panel

### Required Features
1. **Dashboard**
   - Total bookings count
   - Revenue statistics
   - Active customers count
   - Status breakdown chart

2. **Booking Management**
   - View all bookings (all users)
   - Update booking status
   - Update payment status
   - Filter by status, date, user

3. **User Management**
   - View all customers
   - View user details
   - View user booking history

4. **Settings**
   - Update service prices
   - Update booking fee
   - Manage service types

5. **Reports**
   - Daily/Weekly/Monthly revenue
   - Popular services
   - Customer analytics

---

## Security Best Practices

1. **Never store passwords in Firestore**
   - Firebase Auth handles password security

2. **Validate on both client and server**
   - Use Firestore Security Rules
   - Validate inputs in Flutter

3. **Use proper authentication**
   - Check user authentication before operations
   - Verify user ownership of data

4. **Rate limiting**
   - Implement in Firebase Security Rules
   - Prevent abuse

5. **Data privacy**
   - Only expose necessary user data
   - Don't show other users' bookings to customers

---

## Conclusion

This API documentation provides comprehensive coverage of all features in the Laundry Management System mobile app. The system is built with scalability, maintainability, and security in mind, following Clean Architecture principles and Flutter best practices.
