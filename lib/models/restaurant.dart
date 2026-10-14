class Restaurant {
  final String id;
  final String name;
  final String address;
  final String foodId;
  final double latitude;
  final double longitude;
  final String imageUrl;
  final double rating;
  final String openingHours;
  final bool openingHoursIsEstimate;
  final bool imageIsIllustrative;

  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required this.foodId,
    required this.latitude,
    required this.longitude,
    required this.imageUrl,
    required this.rating,
    this.openingHours = '',
    this.openingHoursIsEstimate = false,
    this.imageIsIllustrative = false,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'].toString(),
      name: json['name'].toString(),
      address: json['address']?.toString() ?? '',
      foodId: json['food_id']?.toString() ?? '',
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      imageUrl: json['image_url']?.toString() ?? '',
      rating: double.tryParse(json['rating']?.toString() ?? '') ?? 0,
      openingHours: json['opening_hours']?.toString() ?? '',
      openingHoursIsEstimate:
          json['opening_hours_source']?.toString() == 'estimated',
      imageIsIllustrative: _jsonBool(json['image_is_illustrative']),
    );
  }

  static bool _jsonBool(dynamic value) {
    return value == true || value == 1 || value?.toString() == '1';
  }
}
