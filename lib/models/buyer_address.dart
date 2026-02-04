import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'buyer_address.g.dart';

@HiveType(typeId: 10)
class BuyerAddress extends HiveObject {
  @HiveField(0)
  String id; // Unique address ID

  @HiveField(1)
  String label; // e.g., "Home", "Work", "Office"

  @HiveField(2)
  String fullAddress; // Complete address string

  @HiveField(3)
  String? street;

  @HiveField(4)
  String? city;

  @HiveField(5)
  String? state;

  @HiveField(6)
  String? pincode;

  @HiveField(7)
  double? latitude;

  @HiveField(8)
  double? longitude;

  @HiveField(9)
  bool isDefault; // Default delivery address

  @HiveField(10)
  DateTime createdAt;

  @HiveField(11)
  DateTime? updatedAt;

  BuyerAddress({
    required this.id,
    required this.label,
    required this.fullAddress,
    this.street,
    this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'fullAddress': fullAddress,
      'street': street,
      'city': city,
      'state': state,
      'pincode': pincode,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore map
  factory BuyerAddress.fromMap(Map<String, dynamic> map) {
    DateTime _parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    return BuyerAddress(
      id: map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      fullAddress: map['fullAddress'] as String? ?? '',
      street: map['street'] as String?,
      city: map['city'] as String?,
      state: map['state'] as String?,
      pincode: map['pincode'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      isDefault: map['isDefault'] as bool? ?? false,
      createdAt: _parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? _parseDate(map['updatedAt']) : null,
    );
  }

  BuyerAddress copyWith({
    String? id,
    String? label,
    String? fullAddress,
    String? street,
    String? city,
    String? state,
    String? pincode,
    double? latitude,
    double? longitude,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BuyerAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      fullAddress: fullAddress ?? this.fullAddress,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'BuyerAddress(id: $id, label: $label, address: $fullAddress, isDefault: $isDefault)';
  }
}

