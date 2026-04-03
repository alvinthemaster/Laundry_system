import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/pages/login_page.dart';
import 'package:laundry_system/features/auth/presentation/pages/profile_page.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/presentation/pages/multi_step_booking_page.dart';
import 'package:laundry_system/features/booking/presentation/pages/booking_details_page.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';
import 'package:laundry_system/features/receipt/presentation/pages/receipt_list_page.dart';
import 'package:intl/intl.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _hasLoadedBookings = false;
  String _selectedFilter = 'All'; // Filter state
  String _selectedPaymentFilter = 'All'; // Payment filter state
  int _currentTabIndex = 0;
  
  @override
  void initState() {
    super.initState();
    // Load user bookings with better error handling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserBookings();
    });
  }
  
  Future<void> _loadUserBookings() async {
    try {
      final user = ref.read(authProvider).user;
      if (user != null && user.uid.isNotEmpty) {
        print('Loading bookings for user: ${user.uid}');
        await ref.read(bookingProvider.notifier).getUserBookings(user.uid);
        _hasLoadedBookings = true;
      } else {
        print('User is null or has empty uid, waiting for auth state...');
        // Wait a bit for auth state to load, then try again
        await Future.delayed(const Duration(milliseconds: 500));
        final retryUser = ref.read(authProvider).user;
        if (retryUser != null && retryUser.uid.isNotEmpty) {
          print('Retry: Loading bookings for user: ${retryUser.uid}');
          await ref.read(bookingProvider.notifier).getUserBookings(retryUser.uid);
          _hasLoadedBookings = true;
        } else {
          print('User still not available after retry');
        }
      }
    } catch (e) {
      print('Error in _loadUserBookings: $e');
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
      case 'Completed':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentColor(String status) {
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
    final authState = ref.watch(authProvider);
    final bookingState = ref.watch(bookingProvider);
    final user = authState.user;
    
    // Listen for auth state changes and reload bookings when user becomes available
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (!_hasLoadedBookings && next.user != null && next.user!.uid.isNotEmpty) {
        print('Auth state changed - loading bookings for user: ${next.user!.uid}');
        _loadUserBookings();
      }
    });
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Franz Laundry Hub'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
            tooltip: 'Profile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildBookingsBody(user, bookingState),
          const ReceiptListPage(),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const MultiStepBookingPage()),
                );
                if (result == true && user != null && user.uid.isNotEmpty) {
                  await ref
                      .read(bookingProvider.notifier)
                      .getUserBookings(user.uid);
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('New Booking'),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Bookings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Receipts',
          ),
        ],
      ),
    );
  }

  // ── Bookings Tab Body ──
  Widget _buildBookingsBody(dynamic user, BookingState bookingState) {
    return RefreshIndicator(
      onRefresh: () async {
        if (user != null && user.uid.isNotEmpty) {
          await ref.read(bookingProvider.notifier).getUserBookings(user.uid);
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue, Colors.blue.shade700],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullName ?? 'User',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Bookings Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'My Bookings',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),

                  // Status Filter Dropdown
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilter,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              items: ['All', 'Pending', 'Confirmed', 'Washing', 'Ready', 'Completed']
                                  .map((status) => DropdownMenuItem(
                                        value: status,
                                        child: Row(
                                          children: [
                                            if (status != 'All')
                                              Container(
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(status),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            Text(status, style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedFilter = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Payment Status Filter Dropdown
                  Row(
                    children: [
                      Text(
                        'Payment: ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPaymentFilter,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down),
                              items: ['All', 'Paid', 'Half Paid', 'Unpaid']
                                  .map((status) => DropdownMenuItem(
                                        value: status,
                                        child: Row(
                                          children: [
                                            if (status != 'All')
                                              Container(
                                                width: 10,
                                                height: 10,
                                                margin: const EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  color: status == 'Paid'
                                                      ? Colors.green
                                                      : status == 'Half Paid'
                                                          ? Colors.orange
                                                          : Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                            Text(status, style: const TextStyle(fontSize: 14)),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedPaymentFilter = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Show error if exists
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
                              'Error loading bookings: ${bookingState.error}',
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _loadUserBookings(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),

                  if (bookingState.isLoading && bookingState.bookings.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_getFilteredBookings(bookingState.bookings).isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              bookingState.bookings.isEmpty
                                  ? 'No bookings yet'
                                  : 'No bookings found',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              bookingState.bookings.isEmpty
                                  ? 'Start by creating your first booking'
                                  : 'Try adjusting your filters',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _getFilteredBookings(bookingState.bookings).length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final filteredBookings =
                            _getFilteredBookings(bookingState.bookings);
                        final booking = filteredBookings[index];
                        return _buildBookingCard(booking);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(BookingEntity booking) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getStatusColor(booking.status).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BookingDetailsPage(booking: booking),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
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
                              Icons.local_laundry_service,
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
                                  booking.machineName ??
                                      (booking.categories.isNotEmpty
                                          ? booking.categories
                                              .map((c) =>
                                                  c['name'] as String? ?? '')
                                              .join(', ')
                                          : 'Laundry Booking'),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline,
                                        size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      booking.customerName ?? 'Customer',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (booking.categories.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      const Icon(
                                          Icons.local_laundry_service,
                                          size: 13,
                                          color: Colors.grey),
                                      const SizedBox(width: 2),
                                      Text(
                                        booking.categories
                                            .map((c) =>
                                                c['name'] as String? ?? '')
                                            .join(', '),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getPaymentColor(booking.paymentStatus).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _getPaymentColor(booking.paymentStatus),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            booking.paymentStatus,
                            style: TextStyle(
                              color: _getPaymentColor(booking.paymentStatus),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        booking.bookingType == 'delivery'
                            ? Icons.delivery_dining
                            : Icons.shopping_bag,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        booking.bookingType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (booking.pickupDate != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            DateFormat('MMM dd').format(booking.pickupDate!),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (booking.timeSlot != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.access_time,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            booking.timeSlot!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          booking.paymentMethod == 'GCash'
                              ? Icons.payment
                              : Icons.money,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          booking.paymentMethod ?? 'N/A',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
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
      ),
    );
  }

  // Filter bookings based on selected filters
  List<BookingEntity> _getFilteredBookings(List<BookingEntity> bookings) {
    var filtered = bookings;

    if (_selectedFilter != 'All') {
      filtered = filtered.where((b) => b.status == _selectedFilter).toList();
    }

    if (_selectedPaymentFilter != 'All') {
      filtered = filtered
          .where((b) => b.paymentStatus == _selectedPaymentFilter)
          .toList();
    }

    return filtered;
  }
}
