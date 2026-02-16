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
  
  // Service Types with Prices (per kg)
  static const Map<String, double> serviceTypes = {
    'Wash & Fold': 50.0,
    'Wash & Iron': 75.0,
    'Dry Clean': 100.0,
  };
  
  // Booking Fee
  static const double bookingFee = 20.0;
}
