import 'package:flutter/material.dart';

enum SellerCategory {
  cookedFood,
  liveKitchen,
  clothesApparel,
}

extension SellerCategoryExtension on SellerCategory {
  String get displayName {
    switch (this) {
      case SellerCategory.cookedFood:
        return 'Cooked Food';
      case SellerCategory.liveKitchen:
        return 'Live Kitchen';
      case SellerCategory.clothesApparel:
        return 'Clothes & Apparel';
    }
  }

  String get subtitle {
    switch (this) {
      case SellerCategory.cookedFood:
        return 'Pre-cooked food items ready for sale';
      case SellerCategory.liveKitchen:
        return 'Cook on demand - real-time orders';
      case SellerCategory.clothesApparel:
        return 'Clothing and apparel items';
    }
  }

  IconData get icon {
    switch (this) {
      case SellerCategory.cookedFood:
        return Icons.restaurant;
      case SellerCategory.liveKitchen:
        return Icons.kitchen;
      case SellerCategory.clothesApparel:
        return Icons.checkroom;
    }
  }

  Color get color {
    switch (this) {
      case SellerCategory.cookedFood:
        return const Color(0xFFFF6B6B); // Coral red
      case SellerCategory.liveKitchen:
        return const Color(0xFFFFB703); // Orange
      case SellerCategory.clothesApparel:
        return const Color(0xFF6FA8FF); // Soft blue
    }
  }
}

