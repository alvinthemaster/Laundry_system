import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:laundry_system/core/constants/app_constants.dart';

class DeliveryPriceOption {
  final String address;
  final double price;

  const DeliveryPriceOption({required this.address, required this.price});
}

class DeliveryPriceService {
  DeliveryPriceService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Resolves delivery fee from Firestore collection `delivery_prices`
  /// (or `delivery_price` for backwards compatibility).
  ///
  /// Supported document shapes:
  /// - { address: "Tango", price: 35 }
  /// - { addressLower: "tango", deliveryFee: 35 }
  /// - { location/name/area: "Tango", amount/fee: 35 }
  /// - { prices: { "Tango": 35, "tango": 35 } }
  static Future<double> getDeliveryFeeForAddress(
    String address, {
    double fallback = AppConstants.deliveryFee,
  }) async {
    final normalized = address.trim();
    if (normalized.isEmpty) return fallback;

    try {
      for (final collectionName in _deliveryPriceCollections) {
        final collection = _firestore.collection(collectionName);

        // Fast path: exact field match.
        final byAddress = await collection
            .where('address', isEqualTo: normalized)
            .limit(1)
            .get();
        if (byAddress.docs.isNotEmpty) {
          final resolved = _extractFee(byAddress.docs.first.data(), normalized);
          if (resolved != null) return resolved;
        }

        // Secondary path: normalized field match.
        final byAddressLower = await collection
            .where('addressLower', isEqualTo: normalized.toLowerCase())
            .limit(1)
            .get();
        if (byAddressLower.docs.isNotEmpty) {
          final resolved =
              _extractFee(byAddressLower.docs.first.data(), normalized);
          if (resolved != null) return resolved;
        }

        // Fallback path: scan a small set and match by known address keys.
        final snapshot = await collection.limit(200).get();
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (_matchesAddress(data, normalized, doc.id)) {
            final resolved = _extractFee(data, normalized);
            if (resolved != null) return resolved;
          }
        }

        // Last resort: if collection has one global fee doc, use it.
        if (snapshot.docs.length == 1) {
          final resolved = _extractFee(snapshot.docs.first.data(), normalized);
          if (resolved != null) return resolved;
        }
      }
    } catch (_) {
      // Silent fallback keeps booking flow working even on transient errors.
    }

    return fallback;
  }

  static Future<List<DeliveryPriceOption>> getDeliveryPriceOptions({
    List<String> fallbackAddresses = const [],
  }) async {
    final Map<String, double> merged = {};

    try {
      for (final collectionName in _deliveryPriceCollections) {
        final snapshot = await _firestore.collection(collectionName).limit(200).get();
        for (final doc in snapshot.docs) {
          final data = doc.data();

          final address = _extractAddress(data, doc.id);
          if (address != null) {
            final fee = _extractFee(data, address);
            if (fee != null) {
              merged[address] = fee;
              continue;
            }
          }

          final prices = data['prices'];
          if (prices is Map) {
            for (final entry in prices.entries) {
              final key = entry.key.toString().trim();
              final fee = _toDouble(entry.value);
              if (key.isNotEmpty && fee != null) {
                merged[key] = fee;
              }
            }
          }
        }
      }
    } catch (_) {
      // Keep fallback behavior below.
    }

    if (merged.isEmpty && fallbackAddresses.isNotEmpty) {
      for (final addr in fallbackAddresses) {
        merged[addr] = AppConstants.deliveryFee;
      }
    }

    final list = merged.entries
        .map((e) => DeliveryPriceOption(address: e.key, price: e.value))
        .toList()
      ..sort((a, b) => a.address.toLowerCase().compareTo(b.address.toLowerCase()));

    return list;
  }

  static const List<String> _deliveryPriceCollections = [
    'delivery_prices',
    'delivery_price',
  ];

  static String? _extractAddress(Map<String, dynamic> data, [String? docId]) {
    final candidates = [
      data['address'],
      data['name'],
      data['location'],
      data['locationName'],
      data['area'],
      data['deliveryAddress'],
      data['addressLower'],
      docId,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final value = candidate.toString().trim();
      if (value.isNotEmpty) return value;
    }

    return null;
  }

  static bool _matchesAddress(Map<String, dynamic> data, String address, [String? docId]) {
    final normalized = address.toLowerCase();
    final candidates = [
      data['address'],
      data['addressLower'],
      data['name'],
      data['location'],
      data['locationName'],
      data['area'],
      data['deliveryAddress'],
      docId,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (candidate.toString().trim().toLowerCase() == normalized) {
        return true;
      }
    }

    return false;
  }

  static double? _extractFee(Map<String, dynamic> data, String address) {
    final direct = [
      data['price'],
      data['deliveryFee'],
      data['amount'],
      data['fee'],
    ];

    for (final value in direct) {
      final parsed = _toDouble(value);
      if (parsed != null) return parsed;
    }

    final prices = data['prices'];
    if (prices is Map) {
      final exact = prices[address];
      final lower = prices[address.toLowerCase()];
      final parsedExact = _toDouble(exact);
      if (parsedExact != null) return parsedExact;
      final parsedLower = _toDouble(lower);
      if (parsedLower != null) return parsedLower;
    }

    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}