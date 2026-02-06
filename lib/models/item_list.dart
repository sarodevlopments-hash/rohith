import 'pending_listing_item.dart';
import 'sell_type.dart';
import 'food_category.dart';
import 'cooked_food_source.dart';
import 'measurement_unit.dart';
import 'pack_size.dart';

/// Represents a saved list of items that sellers can reuse
class ItemList {
  final String id;
  final String sellerId;
  final String name;
  final List<PendingListingItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUsedAt;
  final int usageCount; // How many times this list has been used

  ItemList({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    this.lastUsedAt,
    this.usageCount = 0,
  });

  int get itemCount => items.length;

  // Convert to Firestore Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'name': name,
      'items': items.map((item) => itemToMap(item)).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastUsedAt': lastUsedAt?.toIso8601String(),
      'usageCount': usageCount,
    };
  }

  // Convert from Firestore Map
  factory ItemList.fromMap(Map<String, dynamic> map) {
    return ItemList(
      id: map['id'] ?? '',
      sellerId: map['sellerId'] ?? '',
      name: map['name'] ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((item) => _itemFromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
      lastUsedAt: map['lastUsedAt'] != null
          ? DateTime.parse(map['lastUsedAt'])
          : null,
      usageCount: map['usageCount'] ?? 0,
    );
  }

  // Convert PendingListingItem to Map (public static for service use)
  static Map<String, dynamic> itemToMap(PendingListingItem item) {
    return {
      'tempId': item.tempId,
      'name': item.name,
      'price': item.price,
      'originalPrice': item.originalPrice,
      'quantity': item.quantity,
      'type': item.type.toString().split('.').last,
      'category': item.category.toString().split('.').last,
      'cookedFoodSource': item.cookedFoodSource?.toString().split('.').last,
      'preparedAt': item.preparedAt?.toIso8601String(),
      'expiryDate': item.expiryDate?.toIso8601String(),
      'fssaiLicense': item.fssaiLicense,
      'imagePath': item.imagePath,
      'measurementUnit': item.measurementUnit?.toString().split('.').last,
      'packSizes': item.packSizes?.map((ps) => {
            'quantity': ps.quantity,
            'price': ps.price,
            'label': ps.label,
          }).toList(),
      'packSizeWeight': item.packSizeWeight,
      'isBulkFood': item.isBulkFood,
      'servesCount': item.servesCount,
      'portionDescription': item.portionDescription,
      'isKitchenOpen': item.isKitchenOpen,
      'preparationTimeMinutes': item.preparationTimeMinutes,
      'maxCapacity': item.maxCapacity,
    };
  }

  // Convert Map to PendingListingItem
  static PendingListingItem _itemFromMap(Map<String, dynamic> map) {
    // Parse enums
    SellType? sellType;
    FoodCategory? foodCategory;
    CookedFoodSource? cookedFoodSource;
    MeasurementUnit? measurementUnit;

    try {
      final typeStr = map['type'] as String?;
      if (typeStr != null) {
        sellType = SellType.values.firstWhere(
          (e) => e.toString().split('.').last == typeStr,
          orElse: () => SellType.cookedFood,
        );
      }

      final categoryStr = map['category'] as String?;
      if (categoryStr != null) {
        foodCategory = FoodCategory.values.firstWhere(
          (e) => e.toString().split('.').last == categoryStr,
          orElse: () => FoodCategory.veg,
        );
      }

      final sourceStr = map['cookedFoodSource'] as String?;
      if (sourceStr != null) {
        cookedFoodSource = CookedFoodSource.values.firstWhere(
          (e) => e.toString().split('.').last == sourceStr,
          orElse: () => CookedFoodSource.home,
        );
      }

      final unitStr = map['measurementUnit'] as String?;
      if (unitStr != null) {
        measurementUnit = MeasurementUnit.values.firstWhere(
          (e) => e.toString().split('.').last == unitStr,
        );
      }
    } catch (e) {
      // Use defaults if parsing fails
      sellType = SellType.cookedFood;
      foodCategory = FoodCategory.veg;
    }

    // Parse pack sizes
    List<PackSize>? packSizes;
    if (map['packSizes'] != null) {
      packSizes = (map['packSizes'] as List<dynamic>)
          .map((ps) => PackSize(
                quantity: (ps['quantity'] as num).toDouble(),
                price: (ps['price'] as num).toDouble(),
                label: ps['label'] as String?,
              ))
          .toList();
    }

    return PendingListingItem(
      tempId: map['tempId'] as String?,
      name: map['name'] ?? '',
      price: (map['price'] as num).toDouble(),
      originalPrice: map['originalPrice'] != null
          ? (map['originalPrice'] as num).toDouble()
          : null,
      quantity: map['quantity'] ?? 1,
      type: sellType ?? SellType.cookedFood,
      category: foodCategory ?? FoodCategory.veg,
      cookedFoodSource: cookedFoodSource,
      preparedAt: map['preparedAt'] != null
          ? DateTime.parse(map['preparedAt'])
          : null,
      expiryDate: map['expiryDate'] != null
          ? DateTime.parse(map['expiryDate'])
          : null,
      fssaiLicense: map['fssaiLicense'] as String?,
      imagePath: map['imagePath'] as String?,
      measurementUnit: measurementUnit,
      packSizes: packSizes,
      packSizeWeight: map['packSizeWeight'] as String?,
      isBulkFood: map['isBulkFood'] ?? false,
      servesCount: map['servesCount'] as int?,
      portionDescription: map['portionDescription'] as String?,
      isKitchenOpen: map['isKitchenOpen'] ?? false,
      preparationTimeMinutes: map['preparationTimeMinutes'] as int?,
      maxCapacity: map['maxCapacity'] as int?,
    );
  }

  ItemList copyWith({
    String? id,
    String? sellerId,
    String? name,
    List<PendingListingItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastUsedAt,
    int? usageCount,
  }) {
    return ItemList(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      usageCount: usageCount ?? this.usageCount,
    );
  }
}

