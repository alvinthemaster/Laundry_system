import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;
  const RegisterUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String address,
  }) {
    return repository.register(
      email: email,
      password: password,
      fullName: fullName,
      phoneNumber: phoneNumber,
      address: address,
    );
  }
}

class LoginUseCase {
  final AuthRepository repository;
  const LoginUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String email,
    required String password,
  }) {
    return repository.login(email: email, password: password);
  }
}

class LogoutUseCase {
  final AuthRepository repository;
  const LogoutUseCase(this.repository);

  Future<Either<Failure, void>> call() {
    return repository.logout();
  }
}

class GetCurrentUserUseCase {
  final AuthRepository repository;
  const GetCurrentUserUseCase(this.repository);

  Future<Either<Failure, UserEntity?>> call() {
    return repository.getCurrentUser();
  }
}

class ResetPasswordUseCase {
  final AuthRepository repository;
  const ResetPasswordUseCase(this.repository);

  Future<Either<Failure, void>> call({required String email}) {
    return repository.resetPassword(email: email);
  }
}

class SendEmailVerificationUseCase {
  final AuthRepository repository;
  const SendEmailVerificationUseCase(this.repository);

  Future<Either<Failure, void>> call() {
    return repository.sendEmailVerification();
  }
}
