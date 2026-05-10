import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/receipt/domain/entities/receipt_entity.dart';
import 'package:laundry_system/features/receipt/presentation/pages/receipt_details_page.dart';
import 'package:laundry_system/features/receipt/presentation/providers/receipt_provider.dart';

class ReceiptListPage extends ConsumerStatefulWidget {
  const ReceiptListPage({super.key});

  @override
  ConsumerState<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends ConsumerState<ReceiptListPage> {
  DateTime? _selectedDate;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReceipts();
    });
  }

  Future<void> _loadReceipts({bool forceRefresh = false}) async {
    // Skip if already loaded and not a forced refresh (pull-to-refresh)
    if (_hasLoaded && !forceRefresh) return;

    final user = ref.read(authProvider).user;
    if (user != null && user.uid.isNotEmpty) {
      await ref.read(receiptProvider.notifier).getUserReceipts(user.uid);
      _hasLoaded = true;
    } else {
      await Future.delayed(const Duration(milliseconds: 500));
      final retryUser = ref.read(authProvider).user;
      if (retryUser != null && retryUser.uid.isNotEmpty) {
        await ref
            .read(receiptProvider.notifier)
            .getUserReceipts(retryUser.uid);
        _hasLoaded = true;
      }
    }
  }

  List<ReceiptEntity> _getFilteredReceipts(List<ReceiptEntity> receipts) {
    if (_selectedDate == null) return receipts;
    return receipts.where((r) {
      if (r.bookingDate == null) return false;
      return r.bookingDate!.year == _selectedDate!.year &&
          r.bookingDate!.month == _selectedDate!.month &&
          r.bookingDate!.day == _selectedDate!.day;
    }).toList();
  }

  Color _getPaymentStatusColor(String status) {
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
    final receiptState = ref.watch(receiptProvider);
    final theme = Theme.of(context);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!_hasLoaded &&
          next.user != null &&
          next.user!.uid.isNotEmpty) {
        _loadReceipts();
      }
    });

    final filteredReceipts =
        _getFilteredReceipts(receiptState.receipts);

    return RefreshIndicator(
      onRefresh: () => _loadReceipts(forceRefresh: true),
      child: receiptState.isLoading && receiptState.receipts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : receiptState.error != null && receiptState.receipts.isEmpty
              ? _buildErrorView(receiptState.error!, theme)
              : filteredReceipts.isEmpty
                  ? _buildEmptyView(receiptState.receipts.isEmpty, theme)
                  : _buildReceiptList(filteredReceipts, theme),
    );
  }

  Widget _buildErrorView(String error, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              'Failed to load receipts',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadReceipts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(bool noReceipts, ThemeData theme) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Column(
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                noReceipts ? 'No receipts yet' : 'No receipts match filter',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                noReceipts
                    ? 'Receipts will appear here after your bookings are processed'
                    : 'Try adjusting your filter',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptList(
      List<ReceiptEntity> receipts, ThemeData theme) {
    return Column(
      children: [
        // Date filter
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                        const SizedBox(width: 10),
                        Text(
                          _selectedDate != null
                              ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                              : 'All Dates',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate != null
                                ? Colors.black87
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => setState(() => _selectedDate = null),
                  tooltip: 'Clear date filter',
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Receipt cards
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            itemCount: receipts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final receipt = receipts[index];
              return _buildReceiptCard(receipt, theme);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptCard(ReceiptEntity receipt, ThemeData theme) {
    final statusColor = _getPaymentStatusColor(receipt.status);
    final dateStr = receipt.bookingDate != null
        ? DateFormat('MMM d, yyyy').format(receipt.bookingDate!)
        : 'N/A';
    final createdStr = DateFormat('MMM d, yyyy – h:mm a').format(receipt.createdAt);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReceiptDetailsPage(receipt: receipt),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Receipt ID + Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Receipt #${receipt.receiptId.length > 8 ? receipt.receiptId.substring(0, 8) : receipt.receiptId}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      receipt.status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Machine + Time Slot
              if (receipt.machineName != null) ...[
                Row(
                  children: [
                    Icon(Icons.local_laundry_service,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      receipt.machineName!,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (receipt.timeSlot != null) ...[
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Text(
                      receipt.timeSlot!,
                      style: TextStyle(
                          color: Colors.grey.shade700, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],

              // Booking Date
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Booking: $dateStr',
                    style:
                        TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Footer: Total Amount + Created At
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    createdStr,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppUtils.formatCurrency(receipt.totalAmount),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
