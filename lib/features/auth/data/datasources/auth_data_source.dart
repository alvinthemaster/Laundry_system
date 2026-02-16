import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/features/auth/data/models/user_model.dart';

abstract class AuthDataSource {
  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String address,
  });

  Future<UserModel> login({required String email, required String password});
  Future<void> logout();
  Future<UserModel?> getCurrentUser();
  Future<void> resetPassword({required String email});
  Future<bool> isLoggedIn();
  Future<void> sendEmailVerification();
  bool isEmailVerified();
  Stream<User?> authStateChanges();
}

class AuthDataSourceImpl implements AuthDataSource {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthDataSourceImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<UserModel> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String address,
  }) async {
    UserCredential? userCredential;
    try {
      // Step 1: Create Firebase Auth user
      userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user account');
      }

      // Step 2: Send email verification
      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Non-critical: continue even if verification email fails
      }

      // Step 3: Build Firestore document with serverTimestamp
      final now = DateTime.now();
      final userData = <String, dynamic>{
        'uid': user.uid,
        'fullName': fullName,
        'email': email,
        'phoneNumber': phoneNumber,
        'address': address,
        'role': AppConstants.roleCustomer,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Step 4: Write to Firestore (awaited — no race condition)
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .set(userData);

      // Step 5: Sign out so user must verify email before login
      await _firebaseAuth.signOut();

      // Return model with local DateTime (serverTimestamp is write-only)
      return UserModel(
        uid: user.uid,
        fullName: fullName,
        email: email,
        phoneNumber: phoneNumber,
        address: address,
        role: AppConstants.roleCustomer,
        createdAt: now,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } on FirebaseException catch (e) {
      // Firestore write failed — clean up auth user
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
        } catch (_) {}
      }
      throw Exception('Failed to save profile: ${e.message}');
    } catch (e) {
      // Any other error — clean up
      if (userCredential?.user != null) {
        try {
          await userCredential!.user!.delete();
        } catch (_) {}
      }
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception('Registration failed: $msg');
    }
  }

  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Login failed');
      }

      // Reload to get latest emailVerified status with better error handling
      try {
        await user.reload();
      } catch (reloadError) {
        // If reload fails, continue but log it
        print('User reload failed: $reloadError');
      }
      
      // Get fresh user instance with null safety
      final refreshedUser = _firebaseAuth.currentUser;
      final isVerified = refreshedUser?.emailVerified == true;

      // Block unverified users
      if (!isVerified) {
        await _firebaseAuth.signOut();
        throw Exception(
          'Please verify your email before logging in. Check your inbox for a verification link.',
        );
      }

      // Fetch profile from Firestore with better error handling
      try {
        final doc = await _firestore
            .collection(AppConstants.usersCollection)
            .doc(user.uid)
            .get();

        if (!doc.exists || doc.data() == null) {
          throw Exception('User profile not found. Please contact support.');
        }

        return UserModel.fromFirestore(doc.data()!);
      } catch (firestoreError) {
        // If Firestore fails, still sign out and throw error
        await _firebaseAuth.signOut();
        throw Exception('Failed to load user profile: $firestoreError');
      }
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      // Sign out on any error to prevent inconsistent state
      try {
        await _firebaseAuth.signOut();
      } catch (_) {}
      
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception(msg);
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;

      // Verify email is confirmed
      final isVerified = user.emailVerified == true;
      if (!isVerified) {
        return null;
      }

      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get();

      if (!doc.exists || doc.data() == null) {
        return null;
      }

      return UserModel.fromFirestore(doc.data()!);
    } catch (e) {
      // Log but don't throw - return null for safety
      print('getCurrentUser error: $e');
      return null;
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getAuthErrorMessage(e.code));
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      throw Exception('Password reset failed: $msg');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return false;
      
      // Reload user to get fresh data and avoid PigeonUserDetails issues
      await user.reload();
      
      // Get fresh instance after reload
      final freshUser = _firebaseAuth.currentUser;
      
      // Check both user exists and email is verified
      return freshUser != null && freshUser.emailVerified == true;
    } catch (e) {
      // If any error occurs during user data access, assume not logged in
      return false;
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user != null && user.emailVerified != true) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      // Ignore verification email errors to prevent crashes
      // The user can try resending from the UI
    }
  }

  @override
  bool isEmailVerified() {
    try {
      final user = _firebaseAuth.currentUser;
      return user?.emailVerified == true;
    } catch (e) {
      // If error accessing user data, assume not verified
      return false;
    }
  }

  @override
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'This email is already registered. Try logging in.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      default:
        return 'Authentication error: $code';
    }
  }
}
