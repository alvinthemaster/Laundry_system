# Laundry Management System

A comprehensive laundry management system built with Flutter and Firebase.

## Features

### Mobile App (Customer Side)
- User Authentication (Register, Login, Forgot Password)
- Service Booking (Wash & Fold, Wash & Iron, Dry Clean)
- Real-time Booking Status Tracking
- Profile Management

## Tech Stack
- **Frontend**: Flutter
- **Backend**: Firebase (Auth, Firestore)
- **State Management**: Riverpod
- **Architecture**: Clean Architecture

## Project Structure
```
lib/
├── core/                 # Core utilities, constants, theme
├── features/            # Feature modules
│   ├── auth/           # Authentication feature
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── booking/        # Booking feature
│       ├── data/
│       ├── domain/
│       └── presentation/
└── main.dart
```

## Setup

### ✅ Firebase Connected!

Your app is now connected to **Firebase Project: franz-laundry-hub**

**Quick Start:**

1. **Enable Firebase Services** (Required - 5 minutes):
   - Go to [Firebase Console](https://console.firebase.google.com/project/franz-laundry-hub)
   - Enable **Email/Password Authentication**
   - Create **Firestore Database** (test mode)
   - Update **Security Rules** (see [START_HERE.md](START_HERE.md))

2. **Run the app**:
   ```bash
   # Option 1: Launch emulator
   flutter emulators --launch Medium_Phone_API_36.1
   flutter run
   
   # Option 2: Run on Chrome (for quick testing)
   flutter run -d chrome
   ```

📖 **See [START_HERE.md](START_HERE.md) for detailed instructions!**
