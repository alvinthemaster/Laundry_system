import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
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
  final _deliveryAddressController = TextEditingController();

  // Step 2: Booking Date
  DateTime? _selectedDate;

  // Step 3: Category & Add-ons
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
  void dispose() {
    _deliveryAddressController.dispose();
    super.dispose();
  }

  // Pricing calculations
  double get _addOnsTotal => _selectedAddOns.fold(
        0.0,
        (sum, a) => sum + ((a['price'] as num?)?.toDouble() ?? 0.0),
      );

  double get _slotFee =>
      _selectedSlot != null ? AppConstants.slotRate : 0.0;

  double get _deliveryFee =>
      _bookingType == AppConstants.bookingTypeDelivery
          ? AppConstants.deliveryFee
          : 0.0;

  double get _bookingFee => AppConstants.bookingFee;

  double get _totalAmount =>
      _addOnsTotal + _slotFee + _bookingFee + _deliveryFee;

  bool _canProceed() {
    switch (_currentStep) {
      case 0: // Booking Type
        if (_bookingType == AppConstants.bookingTypeDelivery &&
            _deliveryAddressController.text.trim().isEmpty) {
          return false;
        }
        return true;
      case 1: // Booking Date
        return _selectedDate != null;
      case 2: // Category & Add-ons
        return _selectedCategories.isNotEmpty;
      case 3: // Machine & Slot
        return _selectedMachine != null && _selectedSlot != null;
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

      // When entering step 3 (machine/slot), load machines
      if (_currentStep == 3) {
        _loadMachinesAndSlots();
      }
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
        return 'Please enter a delivery address';
      case 1:
        return 'Please select a booking date';
      case 2:
        return 'Please select at least one service category';
      case 3:
        return 'Please select a machine and time slot';
      default:
        return 'Please complete all required fields';
    }
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

      // Fetch slots for each available machine (read-only)
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
                deliveryAddress: _bookingType ==
                        AppConstants.bookingTypeDelivery
                    ? _deliveryAddressController.text.trim()
                    : null,
                pickupDate: _selectedDate,
                timeSlot:
                    '${_selectedSlot!.startTime} - ${_selectedSlot!.endTime}',
                paymentMethod: paymentMethod,
                machineId: _selectedMachine!.machineId,
                machineName: _selectedMachine!.machineName,
                slotId: _selectedSlot!.slotId,
                totalAmount: _totalAmount,
                slotFee: _slotFee,
                deliveryFee: _deliveryFee,
                customerName: user.fullName,
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
      'Category',
      'Machine',
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
        return _buildStep3CategoryAddOns(theme);
      case 3:
        return _buildStep4MachineSlot(theme);
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
            });
          },
        ),
        const SizedBox(height: 12),
        _BookingTypeCard(
          icon: Icons.delivery_dining,
          title: 'Delivery',
          subtitle: 'We deliver your laundry to your address',
          isSelected: _bookingType == AppConstants.bookingTypeDelivery,
          onTap: () {
            setState(() {
              _bookingType = AppConstants.bookingTypeDelivery;
            });
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
          TextField(
            controller: _deliveryAddressController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Enter your full delivery address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
          ),
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
                Text(
                  'Delivery fee: ${AppUtils.formatCurrency(AppConstants.deliveryFee)}',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 13,
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
                // Reset slot selection when date changes
                _selectedMachine = null;
                _selectedSlot = null;
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
                  'Date selected: ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
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
    );
  }

  // ============================================================
  // Step 3: Category & Add-ons
  // ============================================================
  Widget _buildStep3CategoryAddOns(ThemeData theme) {
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

  // ============================================================
  // Step 4: Machine & Time Slot Selection
  // ============================================================
  Widget _buildStep4MachineSlot(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Machine & Time Slot',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose an available machine and time slot for ${DateFormat('MMM d, yyyy').format(_selectedDate!)}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),

        // Machine type filter
        Text(
          'Filter by Machine Type',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _FilterChip(
              label: 'All',
              isSelected: _machineTypeFilter == null,
              onTap: () {
                setState(() {
                  _machineTypeFilter = null;
                  _selectedMachine = null;
                  _selectedSlot = null;
                });
                _loadMachinesAndSlots();
              },
            ),
            _FilterChip(
              label: 'Wash',
              isSelected:
                  _machineTypeFilter == AppConstants.machineTypeWash,
              onTap: () {
                setState(() {
                  _machineTypeFilter = AppConstants.machineTypeWash;
                  _selectedMachine = null;
                  _selectedSlot = null;
                });
                _loadMachinesAndSlots();
              },
            ),
            _FilterChip(
              label: 'Dry',
              isSelected:
                  _machineTypeFilter == AppConstants.machineTypeDry,
              onTap: () {
                setState(() {
                  _machineTypeFilter = AppConstants.machineTypeDry;
                  _selectedMachine = null;
                  _selectedSlot = null;
                });
                _loadMachinesAndSlots();
              },
            ),
            _FilterChip(
              label: 'Wash & Dry',
              isSelected:
                  _machineTypeFilter == AppConstants.machineTypeWashDry,
              onTap: () {
                setState(() {
                  _machineTypeFilter = AppConstants.machineTypeWashDry;
                  _selectedMachine = null;
                  _selectedSlot = null;
                });
                _loadMachinesAndSlots();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (_isLoadingSlots)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_machines.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text(
                    'No machines available',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          // Machine selection
          Text(
            'Select Machine',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // Responsive wrap grid — no overflow
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _machines.map((machine) {
                  final isSelected =
                      _selectedMachine?.machineId == machine.machineId;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMachine = machine;
                        _selectedSlot = null;
                      });
                    },
                    child: Container(
                      width: cardWidth,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? theme.colorScheme.primary
                                .withValues(alpha: 0.08)
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getMachineIcon(machine.machineType),
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  machine.machineName,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _machineTypeLabel(machine.machineType),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          // Time slot grid
          if (_selectedMachine != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Available Time Slots',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Legend
                _SlotLegend(
                    color: Colors.green.shade100, label: 'Available'),
                const SizedBox(width: 8),
                _SlotLegend(
                    color: Colors.grey.shade300, label: 'Booked'),
              ],
            ),
            const SizedBox(height: 12),
            _buildTimeSlotGrid(theme),
          ],
        ],

        // Price summary
        if (_selectedSlot != null) ...[
          const SizedBox(height: 24),
          _buildPriceSummary(theme),
        ],
      ],
    );
  }

  Widget _buildTimeSlotGrid(ThemeData theme) {
    final machineSlots = _slots
        .where((s) => s.machineId == _selectedMachine!.machineId)
        .toList();
    machineSlots.sort((a, b) => a.startTime.compareTo(b.startTime));

    if (machineSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No time slots found for this machine on the selected date.',
                style: TextStyle(color: Colors.orange.shade900, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 columns — wide enough for "08:00 - 09:00" text without overflow
        const cols = 2;
        const spacing = 8.0;
        final cardWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: machineSlots.map((slot) {
            final isSelected = _selectedSlot?.slotId == slot.slotId;
            final isAvailable = slot.isAvailable;

            Color bgColor;
            Color borderColor;
            Color timeColor;
            Color labelColor;

            if (isSelected) {
              bgColor = theme.colorScheme.primary;
              borderColor = theme.colorScheme.primary;
              timeColor = Colors.white;
              labelColor = Colors.white.withValues(alpha: 0.85);
            } else if (isAvailable) {
              bgColor = Colors.green.shade50;
              borderColor = Colors.green.shade300;
              timeColor = Colors.green.shade900;
              labelColor = Colors.green.shade700;
            } else {
              bgColor = Colors.grey.shade100;
              borderColor = Colors.grey.shade300;
              timeColor = Colors.grey.shade500;
              labelColor = Colors.grey.shade400;
            }

            String statusLabel;
            switch (slot.status) {
              case 'booked':
                statusLabel = 'Booked';
                break;
              case 'in_use':
                statusLabel = 'In Use';
                break;
              case 'maintenance':
                statusLabel = 'Maintenance';
                break;
              default:
                statusLabel = isAvailable ? 'Available' : 'Booked';
            }

            return GestureDetector(
              onTap: isAvailable
                  ? () => setState(() => _selectedSlot = slot)
                  : null,
              child: Container(
                width: cardWidth,
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(
                    color: borderColor,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : isAvailable
                              ? Icons.access_time
                              : Icons.lock_outline,
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : isAvailable
                              ? Colors.green.shade600
                              : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            slot.timeRange,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: timeColor,
                            ),
                          ),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
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
          _SummaryRow(
            label: 'Categories',
            value: _selectedCategories.isEmpty
                ? '-'
                : _selectedCategories.join(', '),
          ),
          _SummaryRow(
            label: 'Machine',
            value: _selectedMachine?.machineName ?? '-',
          ),
          _SummaryRow(
            label: 'Time Slot',
            value: _selectedSlot?.timeRange ?? '-',
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
          _SummaryRow(
            label: 'Slot Fee',
            value: AppUtils.formatCurrency(_slotFee),
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
