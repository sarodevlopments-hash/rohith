import 'package:hive/hive.dart';

part 'clothing_category.g.dart';

@HiveType(typeId: 18)
enum ClothingCategory {
  @HiveField(0)
  men,

  @HiveField(1)
  women,

  @HiveField(2)
  baby,

  @HiveField(3)
  boy,

  @HiveField(4)
  girl,

  @HiveField(5)
  unisex,
}

extension ClothingCategoryLabel on ClothingCategory {
  String get label {
    switch (this) {
      case ClothingCategory.men:
        return "Men";
      case ClothingCategory.women:
        return "Women";
      case ClothingCategory.baby:
        return "Baby";
      case ClothingCategory.boy:
        return "Boy";
      case ClothingCategory.girl:
        return "Girl";
      case ClothingCategory.unisex:
        return "Unisex";
    }
  }

  String get icon {
    switch (this) {
      case ClothingCategory.men:
        return "👔";
      case ClothingCategory.women:
        return "👗";
      case ClothingCategory.baby:
        return "👶";
      case ClothingCategory.boy:
        return "👦";
      case ClothingCategory.girl:
        return "👧";
      case ClothingCategory.unisex:
        return "👕";
    }
  }
}

