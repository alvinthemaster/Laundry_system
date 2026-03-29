import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/utils/app_utils.dart';
import 'package:laundry_system/features/auth/presentation/providers/auth_provider.dart';
import 'package:laundry_system/features/booking/presentation/pages/payment_page.dart';
import 'package:laundry_system/features/booking/presentation/providers/booking_provider.dart';

class CreateBookingPage extends ConsumerStatefulWidget {
  const CreateBookingPage({super.key});

  @override
  ConsumerState<CreateBookingPage> createState() => _CreateBookingPageState();
}

class _CreateBookingPageState extends ConsumerState<CreateBookingPage> {
  final _formKey = GlobalKey<FormState>();
  final _instructionsController = TextEditingController();
  final _deliveryAddressController = TextEditingController();

  // Booking type
  String _bookingType = AppConstants.bookingTypePickup;

  // Categories / services / add-ons
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedServices = {};
  final Map<String, double> _selectedAddOns = {};

  // Schedule (used as pickupDate/pickupTime AND for slot availability query)
  DateTime? _scheduleDate;
  TimeOfDay? _scheduleTime;

  // Slot selection
  static const int _totalSlots = 10;
  late final List<String> _allSlots =
      List.generate(_totalSlots, (i) => 'Slot ${i + 1}');
  List<String> _availableSlots = [];
  String? _selectedSlot;
  bool _isLoadingSlots = false;

  @override
  void dispose() {
    _instructionsController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  bool get _isDelivery => _bookingType == AppConstants.bookingTypeDelivery;

  double get _deliveryFee =>
      _isDelivery ? (AppConstants.addOns['Delivery Service'] ?? 0.0) : 0.0;

  double get _addOnsTotal =>
      _selectedAddOns.values.fold(0.0, (a, b) => a + b);

  double get _grandTotal =>
      AppConstants.slotRate + _addOnsTotal + _deliveryFee + AppConstants.bookingFee;

  // ── Schedule pickers ────────────────────────────────────────────────────

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduleDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _scheduleDate = picked);
      await _refreshSlots();
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduleTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() => _scheduleTime = picked);
      await _refreshSlots();
    }
  }

  // ── Slot availability ───────────────────────────────────────────────────

  Future<void> _refreshSlots() async {
    if (_scheduleDate == null || _scheduleTime == null) {
      setState(() {
        _availableSlots = [];
        _selectedSlot = null;
      });
      return;
    }
    setState(() => _isLoadingSlots = true);
    try {
      final slots = await ref.read(bookingProvider.notifier).getAvailableSlots(
        date: _scheduleDate!,
        time: _scheduleTime!.format(context),
        allSlots: _allSlots,
      );
      if (!mounted) return;
      setState(() {
        _availableSlots = slots;
        // deselect if no longer available
        if (_selectedSlot != null && !slots.contains(_selectedSlot)) {
          _selectedSlot = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availableSlots = [];
        _selectedSlot = null;
      });
      AppUtils.showSnackBar(context, 'Failed to load slots', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingSlots = false);
    }
  }

  Future<bool> _revalidateSlot() async {
    if (_scheduleDate == null || _scheduleTime == null || _selectedSlot == null) {
      return false;
    }
    final fresh = await ref.read(bookingProvider.notifier).getAvailableSlots(
      date: _scheduleDate!,
      time: _scheduleTime!.format(context),
      allSlots: _allSlots,
    );
    return fresh.contains(_selectedSlot);
  }

  // ── Payment / create flow ────────────────────────────────────────────────

  Future<void> _proceedToPayment() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategories.isEmpty) {
      AppUtils.showSnackBar(context, 'Please select at least one category',
          isError: true);
      return;
    }
    if (_selectedServices.isEmpty) {
      AppUtils.showSnackBar(context, 'Please select at least one service',
          isError: true);
      return;
    }
    if (_isDelivery && _deliveryAddressController.text.trim().isEmpty) {
      AppUtils.showSnackBar(context, 'Please enter a delivery address',
          isError: true);
      return;
    }
    if (_scheduleDate == null) {
      final label = _isDelivery ? 'slot date' : 'pickup date';
      AppUtils.showSnackBar(context, 'Please select a $label', isError: true);
      return;
    }
    if (_scheduleTime == null) {
      final label = _isDelivery ? 'slot time' : 'pickup time';
      AppUtils.showSnackBar(context, 'Please select a $label', isError: true);
      return;
    }
    if (_selectedSlot == null) {
      AppUtils.showSnackBar(context, 'Please select a machine slot',
          isError: true);
      return;
    }

    // Re-check availability before proceeding
    final available = await _revalidateSlot();
    if (!mounted) return;
    if (!available) {
      AppUtils.showSnackBar(
          context, 'That slot was just taken. Please choose another.',
          isError: true);
      await _refreshSlots();
      return;
    }

    final paymentMethod = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          totalAmount: _grandTotal,
          onPaymentComplete: () {},
        ),
      ),
    );
    if (paymentMethod == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline,
                color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            const Text('Payment Notice'),
          ],
        ),
        content: const Text(
          'Your booking must be fully paid in the shop before the laundry '
          'service begins.',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Booking'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _createBooking(paymentMethod);
  }

  Future<void> _createBooking(String paymentMethod) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      AppUtils.showSnackBar(context, 'User not found', isError: true);
      return;
    }

    // Final availability check
    final stillAvailable = await _revalidateSlot();
    if (!mounted) return;
    if (!stillAvailable) {
      AppUtils.showSnackBar(
          context, 'Slot was just taken. Please select another.',
          isError: true);
      await _refreshSlots();
      return;
    }

    // Build add-ons list; delivery fee is tracked separately per booking type
    final addOnsList = [
      ..._selectedAddOns.entries
          .map((e) => <String, dynamic>{'name': e.key, 'price': e.value}),
      if (_isDelivery && _deliveryFee > 0)
        <String, dynamic>{'name': 'Delivery Service', 'price': _deliveryFee},
    ];

    final success = await ref.read(bookingProvider.notifier).createBooking(
      userId: user.uid,
      categories: _selectedCategories
          .map((n) => <String, dynamic>{'name': n})
          .toList(),
      selectedServices: _selectedServices.toList(),
      selectedAddOns: addOnsList,
      bookingType: _bookingType,
      deliveryAddress:
          _isDelivery ? _deliveryAddressController.text.trim() : null,
      // Store schedule date/time as pickupDate/pickupTime so that
      // getBookedSlots can query conflicts for both booking types.
      pickupDate: _scheduleDate,
      pickupTime: _scheduleTime?.format(context),
      paymentMethod: paymentMethod,
      specialInstructions: _instructionsController.text.trim().isEmpty
          ? null
          : _instructionsController.text.trim(),
      selectedSlot: _selectedSlot,
      totalAmount: _grandTotal,
      customerName: user.fullName,
    );

    if (!mounted) return;
    if (success) {
      AppUtils.showSnackBar(context, 'Booking created successfully!');
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final error = ref.read(bookingProvider).error;
      AppUtils.showSnackBar(context, error ?? 'Failed to create booking',
          isError: true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New Booking'), elevation: 0),
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
                    _buildCard(
                      icon: Icons.local_laundry_service_outlined,
                      title: 'Booking Type',
                      subtitle: 'How will you get your laundry back?',
                      child: _buildTypeSelector(),
                    ),
                    const SizedBox(height: 20),
                    _buildCard(
                      icon: Icons.category,
                      title: 'Select Categories',
                      subtitle: 'Choose the type of laundry',
                      child: _buildCategories(),
                    ),
                    const SizedBox(height: 20),
                    _buildCard(
                      icon: Icons.local_laundry_service,
                      title: 'Select Services',
                      subtitle: 'Choose one or more services',
                      child: _buildServices(),
                    ),
                    const SizedBox(height: 20),
                    _buildCard(
                      icon: Icons.add_circle_outline,
                      title: 'Optional Add-ons',
                      subtitle: 'Extra services (excluding Delivery)',
                      child: _buildAddOns(),
                    ),
                    const SizedBox(height: 20),
                    if (_isDelivery) ...[
                      _buildCard(
                        icon: Icons.local_shipping,
                        title: 'Delivery Address',
                        subtitle: 'Where should we deliver?',
                        child: _buildDeliveryField(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildCard(
                      icon: Icons.wash,
                      title: _isDelivery
                          ? 'Machine Slot'
                          : 'Pickup Schedule & Machine Slot',
                      subtitle: _isDelivery
                          ? 'Choose date, time and slot'
                          : 'When will you drop off? Choose a slot',
                      child: _buildSlotSection(),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _instructionsController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Special Instructions (Optional)',
                        hintText: 'Any notes or special requests...',
                        prefixIcon: const Icon(Icons.note_alt_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildPriceSummary(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildPayButton(bookingState),
          ],
        ),
      ),
    );
  }

  // ── Section card ─────────────────────────────────────────────────────────

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  child: Icon(icon, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600)),
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

  // ── Booking type selector ─────────────────────────────────────────────────

  Widget _buildTypeSelector() {
    return Row(
      children: [
        Expanded(child: _typeBtn(Icons.store, 'Pickup', !_isDelivery,
            () => setState(() => _bookingType = AppConstants.bookingTypePickup))),
        const SizedBox(width: 12),
        Expanded(child: _typeBtn(Icons.local_shipping, 'Delivery', _isDelivery,
            () => setState(() => _bookingType = AppConstants.bookingTypeDelivery))),
      ],
    );
  }

  Widget _typeBtn(IconData icon, String label, bool selected, VoidCallback onTap) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: selected ? color : Colors.grey),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? color : Colors.black87)),
          ],
        ),
      ),
    );
  }

  // ── Categories / services / add-ons ──────────────────────────────────────

  Widget _buildCategories() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppConstants.serviceCategories.keys.map((name) {
        final sel = _selectedCategories.contains(name);
        return FilterChip(
          selected: sel,
          label: Text(name,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: sel ? Colors.white : Colors.black87)),
          onSelected: (v) => setState(() => v
              ? _selectedCategories.add(name)
              : _selectedCategories.remove(name)),
          selectedColor: Theme.of(context).colorScheme.primary,
          checkmarkColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        );
      }).toList(),
    );
  }

  Widget _buildServices() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.serviceTypes.keys.map((name) {
        final sel = _selectedServices.contains(name);
        return FilterChip(
          selected: sel,
          label: Text(name),
          onSelected: (v) => setState(() =>
              v ? _selectedServices.add(name) : _selectedServices.remove(name)),
          selectedColor: Theme.of(context).colorScheme.primaryContainer,
          checkmarkColor: Theme.of(context).colorScheme.primary,
        );
      }).toList(),
    );
  }

  Widget _buildAddOns() {
    final entries = AppConstants.addOns.entries
        .where((e) => e.key != 'Delivery Service')
        .toList();
    if (entries.isEmpty) {
      return const Text('No additional add-ons available.',
          style: TextStyle(color: Colors.grey));
    }
    return Column(
      children: entries.map((e) {
        final sel = _selectedAddOns.containsKey(e.key);
        return CheckboxListTile(
          value: sel,
          onChanged: (v) => setState(() =>
              v == true ? _selectedAddOns[e.key] = e.value : _selectedAddOns.remove(e.key)),
          title: Text(e.key),
          subtitle: Text('+${AppUtils.formatCurrency(e.value)}'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }

  // ── Delivery address ─────────────────────────────────────────────────────

  Widget _buildDeliveryField() {
    return TextFormField(
      controller: _deliveryAddressController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Delivery Address *',
        hintText: 'Enter complete delivery address',
        prefixIcon: const Icon(Icons.location_on),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: (v) =>
          _isDelivery && (v == null || v.trim().isEmpty)
              ? 'Delivery address is required'
              : null,
    );
  }

  // ── Slot section (date + time pickers + grid) ─────────────────────────────

  Widget _buildSlotSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _datePicker()),
            const SizedBox(width: 12),
            Expanded(child: _timePicker()),
          ],
        ),
        const SizedBox(height: 16),
        _buildSlotGrid(),
      ],
    );
  }

  Widget _datePicker() {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _isDelivery ? 'Slot Date *' : 'Pickup Date *',
          prefixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        child: Text(
          _scheduleDate == null
              ? 'Select date'
              : DateFormat('MMM dd, yyyy').format(_scheduleDate!),
          style: TextStyle(
              color: _scheduleDate == null ? Colors.grey : Colors.black87),
        ),
      ),
    );
  }

  Widget _timePicker() {
    return InkWell(
      onTap: _selectTime,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: _isDelivery ? 'Slot Time *' : 'Pickup Time *',
          prefixIcon: const Icon(Icons.access_time),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        child: Text(
          _scheduleTime == null
              ? 'Select time'
              : _scheduleTime!.format(context),
          style: TextStyle(
              color: _scheduleTime == null ? Colors.grey : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildSlotGrid() {
    if (_scheduleDate == null || _scheduleTime == null) {
      return _hint(_isDelivery
          ? 'Select a date and time above to see available machine slots.'
          : 'Select a pickup date and time to see available machine slots.');
    }
    if (_isLoadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final occupied =
        _allSlots.where((s) => !_availableSlots.contains(s)).toSet();

    if (_availableSlots.isEmpty && occupied.length == _totalSlots) {
      return _hint('All slots are taken for this schedule. Please choose another date or time.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _dot(Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            const Text('Available', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 16),
            _dot(Colors.grey.shade300),
            const SizedBox(width: 4),
            const Text('Occupied', style: TextStyle(fontSize: 12)),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.4,
          ),
          itemCount: _totalSlots,
          itemBuilder: (context, i) {
            final slot = _allSlots[i];
            final isOccupied = occupied.contains(slot);
            final isSelected = _selectedSlot == slot;
            final primary = Theme.of(context).colorScheme.primary;
            return GestureDetector(
              onTap: isOccupied ? null : () => setState(() => _selectedSlot = slot),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isOccupied
                      ? Colors.grey.shade200
                      : isSelected
                          ? primary
                          : primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: isSelected
                      ? Border.all(color: primary, width: 2)
                      : null,
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${i + 1}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isOccupied
                                ? Colors.grey.shade400
                                : isSelected
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface)),
                    if (isOccupied)
                      Icon(Icons.lock_outline, size: 11, color: Colors.grey.shade400),
                    if (isSelected)
                      const Icon(Icons.check_circle, size: 11, color: Colors.white),
                  ],
                ),
              ),
            );
          },
        ),
        if (_selectedSlot != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary, size: 16),
                const SizedBox(width: 6),
                Text('$_selectedSlot selected',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _dot(Color color) => Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _hint(String msg) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey.shade500, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          ],
        ),
      );

  // ── Price summary ─────────────────────────────────────────────────────────

  Widget _buildPriceSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Price Summary',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedCategories.isNotEmpty) ...[
              Text('Categories: ${_selectedCategories.join(', ')}',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
            ],
            if (_selectedServices.isNotEmpty) ...[
              Text('Services: ${_selectedServices.join(', ')}',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
            ],
            if (_selectedSlot != null) ...[
              Text('Slot: $_selectedSlot',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
            ],
            const Divider(height: 24, thickness: 1.5),
            _row('Slot Rate (fixed)', AppUtils.formatCurrency(AppConstants.slotRate)),
            if (_selectedAddOns.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._selectedAddOns.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _row(
                        '  ${e.key}', '+${AppUtils.formatCurrency(e.value)}'),
                  )),
            ],
            if (_isDelivery && _deliveryFee > 0) ...[
              const SizedBox(height: 4),
              _row('  Delivery Service',
                  '+${AppUtils.formatCurrency(_deliveryFee)}'),
            ],
            const SizedBox(height: 8),
            _row('Booking Fee', AppUtils.formatCurrency(AppConstants.bookingFee)),
            const Divider(height: 24, thickness: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                Text(AppUtils.formatCurrency(_grandTotal),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      );

  // ── Bottom pay button ─────────────────────────────────────────────────────

  Widget _buildPayButton(BookingState bookingState) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2))
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
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: bookingState.isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payment),
                      const SizedBox(width: 8),
                      Text(
                        'Proceed to Payment  \u2022  ${AppUtils.formatCurrency(_grandTotal)}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}