enum FoodCategory {
  veg,
  egg,
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
