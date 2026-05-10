class AppConstants {
  // App Info
  static const String appName = 'Laundry System';
  static const String appVersion = '1.0.0';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String bookingsCollection = 'bookings';
  static const String machinesCollection = 'machines';
  static const String machineSlotsCollection = 'machine_slots';
  static const String receiptsCollection = 'receipts';
  
  // User Roles
  static const String roleCustomer = 'customer';
  static const String roleAdmin = 'admin';
  static const String roleDriver = 'driver';
  
  // Booking Statuses
  static const String statusPending = 'Pending';
  static const String statusConfirmed = 'Confirmed';
  static const String statusWashing = 'Washing';
  static const String statusReady = 'Ready';
  static const String statusCompleted = 'Completed';
  static const String statusCancelled = 'Cancelled';
  
  // Payment Statuses
  static const String paymentUnpaid = 'Half Paid';
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

  // Service Types (Laundry service options)
  static const String serviceTypeWash = 'Wash';
  static const String serviceTypeDry = 'Dry';
  static const String serviceTypeWashDry = 'Wash & Dry';
  static const List<String> serviceTypeOptions = ['Wash', 'Dry', 'Wash & Dry'];
  
  // Booking Fee (fixed)
  static const double bookingFee = 20.0;

  // Slot rate (fixed per slot)
  static const double slotRate = 50.0;

  // Delivery fee (fixed)
  static const double deliveryFee = 30.0;

  // Machine Types
  static const String machineTypeWash = 'wash';
  static const String machineTypeDry = 'dry';
  static const String machineTypeWashDry = 'wash_dry';

  // Machine Statuses
  static const String machineStatusAvailable = 'available';
  static const String machineStatusMaintenance = 'maintenance';

  // Slot Statuses
  static const String slotAvailable = 'available';
  static const String slotBooked = 'booked';
  static const String slotInUse = 'in_use';
  static const String slotMaintenance = 'maintenance';

  // Delivery Addresses (Glan area) — A-Z order
  static const List<String> deliveryAddresses = [
    'Batulangon',
    'Batulangon Bridge',
    'Bongbongon',
    'Calabalol',
    'Calabanit Proper',
    'Calanasan',
    'Calgang Calabanit',
    'COOP Calpidong',
    'Crossing Calabanit',
    'Crossing Tinago',
    'Dream Village',
    'Glan Padidu',
    'Glan Padidu (Sanibulad)',
    'Gumasa (Baryo Lapok/Langit)',
    'Jumbo Bridge',
    'Kapatan',
    'Kapatan (Kabog)',
    'Kiesig',
    'Kiesig Coop',
    'Lago',
    'Lovesville',
    'Lower Kiogam',
    'Milagring Romblon',
    'Mudan',
    'Nacolil Sundal',
    'NIA Dam',
    'Nursery (Calabanit)',
    'San Vicente',
    'Sitio Cagang',
    'Sitio Pagi',
    'Sunrise',
    'Taluya (Bulbulan)',
    'Taluya (Macatimbol/Baybay)',
    'Tango',
    'Tapon (PBMA Chapter)',
    'Tiboy (Calabanit)',
    'Upper Kiogam',
    'Victory Village (Tumoy)',
    'Victory Village Taluya',
  ];
}
