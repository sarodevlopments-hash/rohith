import 'package:hive/hive.dart';

part 'measurement_unit.g.dart';

@HiveType(typeId: 6)
enum MeasurementUnit {
  @HiveField(0)
  kilograms,

  @HiveField(1)
  grams,

  @HiveField(2)
  liters,

  @HiveField(3)
  pieces, // For items that don't use weight/volume
}

extension MeasurementUnitExtension on MeasurementUnit {
  String get label {
    switch (this) {
      case MeasurementUnit.kilograms:
        return 'Kilograms (kg)';
      case MeasurementUnit.grams:
        return 'Grams (g)';
      case MeasurementUnit.liters:
        return 'Liters (L)';
      case MeasurementUnit.pieces:
        return 'Pieces';
    }
  }

  String get shortLabel {
    switch (this) {
      case MeasurementUnit.kilograms:
        return 'kg';
      case MeasurementUnit.grams:
        return 'g';
      case MeasurementUnit.liters:
        return 'L';
      case MeasurementUnit.pieces:
        return 'pcs';
    }
  }
}

