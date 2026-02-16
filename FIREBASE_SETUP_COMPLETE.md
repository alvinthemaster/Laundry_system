# Firebase Connection - Setup Complete! ✅

## ✅ What's Been Configured

### 1. Firebase Options Updated
- **Project ID**: franz-laundry-hub
- **API Key**: AIzaSyC73F5aIRm-F5YMJ3Y0ocmtkU86GAwmFIU
- **App ID**: 1:883166873265:android:c4829e36b8aab757008490
- **Package Name**: com.laundry.system

### 2. Android Project Created
✅ `google-services.json` placed in `android/app/`  
✅ Build configuration files created  
✅ Android Manifest configured  
✅ Firebase SDK integrated  
✅ Gradle wrapper configured  

### 3. Files Created
- `android/app/google-services.json`
- `android/build.gradle`
- `android/app/build.gradle`
- `android/settings.gradle`
- `android/gradle.properties`
- `android/app/src/main/AndroidManifest.xml`
- `android/app/src/main/kotlin/com/laundry/system/MainActivity.kt`
- Resource files (styles, drawables)
- `lib/firebase_options.dart` (updated with real credentials)

---

## 🔥 Firebase Console Setup Required

Before running the app, you need to enable services in Firebase Console:

### Step 1: Go to Firebase Console
Visit: https://console.firebase.google.com/project/franz-laundry-hub

### Step 2: Enable Authentication
1. Click **Authentication** in left sidebar
2. Click **Get started**
3. Click **Sign-in method** tab
4. Click **Email/Password**
5. Toggle **Enable** switch
6. Click **Save**

### Step 3: Create Firestore Database
1. Click **Firestore Database** in left sidebar
2. Click **Create database**
3. Select **Start in test mode** (for development)
4. Choose your preferred location (asia-southeast1 recommended)
5. Click **Enable**

### Step 4: Update Security Rules (Important!)
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

Click **Publish**

---

## 🚀 Running the App

### Option 1: With Physical Android Device

1. **Enable Developer Mode** on your Android phone:
   - Go to Settings > About Phone
   - Tap "Build Number" 7 times
   - Go back to Settings > Developer Options
   - Enable "USB Debugging"

2. **Connect your phone** to computer via USB

3. **Run the app**:
   ```bash
   flutter devices
   flutter run
   ```

### Option 2: With Android Emulator

1. **Open Android Studio**
2. **Tools > Device Manager**
3. **Create or start an emulator**
4. **Run the app**:
   ```bash
   flutter run
   ```

---

## 🧪 Testing the Connection

### Test 1: Register a New User
1. Launch app
2. Click "Register"
3. Fill in details:
   - Name: Test User
   - Email: test@example.com
   - Phone: 09123456789
   - Address: 123 Main St
   - Password: test123456
4. Click "Register"

**Expected Result**: 
- User created successfully
- Redirected to Home page
- Check Firebase Console > Authentication > Users (should see new user)

### Test 2: Check Firestore
1. Go to Firebase Console
2. Click Firestore Database
3. You should see `users` collection
4. Click on the user document - should see user data

### Test 3: Create a Booking
1. Click "New Booking" button
2. Select "Wash & Iron"
3. Enter weight: 5 kg
4. Select date: Tomorrow
5. Select time: 10:00 AM
6. Click "Create Booking"

**Expected Result**:
- Booking created successfully
- Appears in bookings list
- Check Firestore > bookings collection (should see new booking)

---

## 🐛 Troubleshooting

### Error: "No Firebase App '[DEFAULT]' has been created"

**Fix**: Make sure Firebase is initialized. Check `main.dart`:
```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

### Error: "Google Services configuration file is missing"

**Fix**: Verify `google-services.json` exists at:
```
android/app/google-services.json
```

### Error: Build fails with Gradle error

**Fix 1**: Update `android/local.properties` with correct paths:
```properties
sdk.dir=YOUR_ANDROID_SDK_PATH
flutter.sdk=YOUR_FLUTTER_SDK_PATH
```

**Fix 2**: Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter run
```

### Error: "FirebaseException: Permission denied"

**Fix**: Update Firestore Security Rules in Firebase Console (see Step 4 above)

### Error: "App crashes on startup"

**Fix**: Check Firebase Console logs:
1. Go to Firebase Console > Crashlytics (if enabled)
2. Or check Android Logcat in Android Studio

---

## ✅ Verification Checklist

Before testing, ensure:
- [x] `google-services.json` is in `android/app/`
- [x] `firebase_options.dart` has real credentials (not placeholders)
- [x] Firebase Console: Authentication enabled
- [x] Firebase Console: Firestore created
- [x] Firebase Console: Security rules updated
- [ ] Android device/emulator connected
- [ ] Run `flutter devices` shows a device
- [ ] Run `flutter run` successfully

---

## 📱 Expected Package Name

Your app package name is: **com.laundry.system**

This must match in:
- ✅ `google-services.json` (already set)
- ✅ `android/app/build.gradle` (already set)
- ✅ Firebase Console Android app configuration

---

## 🎯 Next Steps After Successful Connection

1. **Test all authentication features**:
   - Register
   - Login
   - Logout
   - Forgot Password

2. **Test booking features**:
   - Create booking (all 3 service types)
   - View bookings list
   - View booking details
   - Cancel booking

3. **Verify Firebase data**:
   - Check `users` collection in Firestore
   - Check `bookings` collection in Firestore
   - Verify data structure matches schema

4. **Optional: Add test data**:
   - Create multiple users
   - Create multiple bookings
   - Test different scenarios

---

## 📞 Support

If you encounter issues:

1. **Check Firebase Console Logs**
2. **Check Android Logcat** (in Android Studio)
3. **Verify all files exist** (see Files Created section)
4. **Check Flutter doctor**: `flutter doctor -v`
5. **Clean and rebuild**: `flutter clean && flutter pub get`

---

## 🎉 You're All Set!

Your app is now connected to Firebase "franz-laundry-hub"! 

Run `flutter run` and start testing! 🚀

---

**Connection Status**: ✅ CONNECTED  
**Firebase Project**: franz-laundry-hub  
**Package Name**: com.laundry.system  
**Last Updated**: February 16, 2026
