import 'package:hive/hive.dart';

part 'size_color_combination.g.dart';

@HiveType(typeId: 19)
class SizeColorCombination extends HiveObject {
  @HiveField(0)
  final String size; // e.g., "S", "M", "L", "XL"

  @HiveField(1)
  final List<String> availableColors; // Colors available for this size

  SizeColorCombination({
    required this.size,
    required this.availableColors,
  });
}

