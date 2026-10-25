class TouristPlace {
  final String id;
  final String name;
  final String imageUrl;
  final String history;
  final String culture;
  final String address;
  final String province;
  final double? latitude;
  final double? longitude;

  TouristPlace({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.history,
    required this.culture,
    required this.address,
    this.province = '',
    required this.latitude,
    required this.longitude,
  });

  factory TouristPlace.fromJson(Map<String, dynamic> json) {
    return TouristPlace(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      history: json['history']?.toString() ?? '',
      culture: json['culture']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      province: json['province']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
    );
  }
}
