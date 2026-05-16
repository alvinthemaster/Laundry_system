import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/services/pricing_service.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';
import 'package:laundry_system/features/booking/presentation/pages/payment_page.dart';
import 'package:intl/intl.dart';

class CreateBookingPage extends ConsumerStatefulWidget {
  const CreateBookingPage({super.key});
  
  @override
  ConsumerState<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends ConsumerState<CreateBookingPage> {
  int _currentStep = 0;
  static const int _totalSteps = 4;

  // Step 1: Booking Type
  String? _bookingType;

  // Step 2: Date / Delivery
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final _deliveryAddressController = TextEditingController();

  // Step 3: Service Type
  String? _serviceType;

  // Step 4: Category
  final Map<String, TextEditingController> _categoryWeightControllers = {};
  final Set<String> _selectedCategories = {};

  static const List<String> _allTimeSlots = [
    '08:00 - 09:00',
    '09:00 - 10:00',
    '10:00 - 11:00',
    '11:00 - 12:00',
    '12:00 - 13:00',
    '13:00 - 14:00',
    '14:00 - 15:00',
    '15:00 - 16:00',
    '16:00 - 17:00',
    '17:00 - 18:00',
    '18:00 - 19:00',
    '19:00 - 20:00',
  ];
  
  @override
  void dispose() {
    _categoryWeightControllers.forEach((_, c) => c.dispose());
    _deliveryAddressController.dispose();
    super.dispose();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_bookingType == null) {
          AppUtils.showSnackBar(context, 'Please select a booking type', isError: true);
          return false;
        }
        return true;
      case 1:
        if (_bookingType == AppConstants.bookingTypeDelivery) {
          if (_deliveryAddressController.text.trim().isEmpty) {
            AppUtils.showSnackBar(context, 'Please enter delivery address', isError: true);
            return false;
          }
        } else {
          if (_selectedDate == null) {
            AppUtils.showSnackBar(context, 'Please select a pickup date', isError: true);
            return false;
          }
          if (_selectedTimeSlot == null) {
            AppUtils.showSnackBar(context, 'Please select a time slot', isError: true);
            return false;
          }
        }
        return true;
      case 2:
        if (_serviceType == null) {
          AppUtils.showSnackBar(context, 'Please select a service type', isError: true);
          return false;
        }
        return true;
      case 3:
        if (_selectedCategories.isEmpty) {
          AppUtils.showSnackBar(context, 'Please select at least one category', isError: true);
          return false;
        }
        for (final category in _selectedCategories) {
          final weight =
              double.tryParse(_categoryWeightControllers[category]?.text ?? '') ?? 0.0;
          if (weight <= 0) {
            AppUtils.showSnackBar(context, 'Please enter weight for $category', isError: true);
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  List<Map<String, dynamic>> _buildCategoriesList() {
    return _selectedCategories.map((name) {
      final weight =
          double.tryParse(_categoryWeightControllers[name]?.text ?? '0') ?? 0.0;
      return {'name': name, 'weight': weight};
    }).toList();
  }

  double _calculateTotal() {
    return _bookingType == AppConstants.bookingTypeDelivery ? 70.0 : 20.0;
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedTimeSlot = null;
      });
    }
  }
  
  Future<void> _proceedToPayment() async {
    if (!_validateCurrentStep()) return;

    final user = ref.read(authProvider).user;
    if (user == null) {
      AppUtils.showSnackBar(context, 'User not found', isError: true);
      return;
    }

    final total = _calculateTotal();

    final paymentResult = await Navigator.push<PaymentResult>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          totalAmount: total,
          reservationDetails: [
            {'label': 'Customer', 'value': user.fullName},
            {'label': 'Phone', 'value': user.phoneNumber},
            {'label': 'Booking Type', 'value': _bookingType ?? '-'},
            {
              'label': 'Date',
              'value': _selectedDate != null
                  ? DateFormat('EEEE, MMM d, yyyy').format(_selectedDate!)
                  : '-',
            },
            {'label': 'Service', 'value': _serviceType ?? '-'},
            {
              'label': 'Categories',
              'value': _selectedCategories.isEmpty
                  ? '-'
                  : _selectedCategories.join(', '),
            },
            if (_bookingType == AppConstants.bookingTypeDelivery)
              {
                'label': 'Delivery Address',
                'value': _deliveryAddressController.text.trim().isEmpty
                    ? '-'
                    : _deliveryAddressController.text.trim(),
              },
          ],
          onPaymentComplete: () {},
        ),
      ),
    );

    if (paymentResult == null || !mounted) return;

    await _createBooking(paymentResult);
  }

  Future<void> _createBooking(PaymentResult paymentResult) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      AppUtils.showSnackBar(context, 'User not found', isError: true);
      return;
    }

    final total = _calculateTotal();

    final success = await ref.read(bookingProvider.notifier).createBooking(
      userId: user.uid,
      categories: _buildCategoriesList(),
      selectedAddOns: const [],
      bookingType: _bookingType!,
      serviceType: _serviceType,
      deliveryAddress: _bookingType == AppConstants.bookingTypeDelivery
          ? _deliveryAddressController.text.trim()
          : null,
      pickupDate: _bookingType == AppConstants.bookingTypePickup ? _selectedDate : null,
      timeSlot: _bookingType == AppConstants.bookingTypePickup ? _selectedTimeSlot : null,
      paymentMethod: paymentResult.paymentMethod,
      paymentProofUrl: paymentResult.paymentProofDataUri,
      totalAmount: total,
      customerName: user.fullName,
      customerPhone: user.phoneNumber,
    );

    if (!mounted) return;

    if (success) {
      AppUtils.showSnackBar(context, 'Booking created successfully!');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(context, error ?? 'Failed to create booking', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final isLastStep = _currentStep == _totalSteps - 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Booking'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: _buildStepContent(),
                ),
              ),
            ),
          ),
          _buildBottomNavigation(bookingState, isLastStep),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final stepLabels = ['Type', 'Date', 'Service', 'Category'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_totalSteps * 2 - 1, (index) {
          if (index.isOdd) {
            final stepIndex = index ~/ 2;
            final isCompleted = _currentStep > stepIndex;
            return Expanded(
              child: Container(
                height: 2,
                color: isCompleted
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade300,
              ),
            );
          }
          final stepIndex = index ~/ 2;
          final isActive = stepIndex == _currentStep;
          final isCompleted = stepIndex < _currentStep;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted || isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade200,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text(
                          '${stepIndex + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stepLabels[stepIndex],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  color: isActive
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildTypeStep();
      case 1:
        return _buildDateStep();
      case 2:
        return _buildServiceTypeStep();
      case 3:
        return _buildCategoryStep();
      default:
        return const SizedBox.shrink();
    }
  }

  // â”€â”€ Step 1: Type â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How would you like your laundry handled?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 20),
        _buildTypeCard(
          label: 'Pickup',
          description: 'Drop off your laundry at the shop',
          icon: Icons.store,
          value: AppConstants.bookingTypePickup,
        ),
        const SizedBox(height: 16),
        _buildTypeCard(
          label: 'Delivery',
          description: 'Your cleaned laundry will be delivered to you',
          icon: Icons.local_shipping,
          value: AppConstants.bookingTypeDelivery,
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required String label,
    required String description,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _bookingType == value;
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: () => setState(() => _bookingType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isSelected ? Colors.white : Colors.grey, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? color : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Step 2: Date â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDateStep() {
    if (_bookingType == AppConstants.bookingTypeDelivery) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter your delivery address',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _deliveryAddressController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Delivery Address',
              hintText: 'Enter your complete delivery address',
              prefixIcon: const Icon(Icons.location_on),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Delivery Area Notice: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              'Our delivery service is available within Glan area only. Please ensure your address is within this coverage area before proceeding.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When would you like to drop off?',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Pickup Date',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            child: Text(
              _selectedDate == null
                  ? 'Select date'
                  : DateFormat('MMM dd, yyyy').format(_selectedDate!),
              style: TextStyle(
                color: _selectedDate == null ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ),
        if (_selectedDate != null) ...[
          const SizedBox(height: 20),
          Text(
            'Available Time Slots',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allTimeSlots.map((slot) {
              final isSelected = _selectedTimeSlot == slot;
              return ChoiceChip(
                selected: isSelected,
                label: Text(
                  slot,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
                onSelected: (selected) {
                  setState(() => _selectedTimeSlot = selected ? slot : null);
                },
                selectedColor: Theme.of(context).colorScheme.primary,
                backgroundColor: Colors.grey.shade100,
                checkmarkColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // â”€â”€ Step 3: Category â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildServiceTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your service type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 20),
        ...AppConstants.serviceTypeOptions.map((type) {
          final isSelected = _serviceType == type;
          final color = Theme.of(context).colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: () => setState(() => _serviceType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? color.withOpacity(0.08)
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        type,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected) Icon(Icons.check_circle, color: color),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCategoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select categories and enter weights',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: AppConstants.serviceCategories.keys.map((name) {
            final isSelected = _selectedCategories.contains(name);
            final data = AppConstants.serviceCategories[name]!;
            final minPrice = AppUtils.formatCurrency(data['minPrice'] ?? 0.0);
            final minWeight = data['minWeight'] ?? 0.0;
            return FilterChip(
              selected: isSelected,
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Min: $minPrice - ${minWeight}kg',
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? Colors.white70 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(name);
                    _categoryWeightControllers[name] = TextEditingController();
                  } else {
                    _selectedCategories.remove(name);
                    _categoryWeightControllers[name]?.dispose();
                    _categoryWeightControllers.remove(name);
                  }
                });
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              checkmarkColor: Colors.white,
              labelStyle: const TextStyle(fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            );
          }).toList(),
        ),
        if (_selectedCategories.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Enter Weights',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ..._selectedCategories.map((name) {
            final controller = _categoryWeightControllers[name]!;
            final minWeight = AppConstants.serviceCategories[name]!['minWeight']!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: controller,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '$name Weight (kg)',
                  hintText: 'Enter weight',
                  helperText: 'Minimum $minWeight kg',
                  prefixIcon: const Icon(Icons.scale),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                onChanged: (_) => setState(() {}),
              ),
            );
          }),
          const SizedBox(height: 20),
          _buildPriceSummary(),
        ],
      ],
    );
  }

  Widget _buildPriceSummary() {
    final categories = _buildCategoriesList();
    final categoryTotal =
        PricingService.calculateMultipleCategoriesTotal(categories);
    final grandTotal = categoryTotal + AppConstants.bookingFee;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Price Summary',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._selectedCategories.map((name) {
              final weight =
                  double.tryParse(_categoryWeightControllers[name]?.text ?? '0') ??
                      0.0;
              final price = weight > 0
                  ? PricingService.calculateCategoryPrice(
                      category: name, weight: weight)
                  : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$name (${weight}kg)',
                        style: const TextStyle(fontSize: 13)),
                    Text(AppUtils.formatCurrency(price),
                        style: const TextStyle(fontSize: 13)),
                  ],
                ),
              );
            }),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Booking Fee', style: TextStyle(fontSize: 13)),
                Text(AppUtils.formatCurrency(AppConstants.bookingFee),
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
            const Divider(height: 16, thickness: 1.5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  AppUtils.formatCurrency(grandTotal),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Bottom Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBottomNavigation(BookingState bookingState, bool isLastStep) {
    final total = _calculateTotal();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              OutlinedButton(
                onPressed: _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: bookingState.isLoading
                    ? null
                    : isLastStep
                        ? _proceedToPayment
                        : _nextStep,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: bookingState.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        isLastStep
                            ? 'Proceed to Payment \u2022 ${AppUtils.formatCurrency(total)}'
                            : 'Next',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
