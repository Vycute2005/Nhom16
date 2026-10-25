class FoodSpot {
  final int id;
  final String spotName;
  final String address;
  final String price;
  final String rating;
  final String openHours;

  FoodSpot({
    required this.id,
    required this.spotName,
    required this.address,
    required this.price,
    required this.rating,
    required this.openHours,
  });

  factory FoodSpot.fromJson(Map<String, dynamic> json) {
    return FoodSpot(
      // Ép kiểu an toàn: chấp nhận cả kiểu int lẫn kiểu String ("1")
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      spotName: json['spot_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '4.5/5',
      openHours: json['open_hours']?.toString() ?? '06:00 - 22:00',
    );
  }
}

class Food {
  final int id;
  final String category;
  final String region;
  final String province;
  final String name;
  final String description;
  final String culturalStory;
  final String priceRange;
  final String imageUrl;
  final List<FoodSpot> spots;

  Food({
    required this.id,
    required this.category,
    required this.region,
    required this.province,
    required this.name,
    required this.description,
    required this.culturalStory,
    required this.priceRange,
    required this.imageUrl,
    required this.spots,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    var spotsJson = json['spots'] as List? ?? [];
    List<FoodSpot> spotList =
        spotsJson.map((s) => FoodSpot.fromJson(s)).toList();
    final foodName = json['name']?.toString() ?? '';
    final sourceImageUrl = json['image_url']?.toString() ??
        'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600';

    return Food(
      // Ép kiểu an toàn: nếu id là "1" (String) thì tự chuyển thành 1 (int)
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      category: json['category']?.toString() ?? 'Món ăn đường phố',
      region: json['region']?.toString() ?? 'Miền Nam',
      province: json['province']?.toString() ?? 'TP. Hồ Chí Minh',
      name: foodName,
      description: json['description']?.toString() ?? '',
      culturalStory: json['cultural_story']?.toString() ?? '',
      priceRange: json['price_range']?.toString() ?? '30.000 - 80.000 VNĐ',
      imageUrl: _foodImageFor(foodName, sourceImageUrl),
      spots: spotList,
    );
  }
}
String _foodImageFor(String name, String fallback) {
  const withDiacritics =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const withoutDiacritics =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  var normalized = name.toLowerCase();
  for (var index = 0; index < withDiacritics.length; index++) {
    normalized = normalized.replaceAll(
      withDiacritics[index],
      withoutDiacritics[index],
    );
  }

  const imageByFood = <String, String>{
    'banh khot': 'assets/images/foods/banh-khot-vung-tau.jpg',
    'bun dau': 'assets/images/foods/bun-dau-mam-tom.jpg',
    'com tam': 'assets/images/foods/com-tam-sai-gon.jpg',
    'banh mi': 'assets/images/foods/banh-mi-sai-gon.jpg',
    'banh pia': 'https://www.huongnghiepaau.com/wp-content/uploads/2018/07/ad8de5425148aa32777950338f4d11f6.jpg',
    'keo dua': 'https://galatourist.com/pic/blog/images/keodua.png',
    'lau mam': 'https://luhanhvietnam.com.vn/du-lich/vnt_upload/news/05_2021/lau-mam-ca-mau-min.jpg',
    'tre binh dinh': 'https://file.hstatic.net/200000735203/article/tre-binh-dinh_9e6715d9d5b940a883bf7ad7e2d36d16.jpg',
    'banh can': 'https://topnhatrang.com.vn/uploads/2024/02/26/banh-can-co-lan_033121058.jpg',
    'cha muc': 'https://dulichvietnam.com.vn/vnt_upload/news/06_2024/banh_cuon_cha_muc_ha_long_6.jpg',
    'com lang vong': 'https://s-aicmscdn.vietnamhoinhap.vn/vnhn-media/20/10/9/com-lang-vong.jpg',
    'pho bo': 'https://dynamic-media-cdn.tripadvisor.com/media/photo-o/32/94/9f/7d/caption.jpg?h=800&s=1&w=800',
    'banh tet': 'https://catba.tours/wp-content/uploads/2022/11/banh-tet.jpg',
  };
  for (final entry in imageByFood.entries) {
    if (normalized.contains(entry.key)) return entry.value;
  }
  return fallback;
}
