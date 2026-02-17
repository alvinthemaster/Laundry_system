import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/pages/login_page.dart';
import 'package:laundry_system/features/auth/presentation/pages/profile_page.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/domain/entities/booking_entity.dart';
import 'package:laundry_system/features/booking/presentation/pages/create_booking_page.dart';
import 'package:laundry_system/features/booking/presentation/pages/booking_details_page.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';
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
        return Colors.green;
      case 'Completed':
        return Colors.grey;
      case 'Cancelled':
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
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null && user.uid.isNotEmpty) {
            print('Manual refresh: Loading bookings for user: ${user.uid}');
            await ref.read(bookingProvider.notifier).getUserBookings(user.uid);
          } else {
            print('Manual refresh failed: No user available');
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
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
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
                    
                    // Filters
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('All'),
                          _buildFilterChip('Pending'),
                          _buildFilterChip('Confirmed'),
                          _buildFilterChip('Washing'),
                          _buildFilterChip('Ready'),
                          _buildFilterChip('Completed'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Payment Status Filters
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
                        ChoiceChip(
                          label: const Text('All', style: TextStyle(fontSize: 12)),
                          selected: _selectedPaymentFilter == 'All',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedPaymentFilter = 'All';
                              });
                            }
                          },
                          selectedColor: Colors.blue,
                          labelStyle: TextStyle(
                            color: _selectedPaymentFilter == 'All' ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Paid', style: TextStyle(fontSize: 12)),
                          selected: _selectedPaymentFilter == 'Paid',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedPaymentFilter = 'Paid';
                              });
                            }
                          },
                          selectedColor: Colors.green,
                          labelStyle: TextStyle(
                            color: _selectedPaymentFilter == 'Paid' ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Unpaid', style: TextStyle(fontSize: 12)),
                          selected: _selectedPaymentFilter == 'Unpaid',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedPaymentFilter = 'Unpaid';
                              });
                            }
                          },
                          selectedColor: Colors.orange,
                          labelStyle: TextStyle(
                            color: _selectedPaymentFilter == 'Unpaid' ? Colors.white : Colors.black,
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
                              Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                bookingState.bookings.isEmpty
                                    ? 'No bookings yet'
                                    : 'No bookings found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                bookingState.bookings.isEmpty
                                    ? 'Start by creating your first booking'
                                    : 'Try adjusting your filters',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                ),
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
                          final filteredBookings = _getFilteredBookings(bookingState.bookings);
                          final booking = filteredBookings[index];
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
                                    builder: (_) => BookingDetailsPage(
                                      booking: booking,
                                    ),
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
                                                    color: _getStatusColor(booking.status).withOpacity(0.1),
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
                                                        booking.selectedServices.isNotEmpty
                                                            ? booking.selectedServices.join(', ')
                                                            : (booking.serviceType ?? 'N/A'),
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        '${booking.weight} kg',
                                                        style: TextStyle(
                                                          color: Colors.grey.shade600,
                                                          fontSize: 13,
                                                        ),
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
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(booking.status),
                                                  borderRadius: BorderRadius.circular(20),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: _getStatusColor(booking.status).withOpacity(0.3),
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
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: booking.paymentStatus == 'Paid'
                                                      ? Colors.green.withOpacity(0.1)
                                                      : Colors.orange.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: booking.paymentStatus == 'Paid'
                                                        ? Colors.green
                                                        : Colors.orange,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  booking.paymentStatus,
                                                  style: TextStyle(
                                                    color: booking.paymentStatus == 'Paid'
                                                        ? Colors.green
                                                        : Colors.orange,
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
                                          border: Border.all(
                                            color: Colors.grey.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // Booking Type Icon
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
                                            
                                            // Pickup Date (if available)
                                            if (booking.pickupDate != null) ...[
                                              const SizedBox(width: 12),
                                              const Icon(
                                                Icons.calendar_today,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
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
                                            
                                            // Pickup Time (if available)
                                            if (booking.pickupTime != null) ...[
                                              const SizedBox(width: 8),
                                              const Icon(
                                                Icons.access_time,
                                                size: 14,
                                                color: Colors.grey,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  booking.pickupTime!,
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
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
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
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateBookingPage()),
          );
          
          // Refresh bookings if a new booking was created
          if (result == true && user != null && user.uid.isNotEmpty) {
            print('New booking created - refreshing bookings');
            await ref.read(bookingProvider.notifier).getUserBookings(user.uid);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Booking'),
      ),
    );
  }
  
  // Filter chip builder
  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (selected) {
          setState(() {
            _selectedFilter = label;
          });
        },
        selectedColor: _getStatusColor(label),
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
  
  // Filter bookings based on selected filters
  List<BookingEntity> _getFilteredBookings(List<BookingEntity> bookings) {
    var filtered = bookings;
    
    // Filter by status
    if (_selectedFilter != 'All') {
      filtered = filtered.where((b) => b.status == _selectedFilter).toList();
    }
    
    // Filter by payment status
    if (_selectedPaymentFilter != 'All') {
      filtered = filtered.where((b) => b.paymentStatus == _selectedPaymentFilter).toList();
    }
    
    return filtered;
  }
}
