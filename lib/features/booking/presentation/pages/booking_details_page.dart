import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/core/services/pricing_service.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';
import 'package:intl/intl.dart';

// ===========================================================================
// BookingDetailsPage
// ===========================================================================

class BookingDetailsPage extends ConsumerWidget {
  final BookingEntity booking;

  const BookingDetailsPage({super.key, required this.booking});

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Washing':
        return Colors.purple;
      case 'Ready':
        return Colors.green;
      case 'Completed':
        return Colors.grey;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _normalizePaymentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'half paid':
        return 'Half Paid';
      case 'unpaid':
        return 'Unpaid';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  Future<void> _cancelBooking(BuildContext context, WidgetRef ref) async {
    if (booking.paymentMethod == 'GCash') {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Cannot Cancel'),
          content: const Text(
            'Bookings paid via GCash cannot be cancelled.\n\n'
            'Please contact support if you need assistance.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content:
            const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final success = await ref
        .read(bookingProvider.notifier)
        .cancelBooking(booking.bookingId);

    if (!context.mounted) return;
    if (success) {
      AppUtils.showSnackBar(context, 'Booking cancelled successfully');
      Navigator.of(context).pop();
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(
          context, error ?? 'Failed to cancel booking',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Booking Details')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _statusColor(booking.status).withValues(alpha: 0.1),
              ),
              child: Column(
                children: [
                  Icon(
                    booking.status == 'Completed'
                        ? Icons.check_circle
                        : booking.status == 'Cancelled'
                            ? Icons.cancel
                            : Icons.info,
                    size: 60,
                    color: _statusColor(booking.status),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    booking.status,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(booking.status),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Booking ID
                  Text('Booking ID',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey)),
                  const SizedBox(height: 4),
                  Text(booking.bookingId,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontFamily: 'monospace')),
                  const Divider(height: 30),

                  // Service details
                  Text('Service Details',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  if (booking.categories.isNotEmpty) ...[
                    _row(
                      context,
                      Icons.category,
                      'Categories',
                      booking.categories.map((cat) {
                        final name = cat['name'] ?? 'Unknown';
                        final weight = cat['weight'] ?? 0.0;
                        return '$name (${weight}kg)';
                      }).join(', '),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (booking.serviceType != null) ...[  
                    _row(
                      context,
                      Icons.local_laundry_service,
                      'Service Type',
                      booking.serviceType!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),

                  if (booking.deliveryAddress != null) ...[
                    _row(context, Icons.location_on, 'Delivery Address',
                        booking.deliveryAddress!),
                    const SizedBox(height: 12),
                  ],

                  if (booking.pickupDate != null) ...[
                    _row(
                      context,
                      Icons.calendar_today,
                      'Pickup Date',
                      DateFormat('MMMM dd, yyyy').format(booking.pickupDate!),
                    ),
                    const SizedBox(height: 12),
                  ],

if (booking.timeSlot != null) ...[                    
                    _row(context, Icons.access_time, 'Time Slot',
                        booking.timeSlot!),
                    const SizedBox(height: 12),
                  ],

                  if (booking.slotId != null) ...[                    
                    _row(context, Icons.tag, 'Slot ID',
                        booking.slotId!),
                    const SizedBox(height: 12),
                  ],

                  if (booking.specialInstructions != null) ...[
                    _row(context, Icons.note, 'Special Instructions',
                        booking.specialInstructions!),
                    const SizedBox(height: 12),
                  ],

                  const Divider(height: 30),

                  // Payment details
                  Text('Payment Details',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Categories breakdown
                        if (booking.categories.isNotEmpty) ...[                          
                          ...booking.categories.map((cat) {
                            final name = (cat['name'] as String?) ?? 'Unknown';
                            final weight = (cat['weight'] as num?)?.toDouble() ?? 0.0;
                            final price = (cat['computedPrice'] as num?)?.toDouble() ??
                                PricingService.calculateCategoryPrice(
                                    category: name, weight: weight);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: _payRow(
                                '$name (${weight}kg)',
                                AppUtils.formatCurrency(price),
                              ),
                            );
                          }),
                          const SizedBox(height: 4),
                        ],
                        // Slot fee row
                        if (booking.slotFee > 0) ...[
                          _payRow(
                            'Slot Rate',
                            AppUtils.formatCurrency(booking.slotFee),
                          ),
                        ],
                        if (booking.deliveryFee > 0) ...[
                          const SizedBox(height: 4),
                          _payRow(
                            'Delivery Fee',
                            AppUtils.formatCurrency(booking.deliveryFee),
                          ),
                        ],
                        if (booking.addOnsTotal > 0) ...[
                          const SizedBox(height: 4),
                          ...booking.selectedAddOns.map(
                            (addon) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _payRow(
                                '  ${addon['name'] ?? ''}',
                                '+${AppUtils.formatCurrency((addon['price'] as num?)?.toDouble() ?? 0.0)}',
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _payRow('Booking Fee',
                            AppUtils.formatCurrency(booking.bookingFee)),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Amount',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold)),
                            Text(
                              AppUtils.formatCurrency(booking.totalAmount),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment Status'),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: booking.paymentStatus.toLowerCase() == 'paid'
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : booking.paymentStatus.toLowerCase() == 'half paid'
                                        ? Colors.orange.withValues(alpha: 0.12)
                                        : Colors.red.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _normalizePaymentStatus(booking.paymentStatus),
                                style: TextStyle(
                                  color: booking.paymentStatus.toLowerCase() == 'paid'
                                      ? Colors.green
                                      : booking.paymentStatus.toLowerCase() == 'half paid'
                                          ? Colors.orange
                                          : Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 30),
                  Text(
                    'Booked on ${DateFormat('MMMM dd, yyyy - hh:mm a').format(booking.createdAt)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey),
                  ),

                  // Reschedule button (pickup only, pending/confirmed only)
                  if ((booking.status == 'Pending' ||
                          booking.status == 'Confirmed') &&
                      booking.bookingType == 'pickup' &&
                      booking.pickupDate != null) ...[
                    const SizedBox(height: 20),
                    Builder(builder: (ctx) {
                      final windowExpired = DateTime.now().isAfter(
                          booking.createdAt.add(const Duration(hours: 24)));
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ElevatedButton.icon(
                            onPressed: windowExpired
                                ? null
                                : () => showDialog<void>(
                                      context: ctx,
                                      barrierDismissible: false,
                                      builder: (_) =>
                                          _RescheduleDialog(booking: booking),
                                    ),
                            icon: const Icon(Icons.schedule),
                            label: const Text('Reschedule Pickup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  windowExpired ? Colors.grey.shade400 : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          if (windowExpired) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Rescheduling is only allowed within 24 hours of booking.',
                              style: TextStyle(
                                  color: Colors.red.shade600, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      );
                    }),
                  ],

                  // Cancel button
                  if (booking.status == 'Pending' ||
                      booking.status == 'Confirmed') ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: booking.paymentMethod == 'GCash'
                            ? null
                            : () => _cancelBooking(context, ref),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: BorderSide(
                            color: booking.paymentMethod == 'GCash'
                                ? Colors.grey
                                : Colors.red,
                          ),
                        ),
                        child: Text(
                          booking.paymentMethod == 'GCash'
                              ? 'Cannot Cancel (GCash Payment)'
                              : 'Cancel Booking',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
      BuildContext context, IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _payRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      );
}

// ===========================================================================
// _RescheduleDialog  (ConsumerStatefulWidget — clean context management)
// ===========================================================================

class _RescheduleDialog extends ConsumerStatefulWidget {
  final BookingEntity booking;

  const _RescheduleDialog({required this.booking});

  @override
  ConsumerState<_RescheduleDialog> createState() =>
      _RescheduleDialogState();
}

class _RescheduleDialogState extends ConsumerState<_RescheduleDialog> {
  DateTime? _newDate;
  TimeOfDay? _newTime;
  bool _isSubmitting = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every second so the countdown updates live
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// True when the 24-hour reschedule window (from booking creation) has closed.
  bool get _windowExpired => DateTime.now().isAfter(
      widget.booking.createdAt.add(const Duration(hours: 24)));

  /// Remaining time in the reschedule window.
  Duration get _remaining => widget.booking.createdAt
      .add(const Duration(hours: 24))
      .difference(DateTime.now());

  String get _countdownText {
    if (_windowExpired) return 'Expired';
    final d = _remaining;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s remaining';
  }

  String get _currentSchedule {
    final d = widget.booking.pickupDate;
    if (d == null) return 'Unknown';
    return '${DateFormat('MMM dd, yyyy').format(d)}'
        ' at ${widget.booking.timeSlot ?? '—'}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate ?? today,
      firstDate: today,
      lastDate: tomorrow,
    );
    if (picked != null && mounted) {
      setState(() => _newDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _newTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() => _newTime = picked);
    }
  }

  Future<void> _confirm() async {
    if (_newDate == null || _newTime == null) return;

    // Final guard: window may have expired while the dialog was open
    if (_windowExpired) {
      AppUtils.showSnackBar(
        context,
        'Rescheduling is only allowed within 24 hours of booking.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await ref.read(bookingProvider.notifier).reschedulePickup(
      bookingId: widget.booking.bookingId,
      newPickupDate: _newDate!,
      newPickupTime: _newTime!.format(context),
      oldSlotId: widget.booking.slotId,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      AppUtils.showSnackBar(context, 'Pickup rescheduled successfully!');
      Navigator.of(context).pop(); // close dialog
      Navigator.of(context).pop(); // back to booking list
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(context, error ?? 'Failed to reschedule pickup',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Window-expired guard — show info dialog instead
    if (_windowExpired) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cannot Reschedule'),
        content: const Text(
          'Rescheduling is only allowed within 24 hours of booking.\n\n'
          'The reschedule window for this booking has expired.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    final canConfirm = _newDate != null && _newTime != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + live countdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Reschedule Pickup',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          size: 14, color: Colors.orange.shade700),
                      const SizedBox(width: 4),
                      Text(
                        _countdownText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Current: $_currentSchedule',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const Divider(height: 24),

            // Date picker
            const Text('New Pickup Date',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(_newDate == null
                    ? 'Select date'
                    : DateFormat('MMM dd, yyyy').format(_newDate!)),
              ),
            ),
            const SizedBox(height: 16),

            // Time picker
            const Text('New Pickup Time',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pickTime,
                icon: const Icon(Icons.access_time, size: 18),
                label: Text(_newTime == null
                    ? 'Select time'
                    : _newTime!.format(context)),
              ),
            ),

            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: (canConfirm && !_isSubmitting) ? _confirm : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Reschedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}