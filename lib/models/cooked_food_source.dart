import 'package:hive/hive.dart';

part 'cooked_food_source.g.dart';


@HiveType(typeId: 5)
enum CookedFoodSource {
  @HiveField(0)
  home,

  @HiveField(1)
  restaurant,

  @HiveField(2)
  event,
}

extension CookedFoodSourceLabel on CookedFoodSource {
  String get label {
    switch (this) {
      case CookedFoodSource.home:
        return "Home Made";
      case CookedFoodSource.restaurant:
        return "Restaurant";
      case CookedFoodSource.event:
        return "Event";
    }
  }
}
