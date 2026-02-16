# Laundry Management System - Setup Guide

## Prerequisites

- Flutter SDK (3.0.0 or higher)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Firebase account
- Git

## Step 1: Install Dependencies

Open terminal in the project directory and run:

```bash
flutter pub get
```

## Step 2: Firebase Setup

### 2.1 Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Enter project name: `laundry-system` (or your preferred name)
4. Disable Google Analytics (optional)
5. Click "Create project"

### 2.2 Enable Authentication

1. In Firebase Console, go to **Authentication**
2. Click "Get started"
3. Enable **Email/Password** sign-in method
4. Click "Save"

### 2.3 Create Firestore Database

1. In Firebase Console, go to **Firestore Database**
2. Click "Create database"
3. Choose **Start in test mode** (for development)
4. Select your preferred location
5. Click "Enable"

### 2.4 Configure Firestore Security Rules

Go to **Firestore Database > Rules** and replace with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Bookings collection
    match /bookings/{bookingId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
  }
}
```

Click "Publish"

### 2.5 Install FlutterFire CLI

```bash
# Install FlutterFire CLI globally
dart pub global activate flutterfire_cli
```

### 2.6 Configure Firebase for Flutter

```bash
# Login to Firebase
firebase login

# Configure FlutterFire
flutterfire configure
```

Select your Firebase project and choose platforms (Android, iOS, Web).

This will automatically generate `lib/firebase_options.dart` with your Firebase configuration.

## Step 3: Run the App

### For Android

```bash
flutter run
```

### For iOS (Mac only)

```bash
cd ios
pod install
cd ..
flutter run
```

### For Web

```bash
flutter run -d chrome
```

## Step 4: Test the Application

### 4.1 Register a New User

1. Open the app
2. Click "Register"
3. Fill in the registration form:
   - Full Name
   - Email
   - Phone Number
   - Address
   - Password
4. Click "Register"

### 4.2 Create a Booking

1. After login, you'll be on the Home page
2. Click the "New Booking" button
3. Select service type (Wash & Fold, Wash & Iron, or Dry Clean)
4. Enter weight in kg
5. Select pickup date and time
6. Add special instructions (optional)
7. Review the price summary
8. Click "Create Booking"

### 4.3 View Booking Details

1. On the Home page, click on any booking card
2. View complete booking details
3. Cancel booking if status is "Pending" or "Confirmed"

## Troubleshooting

### Error: Firebase not configured

If you get Firebase configuration errors, make sure:
1. You ran `flutterfire configure`
2. The `firebase_options.dart` file exists in `lib/` folder
3. You selected the correct Firebase project

### Error: Version conflict

Run:
```bash
flutter clean
flutter pub get
```

### Error: Build failed

1. Check Flutter version: `flutter --version`
2. Update Flutter: `flutter upgrade`
3. Check Dart version compatibility in `pubspec.yaml`

## Project Structure

```
lib/
├── core/
│   ├── constants/
│   │   └── app_constants.dart
│   ├── errors/
│   │   └── failures.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── utils/
│       └── app_utils.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── auth_data_source.dart
│   │   │   ├── models/
│   │   │   │   └── user_model.dart
│   │   │   └── repositories/
│   │   │       └── auth_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── user_entity.dart
│   │   │   ├── repositories/
│   │   │   │   └── auth_repository.dart
│   │   │   └── usecases/
│   │   │       └── auth_usecases.dart
│   │   └── presentation/
│   │       ├── pages/
│   │       │   ├── login_page.dart
│   │       │   ├── register_page.dart
│   │       │   └── forgot_password_page.dart
│   │       └── providers/
│   │           └── auth_provider.dart
│   └── booking/
│       ├── data/
│       │   ├── datasources/
│       │   │   └── booking_data_source.dart
│       │   ├── models/
│       │   │   └── booking_model.dart
│       │   └── repositories/
│       │       └── booking_repository_impl.dart
│       ├── domain/
│       │   ├── entities/
│       │   │   └── booking_entity.dart
│       │   ├── repositories/
│       │   │   └── booking_repository.dart
│       │   └── usecases/
│       │       └── booking_usecases.dart
│       └── presentation/
│           ├── pages/
│           │   ├── home_page.dart
│           │   ├── create_booking_page.dart
│           │   └── booking_details_page.dart
│           └── providers/
│               └── booking_provider.dart
├── firebase_options.dart
└── main.dart
```

## Features Implemented

### Authentication Module ✅
- [x] User Registration with Email/Password
- [x] User Login
- [x] Logout
- [x] Forgot Password
- [x] User Profile Storage in Firestore

### Booking Module ✅
- [x] Create Booking with Service Selection
- [x] Choose Pickup Date & Time
- [x] Weight-based Pricing Calculation
- [x] Automatic ₱20 Booking Fee
- [x] View All User Bookings
- [x] View Booking Details
- [x] Cancel Booking
- [x] Real-time Status Display
- [x] Special Instructions

### Service Types ✅
- [x] Wash & Fold (₱50/kg)
- [x] Wash & Iron (₱75/kg)
- [x] Dry Clean (₱100/kg)

### Booking Statuses ✅
- Pending
- Confirmed
- Washing
- Ready
- Completed
- Cancelled

## Next Steps for Web Admin Panel

The web admin panel should include:
1. View all bookings from all users
2. Update booking status (Pending → Confirmed → Washing → Ready → Completed)
3. Update payment status
4. View customer details
5. Dashboard with statistics
6. Manage service prices

## Support

For issues or questions, please check:
1. Flutter documentation: https://flutter.dev/docs
2. Firebase documentation: https://firebase.google.com/docs
3. Riverpod documentation: https://riverpod.dev/

## License

This project is for educational/capstone purposes.
