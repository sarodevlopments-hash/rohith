/// Model for place search results
class PlaceResult {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final String? placeType; // e.g., "restaurant", "landmark", "establishment"
  final double? rating;
  final String? photoReference;

  PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.placeType,
    this.rating,
    this.photoReference,
  });

  @override
  String toString() => address;
}

