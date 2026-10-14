class FoodCoordinates {
  const FoodCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

String estimatedFoodPriceRange(String restaurantName) {
  final name = restaurantName.toLowerCase();

  if (RegExp(r'cafe|coffee|starbucks|highlands|monkey|partea').hasMatch(name)) {
    return '30.000đ - 120.000đ (ước tính)';
  }

  if (RegExp(
    r'hotel|wine|sushi|bbq|bistro|morico|pizza|dim tu tac|sumo|japanese',
  ).hasMatch(name)) {
    return '120.000đ - 500.000đ (ước tính)';
  }

  return '50.000đ - 180.000đ (ước tính)';
}

FoodCoordinates estimatedFoodCoordinates(
  String restaurantName,
  String address,
) {
  final nameHash = restaurantName.runes.fold<int>(
    0,
    (sum, rune) => (sum * 31 + rune) & 0x7fffffff,
  );
  final district = address.toLowerCase();
  final centers = <String, FoodCoordinates>{
    'quận 1': const FoodCoordinates(10.7756, 106.7019),
    'quận 3': const FoodCoordinates(10.7823, 106.6840),
    'quận 4': const FoodCoordinates(10.7593, 106.7040),
    'quận 5': const FoodCoordinates(10.7540, 106.6630),
    'quận 10': const FoodCoordinates(10.7721, 106.6678),
    'bình thạnh': const FoodCoordinates(10.8038, 106.6967),
    'phú nhuận': const FoodCoordinates(10.7990, 106.6805),
    'tân bình': const FoodCoordinates(10.8015, 106.6525),
    'quận 7': const FoodCoordinates(10.7340, 106.7218),
    'thủ đức': const FoodCoordinates(10.8505, 106.7717),
  };
  final fallbackCenters = centers.values.toList();
  var center = fallbackCenters[nameHash % fallbackCenters.length];

  for (final entry in centers.entries) {
    if (district.contains(entry.key)) {
      center = entry.value;
      break;
    }
  }

  final latitudeOffset = ((nameHash % 81) - 40) / 10000;
  final longitudeOffset = (((nameHash ~/ 81) % 81) - 40) / 10000;

  return FoodCoordinates(
    center.latitude + latitudeOffset,
    center.longitude + longitudeOffset,
  );
}
