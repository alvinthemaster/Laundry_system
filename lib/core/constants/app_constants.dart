class AppConstants {
  // App Info
  static const String appName = 'Laundry System';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String bookingsCollection = 'bookings';
  
  // User Roles
  static const String roleCustomer = 'customer';
  static const String roleAdmin = 'admin';
  
  // Booking Statuses
  static const String statusPending = 'Pending';
  static const String statusConfirmed = 'Confirmed';
  static const String statusWashing = 'Washing';
  static const String statusReady = 'Ready';
  static const String statusCompleted = 'Completed';
  static const String statusCancelled = 'Cancelled';
  
  // Payment Statuses
  static const String paymentUnpaid = 'Unpaid';
  static const String paymentPaid = 'Paid';
  
  // Payment Methods
  static const String paymentGCash = 'GCash';
  static const String paymentCard = 'Credit/Debit Card';
  static const String paymentCash = 'Cash/COD';
  
  // Service Categories with pricing rules
  // Each category has: minPrice, minWeight, pricePerKg
  static const Map<String, Map<String, double>> serviceCategories = {
    'Clothes': {
      'minPrice': 200.0,
      'minWeight': 4.0,
      'pricePerKg': 50.0,
    },
    'Beddings': {
      'minPrice': 200.0,
      'minWeight': 5.5, // Average of 5-6 kilos
      'pricePerKg': 40.0,
    },
    'Bedsheet': {
      'minPrice': 200.0,
      'minWeight': 4.0,
      'pricePerKg': 45.0,
    },
  };
  
  // Service Types with fixed prices
  // These are now additive services (can select multiple)
  static const Map<String, double> serviceTypes = {
    'Wash & Fold': 50.0,
    'Wash & Iron': 75.0,
    'Dry Clean': 100.0,
  };
  
  // Optional Add-ons
  static const Map<String, double> addOns = {
    'Fabric Conditioner': 30.0,
    'Delivery Service': 30.0,
    'Stain Removal': 40.0,
  };
  
  // Booking Types
  static const String bookingTypePickup = 'pickup';
  static const String bookingTypeDelivery = 'delivery';
  
  // Booking Fee (fixed)
  static const double bookingFee = 20.0;
}
