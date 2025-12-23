import 'package:hive/hive.dart';

part 'food_category.g.dart';

@HiveType(typeId: 11)
enum FoodCategory {
  @HiveField(0)
  veg,

  @HiveField(1)
  egg,

  @HiveField(2)
  nonVeg,
}

extension FoodCategoryLabel on FoodCategory {
  String get label {
    switch (this) {
      case FoodCategory.veg:
        return "Veg";
      case FoodCategory.egg:
        return "Egg";
      case FoodCategory.nonVeg:
        return "Non-Veg";
    }
  }
}
