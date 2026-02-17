import 'package:flutter/material.dart';
import 'package:laundry_system/core/constants/app_constants.dart';
import 'package:laundry_system/core/utils/app_utils.dart';

/// Mock Payment Page for selecting payment method
/// In production, this would integrate with actual payment gateways
class PaymentPage extends StatefulWidget {
  final double totalAmount;
  final VoidCallback onPaymentComplete;
  
  const PaymentPage({
    super.key,
    required this.totalAmount,
    required this.onPaymentComplete,
  });
  
  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? _selectedPaymentMethod;
  bool _isProcessing = false;
  
  void _processPayment() async {
    if (_selectedPaymentMethod == null) {
      AppUtils.showSnackBar(
        context,
        'Please select a payment method',
        isError: true,
      );
      return;
    }
    
    setState(() {
      _isProcessing = true;
    });
    
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    setState(() {
      _isProcessing = false;
    });
    
    // Show success message based on payment method
    final successMessage = _selectedPaymentMethod == AppConstants.paymentGCash
        ? 'Payment successful! Booking confirmed.'
        : 'Booking confirmed! Payment will be collected on delivery/pickup.';
    
    AppUtils.showSnackBar(
      context,
      successMessage,
    );
    
    // Navigate back with payment method
    Navigator.of(context).pop(_selectedPaymentMethod);
    
    // Call completion callback
    widget.onPaymentComplete();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount to Pay
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      AppUtils.formatCurrency(widget.totalAmount),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            
            // Payment Methods Section
            Text(
              'Select Payment Method',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // GCash
            _PaymentMethodTile(
              icon: Icons.payment,
              title: AppConstants.paymentGCash,
              subtitle: 'Pay instantly with GCash (Paid immediately)',
              value: AppConstants.paymentGCash,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value;
                });
              },
            ),
            const SizedBox(height: 12),
            
            // Cash/COD
            _PaymentMethodTile(
              icon: Icons.money,
              title: AppConstants.paymentCash,
              subtitle: 'Pay when receiving your laundry (Cash on Delivery/Pickup)',
              value: AppConstants.paymentCash,
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value;
                });
              },
            ),
            const SizedBox(height: 30),
            
            // Payment Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedPaymentMethod == AppConstants.paymentGCash
                          ? 'GCash: Payment will be marked as PAID immediately.'
                          : _selectedPaymentMethod == AppConstants.paymentCash
                              ? 'Cash/COD: Payment will be marked as UNPAID until you pay upon delivery/pickup.'
                              : 'Please select a payment method.',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isProcessing
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
                          const Icon(Icons.lock_outline),
                          const SizedBox(width: 8),
                          Text(
                            _selectedPaymentMethod == AppConstants.paymentCash
                                ? 'Confirm Booking (${AppUtils.formatCurrency(widget.totalAmount)})'
                                : 'Pay ${AppUtils.formatCurrency(widget.totalAmount)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String? groupValue;
  final ValueChanged<String?> onChanged;
  
  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    final isSelected = value == groupValue;
    
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
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
                          ? Theme.of(context).colorScheme.primary
                          : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
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
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
