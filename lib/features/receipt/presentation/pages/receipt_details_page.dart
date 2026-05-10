import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';

class ReceiptDetailsPage extends StatelessWidget {
  final ReceiptEntity receipt;

  const ReceiptDetailsPage({super.key, required this.receipt});

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'paid':
        return Colors.green;
      case 'half paid':
        return Colors.orange;
      case 'unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDelivery =
        (receipt.bookingType ?? '').toLowerCase() == 'delivery';

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            _buildHeader(theme),
            const SizedBox(height: 20),

            // ── Customer / Delivery Info ──
            _buildSection(
              theme,
              title: isDelivery ? 'Delivery Information' : 'Booking Information',
              icon: isDelivery ? Icons.delivery_dining : Icons.local_laundry_service,
              children: [
                if (receipt.customerName != null)
                  _infoRow('Customer', receipt.customerName!),
                _infoRow('Type',
                    isDelivery ? 'Delivery' : 'Walk-in / Pickup'),
                if (receipt.bookingDate != null)
                  _infoRow(
                    'Date',
                    DateFormat('EEEE, MMMM d, yyyy')
                        .format(receipt.bookingDate!),
                  ),
                if (receipt.serviceType != null)
                  _infoRow('Service', receipt.serviceType!),
                if (isDelivery && receipt.deliveryAddress != null)
                  _infoRow('Address', receipt.deliveryAddress!),
                if (isDelivery && receipt.driverName != null)
                  _infoRow('Driver', receipt.driverName!),
                if (!isDelivery && receipt.machineName != null)
                  _infoRow('Machine', receipt.machineName!),
                if (!isDelivery && receipt.timeSlot != null)
                  _infoRow('Time Slot', receipt.timeSlot!),
              ],
            ),
            const SizedBox(height: 16),

            // ── Laundry Items ──
            if (receipt.categories.isNotEmpty) ...[
              _buildSection(
                theme,
                title: 'Laundry Items',
                icon: Icons.local_laundry_service_outlined,
                children: receipt.categories.map((cat) {
                  final name = cat['name'] as String? ?? 'Item';
                  final weight =
                      (cat['weight'] as num?)?.toDouble() ?? 0.0;
                  final price =
                      (cat['computedPrice'] as num?)?.toDouble() ?? 0.0;
                  return _priceRow(
                    '$name${weight > 0 ? ' (${weight.toStringAsFixed(1)} kg)' : ''}',
                    price > 0 ? AppUtils.formatCurrency(price) : '',
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Add-ons ──
            if (receipt.addOns.isNotEmpty) ...[
              _buildSection(
                theme,
                title: 'Add-ons',
                icon: Icons.add_circle_outline,
                children: receipt.addOns.map((addon) {
                  final name = addon['name'] as String? ?? 'Add-on';
                  final price =
                      (addon['price'] as num?)?.toDouble() ?? 0.0;
                  return _priceRow(name, AppUtils.formatCurrency(price));
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // ── Price Breakdown ──
            _buildSection(
              theme,
              title: 'Price Breakdown',
              icon: Icons.receipt_outlined,
              children: [
                if (receipt.bookingFee > 0)
                  _priceRow('Booking Fee',
                      AppUtils.formatCurrency(receipt.bookingFee)),
                if (receipt.addOnsTotal > 0)
                  _priceRow('Add-ons',
                      AppUtils.formatCurrency(receipt.addOnsTotal)),
                if (receipt.deliveryFee > 0)
                  _priceRow('Delivery Fee',
                      AppUtils.formatCurrency(receipt.deliveryFee)),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppUtils.formatCurrency(receipt.totalAmount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Payment ──
            _buildSection(
              theme,
              title: 'Payment',
              icon: Icons.payment,
              children: [
                _infoRow('Status', receipt.status,
                    valueColor: _statusColor(receipt.status)),
                if (receipt.paymentMethod != null)
                  _infoRow('Method', receipt.paymentMethod!),
                _infoRow(
                  'Issued',
                  DateFormat('MMM d, yyyy – h:mm a')
                      .format(receipt.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Delivery Proof Photo ──
            if (receipt.deliveryProofUrl != null) ...[
              _buildSection(
                theme,
                title: 'Delivery Proof',
                icon: Icons.photo_camera,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildProofImage(receipt.deliveryProofUrl!),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Photo taken by driver at time of delivery',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Header card ──────────────────────────────────────────────────────────

  Widget _buildHeader(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.receipt_long, color: Colors.white, size: 32),
              _statusChip(receipt.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Receipt #${receipt.receiptId.length > 12 ? receipt.receiptId.substring(0, 12) : receipt.receiptId}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            AppUtils.formatCurrency(receipt.totalAmount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ── Section card ─────────────────────────────────────────────────────────

  /// Renders the delivery proof photo whether it's a base64 data URI
  /// (stored in Firestore on Spark plan) or a regular HTTPS URL.
  Widget _buildProofImage(String url) {
    if (url.startsWith('data:image')) {
      // Extract the base64 payload after the comma
      final commaIndex = url.indexOf(',');
      if (commaIndex != -1) {
        try {
          final bytes = base64Decode(url.substring(commaIndex + 1));
          return Image.memory(
            Uint8List.fromList(bytes),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
          );
        } catch (_) {
          return _brokenImagePlaceholder();
        }
      }
      return _brokenImagePlaceholder();
    }
    // Regular URL
    return Image.network(
      url,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (ctx, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          height: 180,
          child: Center(
            child: CircularProgressIndicator(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _brokenImagePlaceholder(),
    );
  }

  Widget _brokenImagePlaceholder() {
    return Container(
      height: 120,
      color: Colors.grey.shade100,
      child: const Center(
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  // ── Row helpers ───────────────────────────────────────────────────────────

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          if (value.isNotEmpty)
            Text(
              value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500),
            ),
        ],
      ),
    );
  }
}

