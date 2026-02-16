import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/data/datasources/auth_data_source.dart';
import 'package:laundry_system/features/auth/domain/entities/user_entity.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;

  const AuthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String address,
  }) async {
    try {
      final user = await dataSource.register(
        email: email,
        password: password,
        fullName: fullName,
        phoneNumber: phoneNumber,
        address: address,
      );
      return Either.right(user);
    } catch (e) {
      return Either.left(AuthFailure(_cleanError(e)));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await dataSource.login(email: email, password: password);
      return Either.right(user);
    } catch (e) {
      return Either.left(AuthFailure(_cleanError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await dataSource.logout();
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(_cleanError(e)));
    }
  }

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async {
    try {
      final user = await dataSource.getCurrentUser();
      return Either.right(user);
    } catch (e) {
      return Either.left(AuthFailure(_cleanError(e)));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword({required String email}) async {
    try {
      await dataSource.resetPassword(email: email);
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(_cleanError(e)));
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    return await dataSource.isLoggedIn();
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      await dataSource.sendEmailVerification();
      return Either.right(null);
    } catch (e) {
      return Either.left(AuthFailure(_cleanError(e)));
    }
  }

  @override
  bool isEmailVerified() {
    return dataSource.isEmailVerified();
  }

  String _cleanError(Object e) {
    return e.toString().replaceAll('Exception: ', '');
  }
}
