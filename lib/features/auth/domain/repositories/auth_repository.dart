import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> register({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String address,
  });

  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, UserEntity?>> getCurrentUser();

  Future<Either<Failure, void>> resetPassword({required String email});

  Future<bool> isLoggedIn();

  Future<Either<Failure, void>> sendEmailVerification();

  bool isEmailVerified();
}

/// Lightweight Either type for functional error handling.
class Either<L, R> {
  final L? _left;
  final R? _right;
  final bool _isLeft;

  const Either._({L? left, R? right, required bool isLeft})
      : _left = left,
        _right = right,
        _isLeft = isLeft;

  factory Either.left(L value) => Either._(left: value, isLeft: true);
  factory Either.right(R value) => Either._(right: value, isLeft: false);

  bool get isLeftValue => _isLeft;
  bool get isRightValue => !_isLeft;

  T fold<T>(T Function(L) leftFn, T Function(R) rightFn) {
    if (_isLeft) {
      return leftFn(_left as L);
    }
    return rightFn(_right as R);
  }
}
