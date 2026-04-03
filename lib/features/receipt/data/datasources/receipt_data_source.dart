import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/features/receipt/data/models/receipt_model.dart';

abstract class ReceiptDataSource {
  Future<List<ReceiptModel>> getUserReceipts(String userId);
  Future<ReceiptModel> getReceiptById(String receiptId);
}

class ReceiptDataSourceImpl implements ReceiptDataSource {
  final FirebaseFirestore _firestore;

  ReceiptDataSourceImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<ReceiptModel>> getUserReceipts(String userId) async {
    // Query by userId only — sort client-side to avoid requiring a composite index.
    final snapshot = await _firestore
        .collection(AppConstants.receiptsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    final receipts = snapshot.docs.map((doc) {
      final data = doc.data();
      if (!data.containsKey('receiptId') || data['receiptId'] == null) {
        data['receiptId'] = doc.id;
      }
      return ReceiptModel.fromJson(data);
    }).toList();

    // Sort by createdAt descending (most recent first)
    receipts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return receipts;
  }

  @override
  Future<ReceiptModel> getReceiptById(String receiptId) async {
    final doc = await _firestore
        .collection(AppConstants.receiptsCollection)
        .doc(receiptId)
        .get();

    if (!doc.exists) {
      throw Exception('Receipt not found');
    }

    final data = doc.data()!;
    if (!data.containsKey('receiptId') || data['receiptId'] == null) {
      data['receiptId'] = doc.id;
    }
    return ReceiptModel.fromJson(data);
  }
}
