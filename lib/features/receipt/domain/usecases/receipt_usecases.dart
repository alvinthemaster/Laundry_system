import 'package:laundry_system/core/errors/failures.dart';
import 'package:laundry_system/features/auth/domain/repositories/auth_repository.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';
import 'package:laundry_system/features/receipt/domain/repositories/receipt_repository.dart';

class GetUserReceiptsUseCase {
  final ReceiptRepository repository;

  const GetUserReceiptsUseCase(this.repository);

  Future<Either<Failure, List<ReceiptEntity>>> call(String userId) {
    return repository.getUserReceipts(userId);
  }
}

class GetReceiptByIdUseCase {
  final ReceiptRepository repository;

  const GetReceiptByIdUseCase(this.repository);

  Future<Either<Failure, ReceiptEntity>> call(String receiptId) {
    return repository.getReceiptById(receiptId);
  }
}
