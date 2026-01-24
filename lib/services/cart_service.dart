import 'package:hive/hive.dart';
import '../models/listing.dart';
import '../models/measurement_unit.dart';
import '../models/pack_size.dart';

class CartItemData {
  final String listingId;
  final String sellerId;
  final String sellerName;
  final String name;
  final double price;
  final double? originalPrice;
  final int quantity;
  final String? imagePath;
  final String? measurementUnitLabel;
  final PackSize? selectedPackSize; // Selected pack size for groceries

  CartItemData({
    required this.listingId,
    required this.sellerId,
    required this.sellerName,
    required this.name,
    required this.price,
    required this.quantity,
    this.originalPrice,
    this.imagePath,
    this.measurementUnitLabel,
    this.selectedPackSize,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'listingId': listingId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'name': name,
      'price': price,
      'originalPrice': originalPrice,
      'quantity': quantity,
      'imagePath': imagePath,
      'measurementUnitLabel': measurementUnitLabel,
      'selectedPackQuantity': selectedPackSize?.quantity,
      'selectedPackPrice': selectedPackSize?.price,
      'selectedPackLabel': selectedPackSize?.label,
    };
  }

  factory CartItemData.fromMap(Map map) {
    PackSize? packSize;
    if (map['selectedPackQuantity'] != null && map['selectedPackPrice'] != null) {
      packSize = PackSize(
        quantity: (map['selectedPackQuantity'] as num).toDouble(),
        price: (map['selectedPackPrice'] as num).toDouble(),
        label: map['selectedPackLabel'] as String?,
      );
    }
    return CartItemData(
      listingId: map['listingId'] as String,
      sellerId: map['sellerId'] as String,
      sellerName: map['sellerName'] as String? ?? '',
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
      originalPrice: map['originalPrice'] != null ? (map['originalPrice'] as num).toDouble() : null,
      quantity: map['quantity'] as int,
      imagePath: map['imagePath'] as String?,
      measurementUnitLabel: map['measurementUnitLabel'] as String?,
      selectedPackSize: packSize,
    );
  }

  CartItemData copyWith({int? quantity, PackSize? selectedPackSize}) {
    return CartItemData(
      listingId: listingId,
      sellerId: sellerId,
      sellerName: sellerName,
      name: name,
      price: price,
      quantity: quantity ?? this.quantity,
      originalPrice: originalPrice,
      imagePath: imagePath,
      measurementUnitLabel: measurementUnitLabel,
      selectedPackSize: selectedPackSize ?? this.selectedPackSize,
    );
  }
}

class CartService {
  static Box get _box => Hive.box('cartBox');

  static List<CartItemData> items() {
    return _box.values
        .whereType<Map>()
        .map((m) => CartItemData.fromMap(Map<String, dynamic>.from(m)))
        .toList();
  }

  static String? currentSellerId() {
    if (_box.isEmpty) return null;
    final first = items().first;
    return first.sellerId;
  }

  static double total() {
    return items().fold(0, (sum, item) => sum + item.total);
  }

  static void clear() {
    _box.clear();
  }

  static Future<void> addItem(Listing listing, int qty, {PackSize? packSize}) async {
    final key = listing.key.toString();
    final existingIndex = _box.keys.toList().indexWhere((k) => k.toString() == key);
    
    // Determine price and pack size
    final selectedPack = packSize ?? listing.defaultPackSize;
    final itemPrice = selectedPack?.price ?? listing.price;
    
    if (existingIndex != -1) {
      final existing = CartItemData.fromMap(Map<String, dynamic>.from(_box.get(key)));
      // Only update if pack size matches, otherwise treat as different item
      if (existing.selectedPackSize?.quantity == selectedPack?.quantity &&
          existing.selectedPackSize?.price == selectedPack?.price) {
        final updated = existing.copyWith(quantity: existing.quantity + qty);
        await _box.put(key, updated.toMap());
      } else {
        // Different pack size - add as separate item with modified key
        final newKey = '${key}_${selectedPack?.quantity ?? 0}_${selectedPack?.price ?? 0}';
        final unitLabel = listing.measurementUnit?.shortLabel;
        final item = CartItemData(
          listingId: key, // Keep original listing ID for reference
          sellerId: listing.sellerId,
          sellerName: listing.sellerName,
          name: listing.name,
          price: itemPrice,
          originalPrice: listing.originalPrice,
          quantity: qty,
          imagePath: listing.imagePath,
          measurementUnitLabel: unitLabel,
          selectedPackSize: selectedPack,
        );
        await _box.put(newKey, item.toMap());
      }
    } else {
      final unitLabel = listing.measurementUnit?.shortLabel;
      final item = CartItemData(
        listingId: key,
        sellerId: listing.sellerId,
        sellerName: listing.sellerName,
        name: listing.name,
        price: itemPrice,
        originalPrice: listing.originalPrice,
        quantity: qty,
        imagePath: listing.imagePath,
        measurementUnitLabel: unitLabel,
        selectedPackSize: selectedPack,
      );
      await _box.put(key, item.toMap());
    }
  }

  static Future<void> updateQuantity(String listingId, int qty) async {
    // Try to find the item by listingId (could be original key or modified key for pack sizes)
    String? key;
    for (var k in _box.keys) {
      final map = _box.get(k);
      if (map != null) {
        final item = CartItemData.fromMap(Map<String, dynamic>.from(map));
        if (item.listingId == listingId) {
          key = k.toString();
          break;
        }
      }
    }
    
    if (key == null) return;
    
    final map = _box.get(key);
    if (map == null) return;
    
    if (qty <= 0) {
      await _box.delete(key);
    } else {
      final updated = CartItemData.fromMap(Map<String, dynamic>.from(map)).copyWith(quantity: qty);
      await _box.put(key, updated.toMap());
    }
  }

  static Future<void> removeItem(String listingId) async {
    // Find and remove the item by listingId
    String? keyToRemove;
    for (var k in _box.keys) {
      final map = _box.get(k);
      if (map != null) {
        final item = CartItemData.fromMap(Map<String, dynamic>.from(map));
        if (item.listingId == listingId) {
          keyToRemove = k.toString();
          break;
        }
      }
    }
    
    if (keyToRemove != null) {
      await _box.delete(keyToRemove);
    }
  }
}

