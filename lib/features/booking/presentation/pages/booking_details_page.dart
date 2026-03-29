import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

                  _row(
                    context,
                    Icons.local_laundry_service,
                    'Service Type',
                    booking.selectedServices.isNotEmpty
                        ? booking.selectedServices.join(', ')
                        : (booking.serviceType ?? 'N/A'),
                  ),
                  const SizedBox(height: 12),

                  _row(context, Icons.scale, 'Total Weight',
                      '${booking.weight} kg'),
                  const SizedBox(height: 12),

                  _row(context, Icons.shopping_bag, 'Booking Type',
                      booking.bookingType.toUpperCase()),
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

                  if (booking.pickupTime != null) ...[
                    _row(context, Icons.access_time, 'Pickup Time',
                        booking.pickupTime!),
                    const SizedBox(height: 12),
                  ],

                  if (booking.selectedSlot != null) ...[
                    _row(context, Icons.wash, 'Machine Slot',
                        booking.selectedSlot!),
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
                        // Slot-based breakdown
                        if (booking.selectedSlot != null) ...[
                          _payRow(
                            'Slot Rate',
                            AppUtils.formatCurrency(
                              (booking.totalAmount -
                                      booking.addOnsTotal -
                                      booking.bookingFee)
                                  .clamp(0.0, double.infinity),
                            ),
                          ),
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
                        ] else ...[
                          // Legacy weight-based breakdown
                          _payRow('Booking Fee',
                              AppUtils.formatCurrency(booking.bookingFee)),
                          const SizedBox(height: 8),
                          _payRow(
                            'Service Charge (${booking.weight} kg)',
                            AppUtils.formatCurrency(
                              booking.servicesTotal > 0
                                  ? booking.servicesTotal
                                  : (booking.weight *
                                      (booking.servicePrice ?? 0)),
                            ),
                          ),
                        ],
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
                              AppUtils.formatCurrency(
                                  booking.totalAmount),
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
                                color: booking.paymentStatus == 'Paid'
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.orange
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                booking.paymentStatus,
                                style: TextStyle(
                                  color: booking.paymentStatus == 'Paid'
                                      ? Colors.green
                                      : Colors.orange,
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) =>
                              _RescheduleDialog(booking: booking),
                        ),
                        icon: const Icon(Icons.schedule),
                        label: const Text('Reschedule Pickup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
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
  static const int _totalSlots = 10;
  final List<String> _allSlots =
      List.generate(10, (i) => 'Slot ${i + 1}');

  DateTime? _newDate;
  TimeOfDay? _newTime;
  List<String> _availableSlots = [];
  String? _selectedSlot;
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  bool get _isWithin24h {
    final d = widget.booking.pickupDate;
    if (d == null) return false;
    return d.difference(DateTime.now()).inHours < 24;
  }

  String get _currentSchedule {
    final d = widget.booking.pickupDate;
    if (d == null) return 'Unknown';
    return '${DateFormat('MMM dd, yyyy').format(d)}'
        ' at ${widget.booking.pickupTime ?? '—'}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() {
        _newDate = picked;
        _selectedSlot = null;
        _availableSlots = [];
      });
      await _loadSlots();
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _newTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null && mounted) {
      setState(() {
        _newTime = picked;
        _selectedSlot = null;
        _availableSlots = [];
      });
      await _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    if (_newDate == null || _newTime == null) return;
    setState(() => _isLoadingSlots = true);
    try {
      final slots =
          await ref.read(bookingProvider.notifier).getAvailableSlots(
        date: _newDate!,
        time: _newTime!.format(context),
        allSlots: _allSlots,
      );
      if (!mounted) return;
      setState(() {
        _availableSlots = slots;
        if (_selectedSlot != null && !slots.contains(_selectedSlot)) {
          _selectedSlot = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _availableSlots = []);
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<void> _confirm() async {
    if (_newDate == null || _newTime == null || _selectedSlot == null) return;
    setState(() => _isSubmitting = true);

    // Re-validate slot availability right before submitting
    final fresh =
        await ref.read(bookingProvider.notifier).getAvailableSlots(
      date: _newDate!,
      time: _newTime!.format(context),
      allSlots: _allSlots,
    );
    if (!mounted) return;

    if (!fresh.contains(_selectedSlot)) {
      setState(() {
        _isSubmitting = false;
        _availableSlots = fresh;
        _selectedSlot = null;
      });
      AppUtils.showSnackBar(
          context, 'That slot was just taken. Please choose another.',
          isError: true);
      return;
    }

    final success = await ref
        .read(bookingProvider.notifier)
        .reschedulePickup(
      bookingId: widget.booking.bookingId,
      newPickupDate: _newDate!,
      newPickupTime: _newTime!.format(context),
      newSlot: _selectedSlot,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      AppUtils.showSnackBar(context, 'Pickup rescheduled successfully!');
      // Close the dialog and the details page so the list refreshes
      Navigator.of(context).pop(); // close dialog
      Navigator.of(context).pop(); // back to booking list
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(
          context, error ?? 'Failed to reschedule pickup',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Within-24h guard — show info dialog instead
    if (_isWithin24h) {
      return AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cannot Reschedule'),
        content: Text(
          'You cannot reschedule within 24 hours of your pickup time.\n\n'
          'Current pickup: $_currentSchedule',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    }

    final occupied =
        _allSlots.where((s) => !_availableSlots.contains(s)).toSet();
    final canConfirm =
        _newDate != null && _newTime != null && _selectedSlot != null;

    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Reschedule Pickup',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Current: $_currentSchedule',
              style:
                  TextStyle(color: Colors.grey.shade600, fontSize: 13),
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

            // Slot grid — shown once both date and time are set
            if (_newDate != null && _newTime != null) ...[
              const SizedBox(height: 20),
              const Text('Machine Slot',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_isLoadingSlots)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_availableSlots.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No slots available for this schedule. '
                    'Try a different date or time.',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                )
              else ...[
                Row(
                  children: [
                    _dot(Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    const Text('Available',
                        style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 12),
                    _dot(Colors.grey.shade300),
                    const SizedBox(width: 4),
                    const Text('Occupied',
                        style: TextStyle(fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: _totalSlots,
                  itemBuilder: (ctx, i) {
                    final slot = _allSlots[i];
                    final isOccupied = occupied.contains(slot);
                    final isSelected = _selectedSlot == slot;
                    final primary = Theme.of(ctx).colorScheme.primary;
                    return GestureDetector(
                      onTap: (isOccupied || _isSubmitting)
                          ? null
                          : () =>
                              setState(() => _selectedSlot = slot),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isOccupied
                              ? Colors.grey.shade200
                              : isSelected
                                  ? primary
                                  : primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: primary, width: 2)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isOccupied
                                    ? Colors.grey.shade400
                                    : isSelected
                                        ? Colors.white
                                        : Theme.of(ctx)
                                            .colorScheme
                                            .onSurface,
                              ),
                            ),
                            if (isOccupied)
                              Icon(Icons.lock_outline,
                                  size: 9,
                                  color: Colors.grey.shade400),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  size: 9, color: Colors.white),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],

            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed:
                      (canConfirm && !_isSubmitting) ? _confirm : null,
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

  Widget _dot(Color c) => Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}