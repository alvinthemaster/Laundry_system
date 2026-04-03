import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';

class ReceiptDetailsPage extends StatelessWidget {
  final ReceiptEntity receipt;

  const ReceiptDetailsPage({super.key, required this.receipt});

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Half Paid':
        return Colors.orange;
      case 'Unpaid':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getPaymentStatusColor(receipt.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Receipt Header ──
            _buildHeader(theme, statusColor),
            const SizedBox(height: 24),

            // ── Booking Information ──
            _buildSection(
              theme,
              title: 'Booking Information',
              icon: Icons.info_outline,
              children: [
                _buildInfoRow('Booking ID',
                    receipt.bookingId.length > 8
                        ? '${receipt.bookingId.substring(0, 8)}...'
                        : receipt.bookingId),
                if (receipt.machineName != null)
                  _buildInfoRow('Machine', receipt.machineName!),
                if (receipt.timeSlot != null)
                  _buildInfoRow('Time Slot', receipt.timeSlot!),
                if (receipt.bookingType != null)
                  _buildInfoRow('Booking Type',
                      receipt.bookingType!.toUpperCase()),
                if (receipt.bookingDate != null)
                  _buildInfoRow(
                    'Booking Date',
                    DateFormat('EEEE, MMMM d, yyyy')
                        .format(receipt.bookingDate!),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Categories ──
            if (receipt.categories.isNotEmpty) ...[
              _buildSection(
                theme,
                title: 'Categories',
                icon: Icons.category_outlined,
                children: receipt.categories.map((cat) {
                  final name = cat['name'] as String? ?? 'Unknown';
                  final weight =
                      (cat['weight'] as num?)?.toDouble() ?? 0.0;
                  final price =
                      (cat['computedPrice'] as num?)?.toDouble() ?? 0.0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$name${weight > 0 ? ' (${weight.toStringAsFixed(1)} kg)' : ''}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        if (price > 0)
                          Text(
                            AppUtils.formatCurrency(price),
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 14)),
                        Text(
                          AppUtils.formatCurrency(price),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
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
                if (receipt.slotFee > 0)
                  _buildPriceRow('Slot Fee', receipt.slotFee),
                if (receipt.bookingFee > 0)
                  _buildPriceRow('Booking Fee', receipt.bookingFee),
                if (receipt.addOnsTotal > 0)
                  _buildPriceRow('Add-ons Total', receipt.addOnsTotal),
                if (receipt.deliveryFee > 0)
                  _buildPriceRow('Delivery Fee', receipt.deliveryFee),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
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

            // ── Payment Info ──
            _buildSection(
              theme,
              title: 'Payment',
              icon: Icons.payment,
              children: [
                _buildInfoRow('Status', receipt.status),
                if (receipt.paymentMethod != null)
                  _buildInfoRow('Method', receipt.paymentMethod!),
                _buildInfoRow(
                  'Created At',
                  DateFormat('MMMM d, yyyy – h:mm a')
                      .format(receipt.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Header ──
  Widget _buildHeader(ThemeData theme, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  receipt.status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Receipt #${receipt.receiptId.length > 12 ? receipt.receiptId.substring(0, 12) : receipt.receiptId}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
            ),
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

  // ── Section Card ──
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
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(
            AppUtils.formatCurrency(amount),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
