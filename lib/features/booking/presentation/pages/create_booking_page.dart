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
  final _formKey = GlobalKey<FormState>();
  
  // Multi-category support
  final Map<String, TextEditingController> _categoryWeightControllers = {};
  final Set<String> _selectedCategories = {};
  
  // Service & Add-ons
  final Set<String> _selectedServices = {};
  final Map<String, double> _selectedAddOns = {};
  
  // Delivery/Pickup logic
  bool _isDeliverySelected = false;
  final _deliveryAddressController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  // Other fields
  final _instructionsController = TextEditingController();
  
  @override
  void dispose() {
    _categoryWeightControllers.forEach((_, controller) => controller.dispose());
    _deliveryAddressController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  /// Build categories list with weights and computed prices
  List<Map<String, dynamic>> _buildCategoriesList() {
    return _selectedCategories.map((categoryName) {
      final controller = _categoryWeightControllers[categoryName];
      final weight = double.tryParse(controller?.text ?? '0') ?? 0.0;
      return {
        'name': categoryName,
        'weight': weight,
      };
    }).toList();
  }
  
  /// Calculate pricing breakdown
  Map<String, double> _calculatePricing() {
    final categories = _buildCategoriesList();
    
    if (categories.isEmpty) {
      return {
        'categoryTotal': 0.0,
        'servicesTotal': 0.0,
        'addOnsTotal': 0.0,
        'bookingFee': AppConstants.bookingFee,
        'grandTotal': AppConstants.bookingFee,
      };
    }
    
    final categoryTotal = PricingService.calculateMultipleCategoriesTotal(categories);
    final servicesTotal = PricingService.calculateServicesTotal(_selectedServices.toList());
    final addOnsTotal = PricingService.calculateAddOnsTotal(
      _selectedAddOns.entries.map((e) => {'name': e.key, 'price': e.value}).toList(),
    );
    final grandTotal = categoryTotal + servicesTotal + addOnsTotal + AppConstants.bookingFee;
    
    return {
      'categoryTotal': categoryTotal,
      'servicesTotal': servicesTotal,
      'addOnsTotal': addOnsTotal,
      'bookingFee': AppConstants.bookingFee,
      'grandTotal': grandTotal,
    };
  }
  
  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation
    if (_selectedCategories.isEmpty) {
      AppUtils.showSnackBar(context, 'Please select at least one category', isError: true);
      return;
    }
    
    // Check each category has weight
    for (final category in _selectedCategories) {
      final controller = _categoryWeightControllers[category];
      final weight = double.tryParse(controller?.text ?? '0') ?? 0.0;
      if (weight <= 0) {
        AppUtils.showSnackBar(context, 'Please enter weight for $category', isError: true);
        return;
      }
    }
    
    if (_selectedServices.isEmpty) {
      AppUtils.showSnackBar(context, 'Please select at least one service', isError: true);
      return;
    }
    
    // Delivery/Pickup validation
    if (_isDeliverySelected) {
      if (_deliveryAddressController.text.trim().isEmpty) {
        AppUtils.showSnackBar(context, 'Please enter delivery address', isError: true);
        return;
      }
    } else {
      if (_selectedDate == null) {
        AppUtils.showSnackBar(context, 'Please select pickup date', isError: true);
        return;
      }
      if (_selectedTime == null) {
        AppUtils.showSnackBar(context, 'Please select pickup time', isError: true);
        return;
      }
    }
    
    final pricing = _calculatePricing();
    
    // Navigate to payment page
    final paymentMethod = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          totalAmount: pricing['grandTotal']!,
          onPaymentComplete: () {},
        ),
      ),
    );
    
    if (paymentMethod == null || !mounted) return;
    
    // Create booking with payment info
    await _createBooking(paymentMethod);
  }
  
  Future<void> _createBooking(String paymentMethod) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      AppUtils.showSnackBar(context, 'User not found', isError: true);
      return;
    }
    
    final categories = _buildCategoriesList();
    final bookingType = _isDeliverySelected 
        ? AppConstants.bookingTypeDelivery 
        : AppConstants.bookingTypePickup;
    
    // Prepare add-ons list
    final addOnsList = _selectedAddOns.entries.map((e) {
      return {
        'name': e.key,
        'price': e.value,
      };
    }).toList();
    
    final success = await ref.read(bookingProvider.notifier).createBooking(
      userId: user.uid,
      categories: categories,
      selectedServices: _selectedServices.toList(),
      selectedAddOns: addOnsList,
      bookingType: bookingType,
      deliveryAddress: _isDeliverySelected ? _deliveryAddressController.text.trim() : null,
      pickupDate: !_isDeliverySelected ? _selectedDate : null,
      pickupTime: !_isDeliverySelected && _selectedTime != null ? _selectedTime!.format(context) : null,
      paymentMethod: paymentMethod,
      specialInstructions: _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
    );
    
    if (!mounted) return;
    
    if (success) {
      AppUtils.showSnackBar(context, 'Booking created successfully!');
      // Pop back to home page (remove all booking creation pages from stack)
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(context, error ?? 'Failed to create booking', isError: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    final pricing = _calculatePricing();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Booking'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // SECTION 1: Category Selection (Multi-select)
                    _buildSectionCard(
                      icon: Icons.category,
                      title: 'Select Categories',
                      subtitle: 'Choose one or more categories',
                      child: _buildCategorySelection(),
                    ),
                    const SizedBox(height: 20),
                    
                    // SECTION 2: Dynamic Weight Inputs (per category)
                    if (_selectedCategories.isNotEmpty) ...[
                      _buildSectionCard(
                        icon: Icons.scale,
                        title: 'Enter Weights',
                        subtitle: 'Weight for each selected category',
                        child: _buildWeightInputs(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    // SECTION 3: Service Selection
                    _buildSectionCard(
                      icon: Icons.local_laundry_service,
                      title: 'Select Services',
                      subtitle: 'Choose one or more services',
                      child: _buildServiceSelection(),
                    ),
                    const SizedBox(height: 20),
                    
                    // SECTION 4: Add-ons
                    _buildSectionCard(
                      icon: Icons.add_circle_outline,
                      title: 'Optional Add-ons',
                      subtitle: 'Extra services for your laundry',
                      child: _buildAddOnsSelection(),
                    ),
                    const SizedBox(height: 20),
                    
                    // SECTION 5: Delivery/Pickup Fields
                    _buildSectionCard(
                      icon: _isDeliverySelected ? Icons.local_shipping : Icons.store,
                      title: _isDeliverySelected ? 'Delivery Details' : 'Pickup Details',
                      subtitle: _isDeliverySelected 
                          ? 'Your laundry will be delivered' 
                          : 'You will pick up your laundry',
                      child: _buildDeliveryPickupFields(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Special Instructions
                    TextFormField(
                      controller: _instructionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Special Instructions (Optional)',
                        hintText: 'Any special requests or notes...',
                        prefixIcon: const Icon(Icons.note),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // SECTION 6: Price Summary
                    _buildPriceSummary(pricing),
                    const SizedBox(height: 100), // Space for bottom button
                  ],
                ),
              ),
            ),
            
            // SECTION 7: Payment Button
            _buildBottomPaymentButton(bookingState, pricing),
          ],
        ),
      ),
    );
  }
  
  /// Build section card wrapper for clean UI
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
  
  /// Multi-select category chips
  Widget _buildCategorySelection() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppConstants.serviceCategories.keys.map((categoryName) {
        final isSelected = _selectedCategories.contains(categoryName);
        final categoryData = AppConstants.serviceCategories[categoryName]!;
        final minWeight = categoryData['minWeight']!;
        final minPrice = categoryData['minPrice']!;
        
        return FilterChip(
          selected: isSelected,
          label: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                categoryName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                'Min: ${AppUtils.formatCurrency(minPrice)} • ${minWeight}kg',
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
                _selectedCategories.add(categoryName);
                _categoryWeightControllers[categoryName] = TextEditingController();
              } else {
                _selectedCategories.remove(categoryName);
                _categoryWeightControllers[categoryName]?.dispose();
                _categoryWeightControllers.remove(categoryName);
              }
            });
          },
          selectedColor: Theme.of(context).colorScheme.primary,
          checkmarkColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }
  
  /// Dynamic weight inputs for each selected category
  Widget _buildWeightInputs() {
    return Column(
      children: _selectedCategories.map((categoryName) {
        final controller = _categoryWeightControllers[categoryName]!;
        final categoryData = AppConstants.serviceCategories[categoryName]!;
        final minWeight = categoryData['minWeight']!;
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '$categoryName Weight (kg)',
              hintText: 'Enter weight',
              helperText: 'Minimum $minWeight kg',
              prefixIcon: const Icon(Icons.scale),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter weight for $categoryName';
              }
              final weight = double.tryParse(value);
              if (weight == null || weight <= 0) {
                return 'Please enter a valid weight';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
        );
      }).toList(),
    );
  }
  
  /// Service selection with chips
  Widget _buildServiceSelection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.serviceTypes.entries.map((entry) {
        final serviceName = entry.key;
        final isSelected = _selectedServices.contains(serviceName);
        
        return FilterChip(
          selected: isSelected,
          label: Text(serviceName),
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedServices.add(serviceName);
              } else {
                _selectedServices.remove(serviceName);
              }
            });
          },
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          checkmarkColor: Theme.of(context).colorScheme.primary,
        );
      }).toList(),
    );
  }
  
  /// Add-ons selection (watches for Delivery selection)
  Widget _buildAddOnsSelection() {
    return Column(
      children: AppConstants.addOns.entries.map((entry) {
        final addOnName = entry.key;
        final price = entry.value;
        final isSelected = _selectedAddOns.containsKey(addOnName);
        
        return CheckboxListTile(
          value: isSelected,
          onChanged: (selected) {
            setState(() {
              if (selected == true) {
                _selectedAddOns[addOnName] = price;
                // Special handling for Delivery add-on
                if (addOnName == 'Delivery Service') {
                  _isDeliverySelected = true;
                }
              } else {
                _selectedAddOns.remove(addOnName);
                if (addOnName == 'Delivery Service') {
                  _isDeliverySelected = false;
                }
              }
            });
          },
          title: Text(addOnName),
          subtitle: Text('+${AppUtils.formatCurrency(price)}'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }
  
  /// Conditional Delivery/Pickup fields based on add-on selection
  Widget _buildDeliveryPickupFields() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isDeliverySelected
          ? _buildDeliveryFields()
          : _buildPickupFields(),
    );
  }
  
  /// Delivery address field
  Widget _buildDeliveryFields() {
    return Column(
      key: const ValueKey('delivery'),
      children: [
        TextFormField(
          controller: _deliveryAddressController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Delivery Address *',
            hintText: 'Enter complete delivery address',
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          validator: (value) {
            if (_isDeliverySelected && (value == null || value.trim().isEmpty)) {
              return 'Delivery address is required';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  /// Pickup date and time fields
  Widget _buildPickupFields() {
    return Column(
      key: const ValueKey('pickup'),
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Pickup Date *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Pickup Time *',
                    prefixIcon: const Icon(Icons.access_time),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  child: Text(
                    _selectedTime == null
                        ? 'Select time'
                        : _selectedTime!.format(context),
                    style: TextStyle(
                      color: _selectedTime == null ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPriceSummary(Map<String, double> pricing) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Price Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Selected Categories with individual weights
            if (_selectedCategories.isNotEmpty) ...[
              Text(
                'Categories:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ..._selectedCategories.map((categoryName) {
                final controller = _categoryWeightControllers[categoryName];
                final weight = double.tryParse(controller?.text ?? '0') ?? 0.0;
                final computedPrice = weight > 0 
                    ? PricingService.calculateCategoryPrice(
                        category: categoryName,
                        weight: weight,
                      )
                    : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('  • $categoryName (${weight}kg)'),
                      Text(
                        AppUtils.formatCurrency(computedPrice),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
            
            // Selected Services
            if (_selectedServices.isNotEmpty) ...[
              Text(
                'Services: ${_selectedServices.join(', ')}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 8),
            ],
            
            // Selected Add-ons with individual prices
            if (_selectedAddOns.isNotEmpty) ...[
              ..._selectedAddOns.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('  • ${e.key}'),
                      Text(AppUtils.formatCurrency(e.value)),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
            
            const Divider(height: 24, thickness: 1.5),
            
            // Pricing Breakdown
            _buildPriceRow(
              'Category Total',
              AppUtils.formatCurrency(pricing['categoryTotal']!),
            ),
            const SizedBox(height: 8),
            _buildPriceRow(
              'Services Total',
              AppUtils.formatCurrency(pricing['servicesTotal']!),
            ),
            const SizedBox(height: 8),
            _buildPriceRow(
              'Add-ons Total',
              AppUtils.formatCurrency(pricing['addOnsTotal']!),
            ),
            const SizedBox(height: 8),
            _buildPriceRow(
              'Booking Fee',
              AppUtils.formatCurrency(pricing['bookingFee']!),
            ),
            
            const Divider(height: 24, thickness: 2),
            
            // Grand Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GRAND TOTAL',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  AppUtils.formatCurrency(pricing['grandTotal']!),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
  
  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildBottomPaymentButton(BookingState bookingState, Map<String, double> pricing) {
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
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: bookingState.isLoading ? null : _proceedToPayment,
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: bookingState.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment),
                      const SizedBox(width: 8),
                      Text(
                        'Proceed to Payment • ${AppUtils.formatCurrency(pricing['grandTotal']!)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
