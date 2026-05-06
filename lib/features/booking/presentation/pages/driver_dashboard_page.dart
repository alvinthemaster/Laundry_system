import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/pages/login_page.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';

class DriverDashboardPage extends ConsumerStatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  ConsumerState<DriverDashboardPage> createState() =>
      _DriverDashboardPageState();
}

class _DriverDashboardPageState extends ConsumerState<DriverDashboardPage> {
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDriverBookings();
    });
  }

  Future<void> _loadDriverBookings() async {
    final user = ref.read(authProvider).user;
    if (user == null || user.uid.isEmpty) return;
    await ref.read(bookingProvider.notifier).getDriverBookings(user.uid);
  }

  Future<void> _updateStatus(BookingEntity booking, String newStatus) async {
    final success = await ref.read(bookingProvider.notifier).updateDeliveryStatus(
          bookingId: booking.bookingId,
          status: newStatus,
        );
    if (!mounted) return;
    if (success) {
      AppUtils.showSnackBar(context, 'Status updated to "$newStatus"');
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(context, error ?? 'Failed to update status',
          isError: true);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
        return Colors.orange;
      case 'Confirmed':
        return Colors.blue;
      case 'Washing':
        return Colors.purple;
      case 'Ready':
        return Colors.teal;
      case 'Pickup':
        return Colors.indigo;
      case 'Out for Delivery':
        return Colors.deepOrange;
      case 'Delivered':
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  List<BookingEntity> _getFilteredBookings(List<BookingEntity> bookings) {
    if (_selectedFilter == 'All') return bookings;
    return bookings.where((b) => b.status == _selectedFilter).toList();
  }

  Future<void> _notifyArrived(BookingEntity booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Notify Customer'),
        content: Text(
          'Notify ${booking.customerName ?? 'the customer'} that you have arrived at their location?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Notify'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await ref.read(bookingProvider.notifier).notifyCustomerArrived(
          bookingId: booking.bookingId,
          customerId: booking.userId,
        );

    if (!mounted) return;
    if (success) {
      AppUtils.showSnackBar(context, 'Customer has been notified!');
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(
        context,
        error ?? 'Failed to notify customer',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final bookingState = ref.watch(bookingProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDriverBookings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver Info Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepOrange, Colors.deepOrange.shade700],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome, Driver!',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.fullName ?? 'Driver',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.phoneNumber ?? '',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Assigned Deliveries',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 16),

                    // Status Filter
                    Row(
                      children: [
                        Text(
                          'Status: ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border:
                                  Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedFilter,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                items: [
                                  'All',
                                  'Pending',
                                  'Confirmed',
                                  'Washing',
                                  'Ready',
                                  'Pickup',
                                  'Out for Delivery',
                                  'Delivered',
                                  'Completed',
                                ]
                                    .map((status) => DropdownMenuItem(
                                          value: status,
                                          child: Row(
                                            children: [
                                              if (status != 'All')
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  margin: const EdgeInsets
                                                      .only(right: 8),
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(
                                                        status),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              Text(status,
                                                  style: const TextStyle(
                                                      fontSize: 14)),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(
                                        () => _selectedFilter = value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Error
                    if (bookingState.error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Error: ${bookingState.error}',
                                style:
                                    TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                            TextButton(
                              onPressed: _loadDriverBookings,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),

                    if (bookingState.isLoading &&
                        bookingState.bookings.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_getFilteredBookings(bookingState.bookings)
                        .isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            children: [
                              Icon(Icons.delivery_dining,
                                  size: 80,
                                  color: Colors.grey.shade400),
                              const SizedBox(height: 16),
                              Text(
                                bookingState.bookings.isEmpty
                                    ? 'No deliveries assigned yet'
                                    : 'No deliveries match the filter',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _getFilteredBookings(
                                bookingState.bookings)
                            .length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final filtered =
                              _getFilteredBookings(bookingState.bookings);
                          return _buildDeliveryCard(filtered[index]);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCard(BookingEntity booking) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(booking.status).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              _getStatusColor(booking.status).withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _getStatusColor(booking.status)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.delivery_dining,
                            color: _getStatusColor(booking.status),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.customerName ?? 'Customer',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: ${booking.bookingId.substring(0, 8)}...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(booking.status),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getStatusColor(booking.status)
                                  .withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          booking.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Delivery address
              if (booking.deliveryAddress != null)
                _infoRow(
                  Icons.location_on,
                  'Address',
                  booking.deliveryAddress!,
                  Colors.red,
                ),

              // Pickup date
              if (booking.pickupDate != null) ...[
                const SizedBox(height: 6),
                _infoRow(
                  Icons.calendar_today,
                  'Date',
                  DateFormat('MMM dd, yyyy').format(booking.pickupDate!),
                  Colors.blue,
                ),
              ],

              // Time slot
              if (booking.timeSlot != null) ...[
                const SizedBox(height: 6),
                _infoRow(
                  Icons.access_time,
                  'Time',
                  booking.timeSlot!,
                  Colors.indigo,
                ),
              ],

              // Categories
              if (booking.categories.isNotEmpty) ...[
                const SizedBox(height: 6),
                _infoRow(
                  Icons.local_laundry_service,
                  'Items',
                  booking.categories
                      .map((c) =>
                          '${c['name']} (${c['weight']}kg)')
                      .join(', '),
                  Colors.purple,
                ),
              ],

              const SizedBox(height: 12),

              // Total amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppUtils.formatCurrency(booking.totalAmount),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),

              // Status update buttons
              if (booking.status != 'Delivered' &&
                  booking.status != 'Completed' &&
                  booking.status != 'Cancelled') ...[                
                const SizedBox(height: 12),
                _buildStatusButtons(booking),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusButtons(BookingEntity booking) {
    // Determine which statuses are available as next steps
    const statuses = [
      ('Pickup', Icons.local_laundry_service, Colors.indigo),
      ('Out for Delivery', Icons.delivery_dining, Colors.deepOrange),
      ('Delivered', Icons.check_circle, Colors.green),
    ];

    return Column(
      children: [
        Row(
          children: statuses.map((s) {
            final label = s.$1;
            final icon = s.$2;
            final color = s.$3;
            final isActive = booking.status == label;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: isActive
                    ? ElevatedButton.icon(
                        onPressed: null,
                        icon: Icon(icon, size: 15),
                        label: Text(label,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: color.withOpacity(0.7),
                          disabledForegroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => _updateStatus(booking, label),
                        icon: Icon(icon, size: 15),
                        label: Text(label,
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                          side: BorderSide(color: color),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 10),
                        ),
                      ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _notifyArrived(booking),
            icon: const Icon(Icons.notifications_active, size: 18),
            label: const Text('Notify Customer — I Have Arrived'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
