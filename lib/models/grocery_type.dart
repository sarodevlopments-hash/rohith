import 'package:flutter/material.dart';

enum GroceryType {
  freshProduce, // Fresh Vegetables & Fruits + Agricultural Produce (merged)
  packagedGroceries, // Packaged Food & General Groceries (merged)
}

enum SellerType {
  farmer, // Farmer / Producer
  reseller, // Reseller / Trader
}

extension GroceryTypeExtension on GroceryType {
  String get displayName {
    switch (this) {
      case GroceryType.freshProduce:
        return 'Fresh Vegetables & Fruits';
      case GroceryType.packagedGroceries:
        return 'Packaged Food & General Groceries';
    }
  }

  String get subtitle {
    switch (this) {
      case GroceryType.freshProduce:
        return 'Raw & Unprocessed (Vegetables, Fruits, Grains, Pulses, Spices)';
      case GroceryType.packagedGroceries:
        return 'Sealed & Labeled Items';
    }
  }

  IconData get icon {
    switch (this) {
      case GroceryType.freshProduce:
        return Icons.eco;
      case GroceryType.packagedGroceries:
        return Icons.inventory_2;
    }
  }

  Color get color {
    switch (this) {
      case GroceryType.freshProduce:
        return const Color(0xFF50C878); // Soft green
      case GroceryType.packagedGroceries:
        return const Color(0xFF5EC6C6); // Teal
    }
  }

  bool get requiresSellerType {
    // Only Fresh Produce requires seller type selection
    return this == GroceryType.freshProduce;
  }
}

extension SellerTypeExtension on SellerType {
  String get displayName {
    switch (this) {
      case SellerType.farmer:
        return 'Farmer / Producer';
      case SellerType.reseller:
        return 'Reseller / Trader';
    }
  }

  String get description {
    switch (this) {
      case SellerType.farmer:
        return 'I grow or produce these items';
      case SellerType.reseller:
        return 'I source and resell these items';
    }
  }

  IconData get icon {
    switch (this) {
      case SellerType.farmer:
        return Icons.agriculture;
      case SellerType.reseller:
        return Icons.store;
    }
  }
}

