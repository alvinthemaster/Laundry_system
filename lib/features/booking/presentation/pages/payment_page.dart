import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/utils/app_utils.dart';

class PaymentResult {
  final String paymentMethod;
  final String? paymentProofDataUri;

  const PaymentResult({
    required this.paymentMethod,
    this.paymentProofDataUri,
  });
}

class PaymentPage extends StatefulWidget {
  final double totalAmount;
  final List<Map<String, String>> reservationDetails;
  final VoidCallback onPaymentComplete;
  final String screenTitle;
  final String submitButtonLabel;
  final String successMessage;
  final String amountSummaryLabel;

  const PaymentPage({
    super.key,
    required this.totalAmount,
    required this.reservationDetails,
    required this.onPaymentComplete,
    this.screenTitle = 'Confirm Reservation',
    this.submitButtonLabel = 'Done',
    this.successMessage = 'Reservation confirmed.',
    this.amountSummaryLabel = 'Total Amount Reservation',
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const String _storeQrAssetPath = 'assets/store_gcash_qr.png';
  static const String _fallbackQrUrl =
      'https://api.qrserver.com/v1/create-qr-code/?size=520x520&data=Laundry%20Store%20GCash';

  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;
  Uint8List? _proofBytes;
  String? _paymentProofDataUri;

  String _formatWholePeso(double amount) {
    return '₱${amount.round()}';
  }

  Future<void> _downloadStoreQr() async {
    try {
      Uint8List bytes;
      String fileName;

      try {
        final data = await rootBundle.load(_storeQrAssetPath);
        bytes = data.buffer.asUint8List();
        fileName = 'store_gcash_qr';
      } catch (_) {
        final data = await NetworkAssetBundle(Uri.parse(_fallbackQrUrl))
            .load(_fallbackQrUrl);
        bytes = data.buffer.asUint8List();
        fileName = 'store_gcash_qr_stock';
      }

      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: fileName,
      );

      final success = (result['isSuccess'] == true) || (result['success'] == true);

      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        success
            ? 'QR downloaded to your gallery.'
            : 'Failed to download QR. Please try again.',
        isError: !success,
      );
    } catch (e) {
      if (!mounted) return;
      AppUtils.showSnackBar(
        context,
        'Failed to download QR: $e',
        isError: true,
      );
    }
  }

  Future<void> _pickProofScreenshot() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 65,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();
    final ext = image.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final base64Image = base64Encode(bytes);

    if (!mounted) return;
    setState(() {
      _proofBytes = bytes;
      _paymentProofDataUri = 'data:image/$ext;base64,$base64Image';
    });
  }

  Future<void> _processPayment() async {
    if (_paymentProofDataUri == null) {
      AppUtils.showSnackBar(
        context,
        'Please attach your GCash payment screenshot',
        isError: true,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    AppUtils.showSnackBar(context, widget.successMessage);

    Navigator.of(context).pop(
      PaymentResult(
        paymentMethod: AppConstants.paymentGCash,
        paymentProofDataUri: _paymentProofDataUri,
      ),
    );

    widget.onPaymentComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.screenTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Details',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: widget.reservationDetails
                    .map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                '${entry['label']}:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(entry['value'] ?? '-'),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Payment Method',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.primary, width: 2),
                borderRadius: BorderRadius.circular(12),
                color: theme.colorScheme.primary.withOpacity(0.05),
              ),
              child: const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'GCash only',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.check_circle),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan Store GCash QR',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  _storeQrAssetPath,
                  width: 220,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.network(
                    _fallbackQrUrl,
                    width: 220,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _downloadStoreQr,
              icon: const Icon(Icons.download_rounded),
              label: const Text('Download QR'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickProofScreenshot,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_proofBytes == null
                  ? 'Attach GCash Payment Screenshot'
                  : 'Change Screenshot'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            if (_proofBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _proofBytes!,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon container
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: theme.colorScheme.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Text column
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.amountSummaryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatWholePeso(widget.totalAmount),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processPayment,
                  icon: _isProcessing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(
                    _isProcessing ? 'Processing...' : widget.submitButtonLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
