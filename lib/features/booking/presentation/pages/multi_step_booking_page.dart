import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/services/delivery_price_service.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/data/models/machine_model.dart';
import 'package:laundry_system/features/booking/data/models/machine_slot_model.dart';
import 'package:laundry_system/features/booking/presentation/pages/payment_page.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';

class MultiStepBookingPage extends ConsumerStatefulWidget {
  const MultiStepBookingPage({super.key});

  @override
  ConsumerState<MultiStepBookingPage> createState() =>
      _MultiStepBookingPageState();
}

class _MultiStepBookingPageState extends ConsumerState<MultiStepBookingPage> {
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Booking Type
  String _bookingType = AppConstants.bookingTypePickup;
  String? _selectedDeliveryAddress;
  List<DeliveryPriceOption> _deliveryAddressOptions = [];
  bool _isLoadingDeliveryAddresses = false;
  double _deliveryFeeFromDb = AppConstants.deliveryFee;
  bool _isLoadingDeliveryFee = false;
  DateTime? _pickupDate; // When customer will pick up their laundry

  // Step 2: Booking Date
  DateTime? _selectedDate;

  // Step 3: Service Type
  String? _serviceType;

  // Step 4: Category & Add-ons
  final List<String> _selectedCategories = [];
  final List<Map<String, dynamic>> _selectedAddOns = [];

  // Step 4: Machine & Slot
  String? _machineTypeFilter;
  MachineModel? _selectedMachine;
  MachineSlotModel? _selectedSlot;
  List<MachineModel> _machines = [];
  List<MachineSlotModel> _slots = [];
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveryAddressOptions();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Pricing calculations
  double get _addOnsTotal => _selectedAddOns.fold(
        0.0,
        (sum, a) => sum + ((a['price'] as num?)?.toDouble() ?? 0.0),
      );

  double get _deliveryFee =>
      _bookingType == AppConstants.bookingTypeDelivery
        ? _deliveryFeeFromDb
          : 0.0;

  double get _bookingFee => AppConstants.bookingFee;

  double get _totalAmount =>
      _addOnsTotal + _bookingFee + _deliveryFee;

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Booking Type
        if (_bookingType == AppConstants.bookingTypeDelivery &&
            _selectedDeliveryAddress == null) {
          return false;
        }
        if (_bookingType == AppConstants.bookingTypeDelivery &&
            _isLoadingDeliveryAddresses) {
          return false;
        }
        if (_bookingType == AppConstants.bookingTypeDelivery &&
            _isLoadingDeliveryFee) {
          return false;
        }
        return true;
      case 1: // Booking Date
        if (_selectedDate == null) return false;
        if (_bookingType == AppConstants.bookingTypePickup &&
            _pickupDate == null) return false;
        return true;
      case 2: // Service Type
        return _serviceType != null;
      case 3: // Category & Add-ons
        return _selectedCategories.isNotEmpty;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (!_canProceed()) {
      AppUtils.showSnackBar(
        context,
        _getValidationMessage(),
        isError: true,
      );
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  String _getValidationMessage() {
    switch (_currentStep) {
      case 0:
        if (_bookingType == AppConstants.bookingTypeDelivery &&
            _isLoadingDeliveryAddresses) {
          return 'Loading delivery addresses. Please wait...';
        }
        if (_bookingType == AppConstants.bookingTypeDelivery &&
            _isLoadingDeliveryFee) {
          return 'Loading delivery fee. Please wait...';
        }
        return 'Please enter a delivery address';
      case 1:
        if (_selectedDate == null) return 'Please select a booking date';
        return 'Please select a pickup date';
      case 2:
        return 'Please select a service type';
      case 3:
        return 'Please select at least one service category';
      default:
        return 'Please complete all required fields';
    }
  }

  Future<void> _loadDeliveryFeeForAddress(String address) async {
    setState(() => _isLoadingDeliveryFee = true);
    final fee = await DeliveryPriceService.getDeliveryFeeForAddress(
      address,
      fallback: AppConstants.deliveryFee,
    );
    if (!mounted) return;
    setState(() {
      _deliveryFeeFromDb = fee;
      _isLoadingDeliveryFee = false;
    });
  }

  Future<void> _loadDeliveryAddressOptions() async {
    setState(() => _isLoadingDeliveryAddresses = true);
    final options = await DeliveryPriceService.getDeliveryPriceOptions();
    if (!mounted) return;

    setState(() {
      _deliveryAddressOptions = options;
      _isLoadingDeliveryAddresses = false;
      if (_selectedDeliveryAddress != null &&
          !_deliveryAddressOptions
              .any((e) => e.address == _selectedDeliveryAddress)) {
        _selectedDeliveryAddress = null;
      }
    });
  }

  Future<void> _loadMachinesAndSlots() async {
    if (_selectedDate == null) return;

    setState(() => _isLoadingSlots = true);

    try {
      final ds = ref.read(machineDataSourceProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);

      // Fetch machines (read-only — no seeding/writing in customer flow)
      final machines = _machineTypeFilter != null
          ? await ds.getMachinesByType(_machineTypeFilter!)
          : await ds.getMachines();

      final availableMachines = machines.where((m) => m.isAvailable).toList();

      // Ensure slots exist for each machine on the selected date
      // This generates hourly slots (8 AM - 8 PM) if they don't exist yet
      for (final machine in availableMachines) {
        try {
          await ds.ensureSlotsExist(
            machineId: machine.machineId,
            date: dateStr,
          );
        } catch (_) {
          // Silently continue if slot creation fails (e.g. permission denied)
          // Existing slots will still be read below
        }
      }

      // Fetch slots for each available machine
      final List<MachineSlotModel> allSlots = [];
      for (final machine in availableMachines) {
        final slots = await ds.getSlotsForMachine(
          machineId: machine.machineId,
          date: dateStr,
        );
        allSlots.addAll(slots);
      }

      if (mounted) {
        setState(() {
          _machines = availableMachines;
          _slots = allSlots;
          _isLoadingSlots = false;
          if (_selectedMachine != null &&
              !_machines.any((m) => m.machineId == _selectedMachine!.machineId)) {
            _selectedMachine = null;
            _selectedSlot = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSlots = false);
        final msg = e.toString().contains('permission-denied')
            ? 'Permission denied. Please check your Firestore security rules.'
            : 'Failed to load machines: $e';
        AppUtils.showSnackBar(context, msg, isError: true);
      }
    }
  }

  Future<void> _confirmBooking() async {
    if (!_canProceed()) return;

    if (_bookingType == AppConstants.bookingTypeDelivery &&
        _isLoadingDeliveryFee) {
      AppUtils.showSnackBar(
        context,
        'Delivery fee is still loading. Please wait a moment.',
        isError: true,
      );
      return;
    }

    // Navigate to payment page
    final paymentMethod = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          totalAmount: _totalAmount,
          onPaymentComplete: () {},
        ),
      ),
    );

    if (paymentMethod == null || !mounted) return;

    AppUtils.showLoadingDialog(context);

    try {
      final user = ref.read(authProvider).user;
      if (user == null) {
        if (mounted) {
          AppUtils.hideLoadingDialog(context);
          AppUtils.showSnackBar(context, 'User not found', isError: true);
        }
        return;
      }

      // Create booking — the slot availability is enforced by Firestore rules
      // and the booking document itself records the slotId.
      // Slot status update is handled server-side / by admin workflow.
      final success =
          await ref.read(bookingProvider.notifier).createBooking(
                userId: user.uid,
                categories: _selectedCategories
                    .map((cat) => {
                          'name': cat,
                          'weight': 0.0,
                          'computedPrice': 0.0,
                        })
                    .toList(),
                selectedAddOns: _selectedAddOns,
                bookingType: _bookingType,
                serviceType: _serviceType,
                deliveryAddress: _bookingType ==
                        AppConstants.bookingTypeDelivery
                    ? _selectedDeliveryAddress
                    : null,
                pickupDate: _bookingType == AppConstants.bookingTypePickup
                    ? _pickupDate
                    : _selectedDate,
                paymentMethod: paymentMethod,
                totalAmount: _totalAmount,
                deliveryFee: _deliveryFee,
                customerName: user.fullName,
                customerPhone: user.phoneNumber,
              );

      if (mounted) {
        AppUtils.hideLoadingDialog(context);

        if (success) {
          AppUtils.showSnackBar(context, 'Booking created successfully!');
          Navigator.of(context).pop(true);
        } else {
          final error = ref.read(bookingProvider).error;
          AppUtils.showSnackBar(
            context,
            error ?? 'Failed to create booking',
            isError: true,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.hideLoadingDialog(context);
        final errStr = e.toString();
        if (errStr.contains('SLOT_UNAVAILABLE')) {
          // Another user just grabbed this slot — refresh and let the user pick again.
          AppUtils.showSnackBar(
            context,
            'That time slot was just taken. Please choose another.',
            isError: true,
          );
          setState(() => _selectedSlot = null);
          _loadMachinesAndSlots();
        } else {
          AppUtils.showSnackBar(
            context,
            'Error creating booking: $errStr',
            isError: true,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Booking'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(theme),

          // Step content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStep(theme),
            ),
          ),

          // Navigation buttons
          _buildNavigationButtons(theme),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme) {
    final stepLabels = [
      'Type',
      'Date',
      'Service',
      'Category',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(_totalSteps, (index) {
              final isActive = index == _currentStep;
              final isCompleted = index < _currentStep;

              return Expanded(
                child: Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isCompleted || isActive
                              ? theme.colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? theme.colorScheme.primary
                            : isActive
                                ? theme.colorScheme.primary
                                : Colors.grey.shade300,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check,
                                size: 18, color: Colors.white)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ),
                    if (index < _totalSteps - 1 && index == 0)
                      const SizedBox(),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_totalSteps, (index) {
              return Expanded(
                child: Text(
                  stepLabels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: index == _currentStep
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: index <= _currentStep
                        ? theme.colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Text(
            'Step ${_currentStep + 1} of $_totalSteps',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep(ThemeData theme) {
    switch (_currentStep) {
      case 0:
        return _buildStep1BookingType(theme);
      case 1:
        return _buildStep2BookingDate(theme);
      case 2:
        return _buildStep3ServiceType(theme);
      case 3:
        return _buildStep4CategoryAddOns(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // Step 1: Booking Type
  // ============================================================
  Widget _buildStep1BookingType(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Booking Type',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose how you want to receive your laundry',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        _BookingTypeCard(
          icon: Icons.store,
          title: 'Pickup',
          subtitle: 'Pick up your laundry at the shop',
          isSelected: _bookingType == AppConstants.bookingTypePickup,
          onTap: () {
            setState(() {
              _bookingType = AppConstants.bookingTypePickup;
              _isLoadingDeliveryFee = false;
            });
          },
        ),
        const SizedBox(height: 12),
        _BookingTypeCard(
          icon: Icons.delivery_dining,
          title: 'Delivery',
          subtitle: 'We deliver your laundry to your address',
          isSelected: _bookingType == AppConstants.bookingTypeDelivery,
          onTap: () async {
            setState(() {
              _bookingType = AppConstants.bookingTypeDelivery;
            });
            if (_deliveryAddressOptions.isEmpty && !_isLoadingDeliveryAddresses) {
              await _loadDeliveryAddressOptions();
            }
            if (_selectedDeliveryAddress != null) {
              await _loadDeliveryFeeForAddress(_selectedDeliveryAddress!);
            }
          },
        ),

        // Delivery address field
        if (_bookingType == AppConstants.bookingTypeDelivery) ...[
          const SizedBox(height: 24),
          Text(
            'Delivery Address',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedDeliveryAddress,
            isExpanded: true,
            decoration: InputDecoration(
              hintText: _isLoadingDeliveryAddresses
                  ? 'Loading delivery addresses...'
                  : 'Select your delivery address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            items: _deliveryAddressOptions
                .map((option) => DropdownMenuItem(
                      value: option.address,
                      child: Text(option.address),
                    ))
                .toList(),
            onTap: () {
              if (_deliveryAddressOptions.isEmpty && !_isLoadingDeliveryAddresses) {
                _loadDeliveryAddressOptions();
              }
            },
            onChanged: _isLoadingDeliveryAddresses
                ? null
                : (value) async {
              setState(() => _selectedDeliveryAddress = value);
              if (value != null) {
                final match = _deliveryAddressOptions.where((e) => e.address == value);
                if (match.isNotEmpty) {
                  setState(() => _deliveryFeeFromDb = match.first.price);
                } else {
                  await _loadDeliveryFeeForAddress(value);
                }
              }
            },
          ),
          if (!_isLoadingDeliveryAddresses && _deliveryAddressOptions.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'No delivery addresses found in Firestore (delivery_prices).',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 18, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: _isLoadingDeliveryFee
                      ? Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Loading delivery fee...',
                              style: TextStyle(
                                color: Colors.orange.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          'Delivery fee: ${AppUtils.formatCurrency(_deliveryFee)}',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 13,
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
                Icon(Icons.location_on,
                    size: 18, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.red.shade900,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Delivery Area Notice: ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              'Our delivery service is available within Glan area only. Please ensure your address is within this coverage area before proceeding.',
                        ),
                        TextSpan(
                          text: '\nCurrent Delivery Fee: ${AppUtils.formatCurrency(_deliveryFee)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],


      ],
    );
  }

  // ============================================================
  // Step 2: Booking Date
  // ============================================================
  Widget _buildStep2BookingDate(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Booking Date',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose your preferred booking date',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDate ?? now.add(const Duration(days: 1)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 30)),
            );
            if (picked != null) {
              setState(() {
                _selectedDate = picked;
                // Reset slot and pickup date when booking date changes
                _selectedMachine = null;
                _selectedSlot = null;
                // If pickup date is now before new booking date, reset it
                if (_pickupDate != null && _pickupDate!.isBefore(picked)) {
                  _pickupDate = null;
                }
              });
            }
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              border: Border.all(
                color: _selectedDate != null
                    ? theme.colorScheme.primary
                    : Colors.grey.shade300,
                width: _selectedDate != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _selectedDate != null
                  ? theme.colorScheme.primary.withOpacity(0.05)
                  : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: _selectedDate != null
                      ? theme.colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 16),
                Text(
                  _selectedDate != null
                      ? DateFormat('EEEE, MMMM d, yyyy')
                          .format(_selectedDate!)
                      : 'Tap to select a date',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: _selectedDate != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _selectedDate != null
                        ? theme.colorScheme.primary
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedDate != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    size: 18, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  'Booking date: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Pickup date — only for Pickup booking type
        if (_bookingType == AppConstants.bookingTypePickup) ...[  
          const SizedBox(height: 24),
          Text(
            'Pickup Date',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When would you like to collect your finished laundry?',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              // Pickup date must be on or after the booking date
              final earliest = _selectedDate ?? DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _pickupDate != null && !_pickupDate!.isBefore(earliest)
                    ? _pickupDate!
                    : earliest.add(const Duration(days: 1)),
                firstDate: earliest,
                lastDate: earliest.add(const Duration(days: 30)),
              );
              if (picked != null) {
                setState(() {
                  _pickupDate = picked;
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _pickupDate != null
                      ? theme.colorScheme.primary
                      : Colors.grey.shade300,
                  width: _pickupDate != null ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
                color: _pickupDate != null
                    ? theme.colorScheme.primary.withValues(alpha: 0.05)
                    : Colors.white,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available,
                    color: _pickupDate != null
                        ? theme.colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  Text(
                    _pickupDate != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_pickupDate!)
                        : 'Tap to select pickup date',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: _pickupDate != null
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: _pickupDate != null
                          ? theme.colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_pickupDate != null) ...[  
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'Pickup date: ${DateFormat('MMM d, yyyy').format(_pickupDate!)}',
                    style: TextStyle(
                      color: Colors.green.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ============================================================
  // Step 3: Service Type
  // ============================================================
  Widget _buildStep3ServiceType(ThemeData theme) {
    const serviceOptions = [
      (
        value: AppConstants.serviceTypeWash,
        label: 'Wash',
        description: 'Laundry washed and folded',
        icon: Icons.local_laundry_service,
      ),
      (
        value: AppConstants.serviceTypeDry,
        label: 'Dry',
        description: 'Laundry dried only',
        icon: Icons.dry,
      ),
      (
        value: AppConstants.serviceTypeWashDry,
        label: 'Wash & Dry',
        description: 'Full wash and dry service',
        icon: Icons.dry_cleaning,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Service Type',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'What service do you need?',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        ...serviceOptions.map((option) {
          final isSelected = _serviceType == option.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _serviceType = option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.05)
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        option.icon,
                        color: isSelected ? Colors.white : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.label,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary, size: 24),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============================================================
  // Step 4: Category & Add-ons
  // ============================================================
  Widget _buildStep4CategoryAddOns(ThemeData theme) {
    final categories = AppConstants.serviceCategories.keys.toList();
    final addOns = {
      'Fabric Conditioner': 30.0,
      'Stain Removal': 40.0,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Categories',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose one or more laundry service types',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...categories.map((cat) {
          final isSelected = _selectedCategories.contains(cat);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(cat);
                  } else {
                    _selectedCategories.add(cat);
                  }
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? theme.colorScheme.primary.withOpacity(0.05)
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(cat),
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      cat,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle,
                          color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          );
        }),

        const SizedBox(height: 24),
        Text(
          'Optional Add-ons',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Enhance your laundry experience',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        ...addOns.entries.map((entry) {
          final isSelected = _selectedAddOns
              .any((a) => a['name'] == entry.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedAddOns
                        .removeWhere((a) => a['name'] == entry.key);
                  } else {
                    _selectedAddOns.add({
                      'name': entry.key,
                      'price': entry.value,
                    });
                  }
                });
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? theme.colorScheme.secondary
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isSelected
                      ? theme.colorScheme.secondary.withOpacity(0.05)
                      : Colors.white,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) {
                        setState(() {
                          if (isSelected) {
                            _selectedAddOns.removeWhere(
                                (a) => a['name'] == entry.key);
                          } else {
                            _selectedAddOns.add({
                              'name': entry.key,
                              'price': entry.value,
                            });
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    Text(
                      AppUtils.formatCurrency(entry.value),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Clothes':
        return Icons.checkroom;
      case 'Beddings':
        return Icons.bed;
      case 'Bedsheet':
        return Icons.king_bed;
      default:
        return Icons.local_laundry_service;
    }
  }
  Widget _buildPriceSummary(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Booking Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(),
          _SummaryRow(
            label: 'Booking Type',
            value: _bookingType == AppConstants.bookingTypeDelivery
                ? 'Delivery'
                : 'Pickup',
          ),
          _SummaryRow(
            label: 'Date',
            value: DateFormat('MMM d, yyyy').format(_selectedDate!),
          ),
          if (_bookingType == AppConstants.bookingTypePickup &&
              _pickupDate != null)
            _SummaryRow(
              label: 'Pickup Date',
              value: DateFormat('MMM d, yyyy').format(_pickupDate!),
            ),
          _SummaryRow(
            label: 'Categories',
            value: _selectedCategories.isEmpty
                ? '-'
                : _selectedCategories.join(', '),
          ),
          if (_selectedAddOns.isNotEmpty)
            _SummaryRow(
              label: 'Add-ons',
              value: _selectedAddOns
                  .map((a) => a['name'] as String)
                  .join(', '),
            ),
          const Divider(),
          _SummaryRow(
            label: 'Booking Fee',
            value: AppUtils.formatCurrency(_bookingFee),
          ),
          if (_deliveryFee > 0)
            _SummaryRow(
              label: 'Delivery Fee',
              value: AppUtils.formatCurrency(_deliveryFee),
            ),
          if (_addOnsTotal > 0)
            _SummaryRow(
              label: 'Add-ons Total',
              value: AppUtils.formatCurrency(_addOnsTotal),
            ),
          const Divider(),
          _SummaryRow(
            label: 'Total Amount',
            value: AppUtils.formatCurrency(_totalAmount),
            isBold: true,
          ),
        ],
      ),
    );
  }

  IconData _getMachineIcon(String type) {
    switch (type) {
      case 'wash':
        return Icons.local_laundry_service;
      case 'dry':
        return Icons.dry_cleaning;
      case 'wash_dry':
        return Icons.wash;
      default:
        return Icons.local_laundry_service;
    }
  }

  String _machineTypeLabel(String type) {
    switch (type) {
      case 'wash':
        return 'Washer';
      case 'dry':
        return 'Dryer';
      case 'wash_dry':
        return 'Wash & Dry';
      default:
        return type;
    }
  }

  Widget _buildNavigationButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _previousStep,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: 12),
            Expanded(
              flex: _currentStep == 0 ? 1 : 1,
              child: ElevatedButton.icon(
                onPressed: _currentStep == _totalSteps - 1
                    ? (_canProceed() ? _confirmBooking : null)
                    : _nextStep,
                icon: Icon(
                  _currentStep == _totalSteps - 1
                      ? Icons.payment
                      : Icons.arrow_forward,
                ),
                label: Text(
                  _currentStep == _totalSteps - 1
                      ? 'Proceed to Payment'
                      : 'Next',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Helper Widgets
// ============================================================

class _BookingTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _BookingTypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.05)
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor:
            isSelected ? theme.colorScheme.primary : Colors.grey.shade100,
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : Colors.grey.shade300,
        ),
      ),
    );
  }
}

class _SlotLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _SlotLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
              color: isBold
                  ? Theme.of(context).colorScheme.primary
                  : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
