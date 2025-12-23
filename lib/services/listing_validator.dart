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

    // ✅ Vegetables don't require dates
    if (l.type == SellType.vegetables) {
      // No date requirements for vegetables
    }

    return null;
  }
}
