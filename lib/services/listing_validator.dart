import '../models/listing.dart';
import '../models/sell_type.dart';

class ListingValidator {
  static String? validate(Listing l) {
    if (l.name.trim().isEmpty) {
      return "Item name is required";
    }

    if (l.imagePath == null || l.imagePath!.isEmpty) {
      return "Product image is required";
    }

    if (l.quantity <= 0) {
      return "Quantity must be greater than 0";
    }

    if (l.price <= 0) {
      return "Selling price must be greater than 0";
    }

    // ✅ Original price rules
    if (l.originalPrice != null) {
      if (l.originalPrice! <= l.price) {
        return "Selling price must be less than original price";
      }

      final discount =
          ((l.originalPrice! - l.price) / l.originalPrice!) * 100;

      if (discount < 20) {
        return "Minimum 20% discount required";
      }
    }
//     if (l.category == null) {
//   return "Please select food category (Veg / Egg / Non-Veg)";
// }
// if (l.type == SellType.cookedFood) {
//   if (l.cookedFoodSource == null) {
//     return "Please select cooked food source";
//   }
// }


    // ✅ Cooked food rules (not applicable for vegetables)
    if (l.type == SellType.cookedFood) {
      if (l.fssaiLicense == null || l.fssaiLicense!.isEmpty) {
        return "FSSAI license is required";
      }

      if (l.preparedAt == null) {
        return "Prepared time is required";
      }

      if (l.expiryDate == null) {
        return "Expiry time is required";
      }

      if (!l.expiryDate!.isAfter(l.preparedAt!)) {
        return "Expiry must be after preparation time";
      }
    }

    // ✅ Vegetables and Groceries don't require dates
    if (l.type == SellType.vegetables || l.type == SellType.groceries) {
      // No date requirements for vegetables and groceries
    }

    // ✅ Bulk food item rules
    if (l.isBulkFood) {
      if (l.servesCount == null || l.servesCount! <= 1) {
        return "Bulk items must serve more than 1 person";
      }
      if (l.price <= 0) {
        return "Bulk item must have a valid total price";
      }
    }

    // ✅ Live Kitchen rules
    if (l.type == SellType.liveKitchen) {
      // Preparation time is required for live kitchen
      if (l.preparationTimeMinutes == null || l.preparationTimeMinutes! <= 0) {
        return "Preparation time is required for Live Kitchen items";
      }
      // Capacity must be positive
      if (l.maxCapacity == null || l.maxCapacity! <= 0) {
        return "Maximum order capacity is required for Live Kitchen items";
      }
      // No expiry date required for live kitchen items
      // FSSAI is still recommended but not required
    }

    return null;
  }

  /// Validates if a live kitchen order can be placed
  static String? validateLiveKitchenOrder(Listing l) {
    if (!l.isLiveKitchen) {
      return "This is not a Live Kitchen item";
    }
    if (!l.isKitchenOpen) {
      return "Kitchen is currently closed";
    }
    if (!l.hasAvailableCapacity) {
      return "No available order slots";
    }
    return null;
  }
}
