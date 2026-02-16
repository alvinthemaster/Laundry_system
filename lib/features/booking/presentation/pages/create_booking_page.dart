import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';
import 'package:intl/intl.dart';

class CreateBookingPage extends ConsumerStatefulWidget {
  const CreateBookingPage({super.key});
  
  @override
  ConsumerState<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends ConsumerState<CreateBookingPage> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedServiceType;
  final _weightController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final _instructionsController = TextEditingController();
  
  @override
  void dispose() {
    _weightController.dispose();
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
  
  double _calculateTotal() {
    if (_selectedServiceType == null || _weightController.text.isEmpty) {
      return AppConstants.bookingFee;
    }
    
    final weight = double.tryParse(_weightController.text) ?? 0;
    return ref.read(bookingProvider.notifier).calculateTotalAmount(
      serviceType: _selectedServiceType!,
      weight: weight,
      bookingFee: AppConstants.bookingFee,
    );
  }
  
  Future<void> _createBooking() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedServiceType == null) {
      AppUtils.showSnackBar(context, 'Please select a service type', isError: true);
      return;
    }
    
    if (_selectedDate == null) {
      AppUtils.showSnackBar(context, 'Please select pickup date', isError: true);
      return;
    }
    
    if (_selectedTime == null) {
      AppUtils.showSnackBar(context, 'Please select pickup time', isError: true);
      return;
    }
    
    final user = ref.read(authProvider).user;
    if (user == null) {
      AppUtils.showSnackBar(context, 'User not found', isError: true);
      return;
    }
    
    final weight = double.parse(_weightController.text);
    final pickupTime = _selectedTime!.format(context);
    
    final success = await ref.read(bookingProvider.notifier).createBooking(
      userId: user.uid,
      serviceType: _selectedServiceType!,
      weight: weight,
      pickupDate: _selectedDate!,
      pickupTime: pickupTime,
      specialInstructions: _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
    );
    
    if (!mounted) return;
    
    if (success) {
      AppUtils.showSnackBar(context, 'Booking created successfully!');
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(context, error ?? 'Failed to create booking', isError: true);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Booking'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              // Service Type
              Text(
                'Select Service Type',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...AppConstants.serviceTypes.entries.map((entry) {
                return RadioListTile<String>(
                  title: Text(entry.key),
                  subtitle: Text('${AppUtils.formatCurrency(entry.value)} per kg'),
                  value: entry.key,
                  groupValue: _selectedServiceType,
                  onChanged: (value) {
                    setState(() {
                      _selectedServiceType = value;
                    });
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedServiceType == entry.key
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                    ),
                  ),
                );
              }).toList(),
              const SizedBox(height: 20),
              
              // Weight
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  prefixIcon: Icon(Icons.scale),
                  helperText: 'Estimated weight of your laundry',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  final weight = double.tryParse(value);
                  if (weight == null || weight <= 0) {
                    return 'Please enter a valid weight';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              
              // Pickup Date
              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Pickup Date',
                    prefixIcon: Icon(Icons.calendar_today),
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
              const SizedBox(height: 16),
              
              // Pickup Time
              InkWell(
                onTap: _selectTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Pickup Time',
                    prefixIcon: Icon(Icons.access_time),
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
              const SizedBox(height: 20),
              
              // Special Instructions
              TextFormField(
                controller: _instructionsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Special Instructions (Optional)',
                  prefixIcon: Icon(Icons.note),
                  helperText: 'Any special requests or notes',
                ),
              ),
              const SizedBox(height: 30),
              
              // Price Summary
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price Summary',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Booking Fee'),
                          Text(AppUtils.formatCurrency(AppConstants.bookingFee)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_selectedServiceType != null && _weightController.text.isNotEmpty)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Service Charge (${_weightController.text} kg)'),
                            Text(
                              AppUtils.formatCurrency(
                                (double.tryParse(_weightController.text) ?? 0) *
                                    AppConstants.serviceTypes[_selectedServiceType!]!,
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
                            AppUtils.formatCurrency(_calculateTotal()),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              
              // Create Booking Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: bookingState.isLoading ? null : _createBooking,
                  child: bookingState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Booking'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
