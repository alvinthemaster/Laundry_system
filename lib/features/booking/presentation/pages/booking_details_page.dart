import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';
import 'package:intl/intl.dart';

class BookingDetailsPage extends ConsumerWidget {
  final BookingEntity booking;
  
  const BookingDetailsPage({
    super.key,
    required this.booking,
  });
  
  Color _getStatusColor(String status) {
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
    // Block cancellation for GCash payments
    if (booking.paymentMethod == 'GCash') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Cancel'),
          content: const Text(
            'Bookings paid via GCash cannot be cancelled as the payment has already been processed.\n\nPlease contact support if you need assistance.',
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
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    
    if (confirm == true && context.mounted) {
      final success = await ref.read(bookingProvider.notifier).cancelBooking(booking.bookingId);
      
      if (context.mounted) {
        if (success) {
          AppUtils.showSnackBar(context, 'Booking cancelled successfully');
          Navigator.of(context).pop();
        } else {
          final error = ref.read(bookingProvider).error;
          AppUtils.showSnackBar(context, error ?? 'Failed to cancel booking', isError: true);
        }
      }
    }
  }
  
  Future<void> _reschedulePickup(BuildContext context, WidgetRef ref) async {
    // Only allow reschedule for pickup type bookings
    if (booking.bookingType != 'pickup' || booking.pickupDate == null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Reschedule'),
          content: const Text('Only pickup bookings can be rescheduled.'),
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
    
    // Check if within 24 hours
    final currentPickupDate = booking.pickupDate!;
    final now = DateTime.now();
    final difference = currentPickupDate.difference(now);
    
    if (difference.inHours < 24) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Reschedule'),
          content: Text(
            'Sorry, you cannot reschedule within 24 hours of your pickup time.\\n\\nYour current pickup: ${DateFormat('MMM dd, yyyy').format(currentPickupDate)} at ${booking.pickupTime}',
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
    
    // Show reschedule dialog
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    
    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reschedule Pickup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Pickup:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Text('${DateFormat('MMM dd, yyyy').format(currentPickupDate)} at ${booking.pickupTime}'),
              const SizedBox(height: 20),
              Text(
                'New Pickup Date:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: currentPickupDate.add(const Duration(days: 1)),
                    firstDate: DateTime.now().add(const Duration(hours: 24)),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(
                  selectedDate == null
                      ? 'Select Date'
                      : DateFormat('MMM dd, yyyy').format(selectedDate!),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'New Pickup Time:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedTime = picked;
                    });
                  }
                },
                icon: const Icon(Icons.access_time),
                label: Text(
                  selectedTime == null
                      ? 'Select Time'
                      : selectedTime!.format(context),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (selectedDate != null && selectedTime != null)
                  ? () {
                      Navigator.of(context).pop();
                      _confirmReschedule(
                        context,
                        ref,
                        selectedDate!,
                        selectedTime!,
                      );
                    }
                  : null,
              child: const Text('Reschedule'),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _confirmReschedule(
    BuildContext context,
    WidgetRef ref,
    DateTime newDate,
    TimeOfDay newTime,
  ) async {
    final success = await ref.read(bookingProvider.notifier).reschedulePickup(
          bookingId: booking.bookingId,
          newPickupDate: newDate,
          newPickupTime: newTime.format(context),
        );
    
    if (!context.mounted) return;
    
    if (success) {
      AppUtils.showSnackBar(context, 'Pickup rescheduled successfully!');
      Navigator.of(context).pop(); // Go back to refresh
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(
        context,
        error ?? 'Failed to reschedule pickup',
        isError: true,
      );
    }
  }
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getStatusColor(booking.status).withOpacity(0.1),
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
                    color: _getStatusColor(booking.status),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    booking.status,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(booking.status),
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
                  Text(
                    'Booking ID',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.bookingId,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Divider(height: 30),
                  
                  // Service Details
                  Text(
                    'Service Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Categories (Multi-category support)
                  if (booking.categories.isNotEmpty) ...[
                    _buildDetailRow(
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
                  
                  _buildDetailRow(
                    context,
                    Icons.local_laundry_service,
                    'Service Type',
                    booking.selectedServices.isNotEmpty 
                        ? booking.selectedServices.join(', ') 
                        : (booking.serviceType ?? 'N/A'),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    Icons.scale,
                    'Total Weight',
                    '${booking.weight} kg',
                  ),
                  const SizedBox(height: 12),
                  
                  // Booking Type
                  _buildDetailRow(
                    context,
                    Icons.shopping_bag,
                    'Booking Type',
                    booking.bookingType.toUpperCase(),
                  ),
                  const SizedBox(height: 12),
                  
                  // Delivery Address (if delivery type)
                  if (booking.deliveryAddress != null) ...[
                    _buildDetailRow(
                      context,
                      Icons.location_on,
                      'Delivery Address',
                      booking.deliveryAddress!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Pickup Date/Time (if pickup type)
                  if (booking.pickupDate != null) ...[
                    _buildDetailRow(
                      context,
                      Icons.calendar_today,
                      'Pickup Date',
                      DateFormat('MMMM dd, yyyy').format(booking.pickupDate!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (booking.pickupTime != null) ...[
                    _buildDetailRow(
                      context,
                      Icons.access_time,
                      'Pickup Time',
                      booking.pickupTime!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  if (booking.specialInstructions != null) ...[
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      context,
                      Icons.note,
                      'Special Instructions',
                      booking.specialInstructions!,
                    ),
                  ],
                  
                  const Divider(height: 30),
                  
                  // Payment Details
                  Text(
                    'Payment Details',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Booking Fee'),
                            Text(AppUtils.formatCurrency(booking.bookingFee)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service Charge (${booking.weight} kg)'),
                            Text(
                              AppUtils.formatCurrency(
                                booking.servicesTotal > 0 
                                    ? booking.servicesTotal 
                                    : (booking.weight * (booking.servicePrice ?? 0)),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              AppUtils.formatCurrency(booking.totalAmount),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Payment Status'),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: booking.paymentStatus == 'Paid'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
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
                  
                  // Booking Date
                  Text(
                    'Booked on ${DateFormat('MMMM dd, yyyy - hh:mm a').format(booking.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  
                  // Reschedule Button (only for pickup bookings)
                  if ((booking.status == 'Pending' || booking.status == 'Confirmed') &&
                      booking.bookingType == 'pickup' &&
                      booking.pickupDate != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _reschedulePickup(context, ref),
                        icon: const Icon(Icons.schedule),
                        label: const Text('Reschedule Pickup'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  
                  // Cancel Button
                  if (booking.status == 'Pending' || booking.status == 'Confirmed') ...[
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
  
  Widget _buildDetailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
