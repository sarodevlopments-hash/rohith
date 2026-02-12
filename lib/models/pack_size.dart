import 'package:hive/hive.dart';

part 'pack_size.g.dart';

@HiveType(typeId: 15)
class PackSize extends HiveObject {
  @HiveField(0)
  final double quantity; // e.g., 5.0 for 5kg, 0.25 for 250gm

  @HiveField(1)
  final double price; // e.g., 100.0 for ₹100

  @HiveField(2)
  final String? label; // Optional label like "5kg Pack", "250gm Pack"

  @HiveField(3)
  final int stock; // Number of packs available for this size

  PackSize({
    required this.quantity,
    required this.price,
    this.label,
    this.stock = 0,
  });

  // Helper method to generate label from quantity and unit
  String getDisplayLabel(String unitShortLabel) {
    if (label != null && label!.isNotEmpty) {
      return label!;
    }
    return '$quantity $unitShortLabel';
  }
}

