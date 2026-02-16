# Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Step 1: Install Dependencies (1 min)

```bash
cd Laundry_system
flutter pub get
```

### Step 2: Configure Firebase (2 min)

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Login to Firebase
firebase login

# Configure project
flutterfire configure
```

Select your Firebase project or create a new one. Choose Android/iOS platforms.

### Step 3: Set Up Firebase Console (1 min)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Enable **Email/Password** authentication
4. Create **Firestore Database** in test mode

### Step 4: Run the App (1 min)

```bash
flutter run
```

That's it! 🎉

---

## 📱 Test the App

### Create Your First User
1. Click "Register"
2. Enter details:
   - Name: John Doe
   - Email: john@example.com
   - Phone: 09123456789
   - Address: 123 Main St
   - Password: password123
3. Click "Register"

### Create Your First Booking
1. Click "New Booking" button
2. Select "Wash & Iron"
3. Enter weight: 5 kg
4. Select tomorrow's date
5. Select time: 10:00 AM
6. Click "Create Booking"

### View Booking
- See your booking on the home page
- Click it to view details
- Try cancelling it

---

## 🔥 Firebase Console Checklist

### Authentication
- [x] Email/Password enabled

### Firestore Database
- [x] Database created
- [x] Security rules configured (optional for testing)

### Collections (Auto-created on first use)
- `users` - Created when first user registers
- `bookings` - Created when first booking is made

---

## 📂 Project Files Overview

### Core Files
- `lib/main.dart` - App entry point
- `lib/firebase_options.dart` - Firebase configuration
- `pubspec.yaml` - Dependencies

### Authentication Feature
```
lib/features/auth/
├── domain/          # Business logic
├── data/            # Firebase integration
└── presentation/    # UI pages
    ├── login_page.dart
    ├── register_page.dart
    └── forgot_password_page.dart
```

### Booking Feature
```
lib/features/booking/
├── domain/          # Business logic
├── data/            # Firebase integration
└── presentation/    # UI pages
    ├── home_page.dart
    ├── create_booking_page.dart
    └── booking_details_page.dart
```

---

## 🎯 Key Features Implemented

✅ User Registration & Login  
✅ Password Reset  
✅ Service Selection (3 types)  
✅ Weight-based Pricing  
✅ Date & Time Picker  
✅ Real-time Price Calculation  
✅ Booking Management  
✅ Status Tracking  
✅ Booking Cancellation  

---

## 💡 Quick Tips

### Running on Physical Device

**Android:**
```bash
# Enable USB debugging on your phone
flutter run
```

**iOS:**
```bash
flutter run
# May require Apple Developer account for physical device
```

### Running on Emulator

```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

### Hot Reload

While app is running:
- Press `r` for hot reload
- Press `R` for hot restart
- Press `q` to quit

---

## 🐛 Common Issues & Fixes

### Issue: "Firebase not configured"

**Fix:**
```bash
flutterfire configure
```

### Issue: "Package not found"

**Fix:**
```bash
flutter clean
flutter pub get
```

### Issue: Build fails

**Fix:**
```bash
# Update Flutter
flutter upgrade

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

### Issue: "Permission denied" errors on macOS/Linux

**Fix:**
```bash
# Make FlutterFire CLI executable
dart pub global activate flutterfire_cli
export PATH="$PATH:$HOME/.pub-cache/bin"
```

---

## 📊 Testing Credentials

Create test users with these patterns:

| Name | Email | Phone | Password |
|------|-------|-------|----------|
| Test User 1 | test1@example.com | 09123456781 | test123456 |
| Test User 2 | test2@example.com | 09123456782 | test123456 |
| Test User 3 | test3@example.com | 09123456783 | test123456 |

---

## 📖 Documentation

- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed setup instructions
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture documentation
- [API_DOCUMENTATION.md](API_DOCUMENTATION.md) - Complete API reference

---

## 🎨 Service Pricing

| Service | Price per kg | Example (5kg) |
|---------|-------------|---------------|
| Wash & Fold | ₱50 | ₱250 + ₱20 = ₱270 |
| Wash & Iron | ₱75 | ₱375 + ₱20 = ₱395 |
| Dry Clean | ₱100 | ₱500 + ₱20 = ₱520 |

*₱20 booking fee added to all orders*

---

## 🚀 Next Steps

1. **Test all features** - Register, login, create bookings
2. **Customize styling** - Modify colors in `lib/core/theme/app_theme.dart`
3. **Add features** - Implement additional requirements
4. **Build Web Admin** - Create admin panel for managing bookings
5. **Deploy** - Prepare for production deployment

---

## 📞 Need Help?

Check the detailed guides:
- Setup issues → [SETUP_GUIDE.md](SETUP_GUIDE.md)
- Architecture questions → [ARCHITECTURE.md](ARCHITECTURE.md)
- API usage → [API_DOCUMENTATION.md](API_DOCUMENTATION.md)

---

## ✨ You're All Set!

Your Laundry Management System is ready to use. Start testing and building more features! 🎉
