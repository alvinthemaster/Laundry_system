import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/receipt/data/datasources/receipt_data_source.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';
import 'package:laundry_system/features/receipt/domain/repositories/receipt_repository.dart';

class ReceiptRepositoryImpl implements ReceiptRepository {
  final ReceiptDataSource dataSource;

  const ReceiptRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<ReceiptEntity>>> getUserReceipts(
      String userId) async {
    try {
      final receipts = await dataSource.getUserReceipts(userId);
      return Either.right(receipts);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ReceiptEntity>> getReceiptById(
      String receiptId) async {
    try {
      final receipt = await dataSource.getReceiptById(receiptId);
      return Either.right(receipt);
    } catch (e) {
      return Either.left(ServerFailure(e.toString()));
    }
  }
}
