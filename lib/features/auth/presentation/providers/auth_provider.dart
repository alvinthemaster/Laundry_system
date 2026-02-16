import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/features/auth/data/datasources/auth_data_source.dart';
import 'package:laundry_system/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:laundry_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/auth/domain/usecases/auth_usecases.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  return AuthDataSourceImpl();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.read(authDataSourceProvider));
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.read(authRepositoryProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.read(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.read(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(ref.read(authRepositoryProvider));
});

final resetPasswordUseCaseProvider = Provider<ResetPasswordUseCase>((ref) {
  return ResetPasswordUseCase(ref.read(authRepositoryProvider));
});

final sendEmailVerificationUseCaseProvider =
    Provider<SendEmailVerificationUseCase>((ref) {
  return SendEmailVerificationUseCase(ref.read(authRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

class AuthState {
  final bool isLoading;
  final UserEntity? user;
  final String? error;
  final String? successMessage;

  const AuthState({
    this.isLoading = false,
    this.user,
    this.error,
    this.successMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    UserEntity? user,
    String? error,
    String? successMessage,
    bool clearUser = false,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth Notifier
// ---------------------------------------------------------------------------

class AuthNotifier extends StateNotifier<AuthState> {
  final RegisterUseCase _registerUseCase;
  final LoginUseCase _loginUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final ResetPasswordUseCase _resetPasswordUseCase;
  final SendEmailVerificationUseCase _sendEmailVerificationUseCase;

  AuthNotifier(
    this._registerUseCase,
    this._loginUseCase,
    this._logoutUseCase,
    this._getCurrentUserUseCase,
    this._resetPasswordUseCase,
    this._sendEmailVerificationUseCase,
  ) : super(const AuthState());

  // ---- Register ----
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String address,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    final result = await _registerUseCase(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      address: address,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (user) {
        state = state.copyWith(
          isLoading: false,
          successMessage:
              'Registration successful! A verification email has been sent to $email. Please verify your email before logging in.',
        );
        return true;
      },
    );
  }

  // ---- Login ----
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    final result = await _loginUseCase(email: email, password: password);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (user) {
        state = state.copyWith(isLoading: false, user: user);
        return true;
      },
    );
  }

  // ---- Logout ----
  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await _logoutUseCase();
    state = const AuthState();
  }

  // ---- Get current user from Firestore ----
  Future<void> getCurrentUser() async {
    state = state.copyWith(isLoading: true);
    final result = await _getCurrentUserUseCase();
    result.fold(
      (failure) => state = state.copyWith(isLoading: false, error: failure.message),
      (user) {
        if (user != null) {
          state = state.copyWith(isLoading: false, user: user);
        } else {
          state = state.copyWith(isLoading: false, clearUser: true);
        }
      },
    );
  }

  // ---- Reset password ----
  Future<bool> resetPassword({required String email}) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    final result = await _resetPasswordUseCase(email: email);

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
    );
  }

  // ---- Resend verification email ----
  Future<bool> resendVerificationEmail() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _sendEmailVerificationUseCase();

    return result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.message);
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false);
        return true;
      },
    );
  }

  // ---- Clear messages ----
  void clearError() => state = state.copyWith(clearError: true);
  void clearSuccess() => state = state.copyWith(clearSuccess: true);
}

// ---------------------------------------------------------------------------
// Provider declaration
// ---------------------------------------------------------------------------

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(registerUseCaseProvider),
    ref.read(loginUseCaseProvider),
    ref.read(logoutUseCaseProvider),
    ref.read(getCurrentUserUseCaseProvider),
    ref.read(resetPasswordUseCaseProvider),
    ref.read(sendEmailVerificationUseCaseProvider),
  );
});
