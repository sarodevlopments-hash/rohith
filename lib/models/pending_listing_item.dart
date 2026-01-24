import 'listing.dart';
import 'sell_type.dart';
import 'food_category.dart';
import 'cooked_food_source.dart';
import 'measurement_unit.dart';
import 'pack_size.dart';

/// Represents a listing item that is being prepared but not yet submitted
class PendingListingItem {
  final String? tempId; // Temporary ID for UI purposes
  final String name;
  final double price;
  final double? originalPrice;
  final int quantity;
  final SellType type;
  final FoodCategory category;
  final CookedFoodSource? cookedFoodSource;
  final DateTime? preparedAt;
  final DateTime? expiryDate;
  final String? fssaiLicense;
  final String? imagePath;
  final MeasurementUnit? measurementUnit;
  final List<PackSize>? packSizes;
  final String? packSizeWeight; // For groceries without multiple packs
  final bool isBulkFood; // Whether this is a bulk/catering food item
  final int? servesCount; // Number of people this bulk item serves
  final String? portionDescription; // Description like "Full handi"
  
  // Live Kitchen fields
  final bool isKitchenOpen; // Whether kitchen is accepting orders
  final int? preparationTimeMinutes; // Estimated prep time per order
  final int? maxCapacity; // Maximum number of orders available

  PendingListingItem({
    this.tempId,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.quantity,
    required this.type,
    required this.category,
    this.cookedFoodSource,
    this.preparedAt,
    this.expiryDate,
    this.fssaiLicense,
    this.imagePath,
    this.measurementUnit,
    this.packSizes,
    this.packSizeWeight,
    this.isBulkFood = false,
    this.servesCount,
    this.portionDescription,
    this.isKitchenOpen = false,
    this.preparationTimeMinutes,
    this.maxCapacity,
  });

  // Convert to Listing (for final submission)
  Listing toListing({
    required String sellerId,
    required String sellerName,
  }) {
    // For groceries without multiple pack sizes, create a single pack size
    List<PackSize>? finalPackSizes = packSizes;
    final hasNoPackSizes = packSizes == null || packSizes!.isEmpty;
    if (type == SellType.groceries && 
        hasNoPackSizes && 
        packSizeWeight != null && packSizeWeight!.isNotEmpty) {
      final packWeight = double.tryParse(packSizeWeight!) ?? 0.0;
      if (packWeight > 0) {
        finalPackSizes = [
          PackSize(
            quantity: packWeight,
            price: price,
          )
        ];
      }
    }

    return Listing(
      name: name,
      sellerName: sellerName,
      price: price,
      originalPrice: originalPrice,
      quantity: quantity,
      initialQuantity: quantity,
      sellerId: sellerId,
      type: type,
      fssaiLicense: fssaiLicense,
      preparedAt: preparedAt,
      expiryDate: expiryDate,
      category: category,
      cookedFoodSource: cookedFoodSource,
      imagePath: imagePath,
      measurementUnit: measurementUnit,
      packSizes: finalPackSizes,
      isBulkFood: isBulkFood,
      servesCount: servesCount,
      portionDescription: portionDescription,
      isKitchenOpen: isKitchenOpen,
      preparationTimeMinutes: preparationTimeMinutes,
      maxCapacity: maxCapacity,
    );
  }

  PendingListingItem copyWith({
    String? tempId,
    String? name,
    double? price,
    double? originalPrice,
    int? quantity,
    SellType? type,
    FoodCategory? category,
    CookedFoodSource? cookedFoodSource,
    DateTime? preparedAt,
    DateTime? expiryDate,
    String? fssaiLicense,
    String? imagePath,
    MeasurementUnit? measurementUnit,
    List<PackSize>? packSizes,
    String? packSizeWeight,
    bool? isBulkFood,
    int? servesCount,
    String? portionDescription,
    bool? isKitchenOpen,
    int? preparationTimeMinutes,
    int? maxCapacity,
  }) {
    return PendingListingItem(
      tempId: tempId ?? this.tempId,
      name: name ?? this.name,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
      category: category ?? this.category,
      cookedFoodSource: cookedFoodSource ?? this.cookedFoodSource,
      preparedAt: preparedAt ?? this.preparedAt,
      expiryDate: expiryDate ?? this.expiryDate,
      fssaiLicense: fssaiLicense ?? this.fssaiLicense,
      imagePath: imagePath ?? this.imagePath,
      measurementUnit: measurementUnit ?? this.measurementUnit,
      packSizes: packSizes ?? this.packSizes,
      packSizeWeight: packSizeWeight ?? this.packSizeWeight,
      isBulkFood: isBulkFood ?? this.isBulkFood,
      servesCount: servesCount ?? this.servesCount,
      portionDescription: portionDescription ?? this.portionDescription,
      isKitchenOpen: isKitchenOpen ?? this.isKitchenOpen,
      preparationTimeMinutes: preparationTimeMinutes ?? this.preparationTimeMinutes,
      maxCapacity: maxCapacity ?? this.maxCapacity,
    );
  }
}
