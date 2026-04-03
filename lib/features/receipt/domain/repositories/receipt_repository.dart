import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';

abstract class ReceiptRepository {
  Future<Either<Failure, List<ReceiptEntity>>> getUserReceipts(String userId);
  Future<Either<Failure, ReceiptEntity>> getReceiptById(String receiptId);
}
