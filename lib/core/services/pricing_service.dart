import 'package:laundry_system/core/constants/app_constants.dart';

/// Service class responsible for all pricing calculations
/// This ensures pricing logic is centralized and prevents client-side manipulation
class PricingService {
  /// Calculate the base price for a single category based on weight
  /// Applies minimum price rule if weight is below minimum
  static double calculateCategoryPrice({
    required String category,
    required double weight,
  }) {
    final categoryData = AppConstants.serviceCategories[category];
    if (categoryData == null) return 0.0;
    
    final minPrice = categoryData['minPrice'] as double;
    final minWeight = categoryData['minWeight'] as double;
    final pricePerKg = categoryData['pricePerKg'] as double;
    
    // If weight is below minimum, charge minimum price
    if (weight <= minWeight) {
      return minPrice;
    }
    
    // Otherwise, calculate based on weight
    return weight * pricePerKg;
  }
  
  /// Calculate total price for multiple categories
  /// Each category has its own weight and computed price
  static double calculateMultipleCategoriesTotal(
    List<Map<String, dynamic>> categories,
  ) {
    double total = 0.0;
    for (final category in categories) {
      final name = category['name'] as String;
      final weight = category['weight'] as double;
      total += calculateCategoryPrice(category: name, weight: weight);
    }
    return total;
  }
  
  /// Calculate total price for selected services
  /// Each service has a fixed price regardless of weight
  static double calculateServicesTotal(List<String> selectedServices) {
    double total = 0.0;
    for (final service in selectedServices) {
      final price = AppConstants.serviceTypes[service];
      if (price != null) {
        total += price;
      }
    }
    return total;
  }
  
  /// Calculate total price for selected add-ons
  static double calculateAddOnsTotal(List<Map<String, dynamic>> selectedAddOns) {
    double total = 0.0;
    for (final addOn in selectedAddOns) {
      final price = addOn['price'] as num?;
      if (price != null) {
        total += price.toDouble();
      }
    }
    return total;
  }
  
  /// Calculate the grand total including all components (legacy single category)
  /// Formula: Category Price + Services Total + Add-ons Total + Booking Fee
  static double calculateGrandTotal({
    required String category,
    required double weight,
    required List<String> selectedServices,
    required List<Map<String, dynamic>> selectedAddOns,
  }) {
    final categoryPrice = calculateCategoryPrice(
      category: category,
      weight: weight,
    );
    
    final servicesTotal = calculateServicesTotal(selectedServices);
    final addOnsTotal = calculateAddOnsTotal(selectedAddOns);
    
    return categoryPrice + servicesTotal + addOnsTotal + AppConstants.bookingFee;
  }
  
  /// Calculate grand total for multiple categories
  /// Formula: Sum of all category prices + Services Total + Add-ons Total + Booking Fee
  static double calculateGrandTotalMultiCategory({
    required List<Map<String, dynamic>> categories,
    required List<String> selectedServices,
    required List<Map<String, dynamic>> selectedAddOns,
  }) {
    final categoryTotal = calculateMultipleCategoriesTotal(categories);
    final servicesTotal = calculateServicesTotal(selectedServices);
    final addOnsTotal = calculateAddOnsTotal(selectedAddOns);
    
    return categoryTotal + servicesTotal + addOnsTotal + AppConstants.bookingFee;
  }
  
  /// Get minimum weight for a category
  static double getMinimumWeight(String category) {
    final categoryData = AppConstants.serviceCategories[category];
    if (categoryData == null) return 0.0;
    return categoryData['minWeight'] as double;
  }
  
  /// Get minimum price for a category
  static double getMinimumPrice(String category) {
    final categoryData = AppConstants.serviceCategories[category];
    if (categoryData == null) return 0.0;
    return categoryData['minPrice'] as double;
  }
  
  /// Validate if the pricing calculation is correct
  /// This can be used server-side to verify client submissions
  static bool validatePricing({
    required String category,
    required double weight,
    required List<String> selectedServices,
    required List<Map<String, dynamic>> selectedAddOns,
    required double submittedTotal,
  }) {
    final calculatedTotal = calculateGrandTotal(
      category: category,
      weight: weight,
      selectedServices: selectedServices,
      selectedAddOns: selectedAddOns,
    );
    
    // Allow for small floating point differences
    return (calculatedTotal - submittedTotal).abs() < 0.01;
  }
  
  /// Validate pricing for multi-category bookings
  static bool validatePricingMultiCategory({
    required List<Map<String, dynamic>> categories,
    required List<String> selectedServices,
    required List<Map<String, dynamic>> selectedAddOns,
    required double submittedTotal,
  }) {
    final calculatedTotal = calculateGrandTotalMultiCategory(
      categories: categories,
      selectedServices: selectedServices,
      selectedAddOns: selectedAddOns,
    );
    
    // Allow for small floating point differences
    return (calculatedTotal - submittedTotal).abs() < 0.01;
  }
  
  /// Get category total price (sum of all categories)
  static double getCategoryTotal(List<Map<String, dynamic>> categories) {
    return calculateMultipleCategoriesTotal(categories);
  }
}
