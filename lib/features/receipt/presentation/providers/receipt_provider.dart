import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/features/receipt/data/datasources/receipt_data_source.dart';
import 'package:laundry_system/features/receipt/data/repositories/receipt_repository_impl.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';
import 'package:laundry_system/features/receipt/domain/repositories/receipt_repository.dart';
import 'package:laundry_system/features/receipt/domain/usecases/receipt_usecases.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final receiptDataSourceProvider = Provider<ReceiptDataSource>((ref) {
  return ReceiptDataSourceImpl();
});

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepositoryImpl(ref.read(receiptDataSourceProvider));
});

final getUserReceiptsUseCaseProvider = Provider<GetUserReceiptsUseCase>((ref) {
  return GetUserReceiptsUseCase(ref.read(receiptRepositoryProvider));
});

final getReceiptByIdUseCaseProvider = Provider<GetReceiptByIdUseCase>((ref) {
  return GetReceiptByIdUseCase(ref.read(receiptRepositoryProvider));
});

// ---------------------------------------------------------------------------
// Receipt State
// ---------------------------------------------------------------------------

class ReceiptState {
  final bool isLoading;
  final List<ReceiptEntity> receipts;
  final ReceiptEntity? selectedReceipt;
  final String? error;

  const ReceiptState({
    this.isLoading = false,
    this.receipts = const [],
    this.selectedReceipt,
    this.error,
  });

  ReceiptState copyWith({
    bool? isLoading,
    List<ReceiptEntity>? receipts,
    ReceiptEntity? selectedReceipt,
    String? error,
  }) {
    return ReceiptState(
      isLoading: isLoading ?? this.isLoading,
      receipts: receipts ?? this.receipts,
      selectedReceipt: selectedReceipt ?? this.selectedReceipt,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Receipt Notifier
// ---------------------------------------------------------------------------

class ReceiptNotifier extends StateNotifier<ReceiptState> {
  final GetUserReceiptsUseCase _getUserReceiptsUseCase;
  final GetReceiptByIdUseCase _getReceiptByIdUseCase;

  ReceiptNotifier(
    this._getUserReceiptsUseCase,
    this._getReceiptByIdUseCase,
  ) : super(const ReceiptState());

  Future<void> getUserReceipts(String userId) async {
    if (userId.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _getUserReceiptsUseCase(userId);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.toString());
      },
      (receipts) {
        state = state.copyWith(isLoading: false, receipts: receipts);
      },
    );
  }

  Future<void> getReceiptById(String receiptId) async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _getReceiptByIdUseCase(receiptId);

    result.fold(
      (failure) {
        state = state.copyWith(isLoading: false, error: failure.toString());
      },
      (receipt) {
        state =
            state.copyWith(isLoading: false, selectedReceipt: receipt);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Provider declaration
// ---------------------------------------------------------------------------

final receiptProvider =
    StateNotifierProvider<ReceiptNotifier, ReceiptState>((ref) {
  return ReceiptNotifier(
    ref.read(getUserReceiptsUseCaseProvider),
    ref.read(getReceiptByIdUseCaseProvider),
  );
});
