import 'package:flutter/material.dart';

enum SellerCategory {
  cookedFood,
  liveKitchen,
  clothesApparel,
  electronics,
  electricals,
  hardware,
  automobiles,
  others,
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
      case SellerCategory.electronics:
        return 'Electronics';
      case SellerCategory.electricals:
        return 'Electricals';
      case SellerCategory.hardware:
        return 'Hardware';
      case SellerCategory.automobiles:
        return 'Automobiles';
      case SellerCategory.others:
        return 'Others';
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
      case SellerCategory.electronics:
        return 'Electronic devices and gadgets';
      case SellerCategory.electricals:
        return 'Electrical appliances and equipment';
      case SellerCategory.hardware:
        return 'Hardware tools and materials';
      case SellerCategory.automobiles:
        return 'Automobile parts and accessories';
      case SellerCategory.others:
        return 'Other products and items';
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
      case SellerCategory.electronics:
        return Icons.devices;
      case SellerCategory.electricals:
        return Icons.electrical_services;
      case SellerCategory.hardware:
        return Icons.build;
      case SellerCategory.automobiles:
        return Icons.directions_car;
      case SellerCategory.others:
        return Icons.category;
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
      case SellerCategory.electronics:
        return const Color(0xFF9B59B6); // Purple
      case SellerCategory.electricals:
        return const Color(0xFFE67E22); // Dark orange
      case SellerCategory.hardware:
        return const Color(0xFF34495E); // Dark grey-blue
      case SellerCategory.automobiles:
        return const Color(0xFFE74C3C); // Red
      case SellerCategory.others:
        return const Color(0xFF95A5A6); // Grey
    }
  }
}

