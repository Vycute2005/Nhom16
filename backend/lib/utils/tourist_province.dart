const _provinceAliases = <String, List<String>>{
  'An Giang': ['An Giang', 'Kiên Giang'],
  'Bắc Ninh': ['Bắc Ninh', 'Bắc Giang'],
  'Cà Mau': ['Cà Mau', 'Bạc Liêu'],
  'Cao Bằng': ['Cao Bằng'],
  'Đắk Lắk': ['Đắk Lắk', 'Phú Yên'],
  'Điện Biên': ['Điện Biên'],
  'Đồng Nai': ['Đồng Nai', 'Bình Phước'],
  'Đồng Tháp': ['Đồng Tháp', 'Tiền Giang'],
  'Gia Lai': ['Gia Lai', 'Bình Định'],
  'Hà Nội': ['Hà Nội'],
  'Hà Tĩnh': ['Hà Tĩnh'],
  'Hải Phòng': ['Hải Phòng'],
  'Hưng Yên': ['Hưng Yên', 'Thái Bình'],
  'Khánh Hòa': ['Khánh Hòa', 'Ninh Thuận'],
  'Lai Châu': ['Lai Châu'],
  'Lạng Sơn': ['Lạng Sơn'],
  'Lào Cai': ['Lào Cai', 'Yên Bái'],
  'Lâm Đồng': ['Lâm Đồng', 'Đắk Nông', 'Bình Thuận'],
  'Nghệ An': ['Nghệ An'],
  'Ninh Bình': ['Ninh Bình', 'Hà Nam', 'Nam Định'],
  'Phú Thọ': ['Phú Thọ', 'Vĩnh Phúc', 'Hòa Bình'],
  'Quảng Ngãi': ['Quảng Ngãi', 'Kon Tum'],
  'Quảng Ninh': ['Quảng Ninh'],
  'Quảng Trị': ['Quảng Trị', 'Quảng Bình'],
  'Sơn La': ['Sơn La'],
  'Tây Ninh': ['Tây Ninh', 'Long An'],
  'Thái Nguyên': ['Thái Nguyên', 'Bắc Kạn'],
  'Thanh Hóa': ['Thanh Hóa'],
  'Đà Nẵng': ['Đà Nẵng', 'Quảng Nam'],
  'Cần Thơ': ['Cần Thơ', 'Hậu Giang', 'Sóc Trăng'],
  'TP. Hồ Chí Minh': [
    'Hồ Chí Minh',
    'TP. Hồ Chí Minh',
    'Thành phố Hồ Chí Minh',
    'Bình Dương',
    'Bà Rịa',
    'Vũng Tàu',
    'Sài Gòn',
    'Ho Chi Minh City',
    'Saigon',
  ],
  'Huế': ['Huế', 'Thừa Thiên Huế'],
  'Tuyên Quang': ['Tuyên Quang', 'Hà Giang'],
  'Vĩnh Long': ['Vĩnh Long', 'Bến Tre', 'Trà Vinh'],
};

const _placeProvinceOverrides = <String, String>{
  'cao-nguyen-da-dong-van': 'Tuyên Quang',
  'chua-huong': 'Hà Nội',
  'fansipan-sapa': 'Lào Cai',
  'ghenh-da-dia': 'Đắk Lắk',
  'tam-dao': 'Phú Thọ',
  'thanh-nha-ho-tai-thanh-hoa': 'Thanh Hóa',
};

String _normalizeVietnamese(String value) {
  const replacements = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'e': 'éèẻẽẹêếềểễệ',
    'i': 'íìỉĩị',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'u': 'úùủũụưứừửữự',
    'y': 'ýỳỷỹỵ',
    'd': 'đ',
  };
  var normalized = value.toLowerCase();
  for (final entry in replacements.entries) {
    for (final codePoint in entry.value.runes) {
      normalized = normalized.replaceAll(
        String.fromCharCode(codePoint),
        entry.key,
      );
    }
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String? resolveTouristProvince({
  required String name,
  required String address,
  String? province,
}) {
  final normalizedName = _normalizeVietnamese(name);
  for (final entry in _placeProvinceOverrides.entries) {
    if (normalizedName == entry.key.replaceAll('-', ' ')) {
      return entry.value;
    }
  }

  final normalizedProvince = _normalizeVietnamese(province ?? '');
  final normalizedAddress = _normalizeVietnamese(address);
  if (normalizedProvince.isNotEmpty) {
    for (final entry in _provinceAliases.entries) {
      if (entry.value.any(
        (alias) => _normalizeVietnamese(alias) == normalizedProvince,
      )) {
        return entry.key;
      }
    }
  }

  final candidates = [normalizedAddress];

  for (final legacyAliases in [false, true]) {
    for (final entry in _provinceAliases.entries) {
      for (var index = 0; index < entry.value.length; index++) {
        if ((index > 0) != legacyAliases) continue;
        final normalizedAlias = _normalizeVietnamese(entry.value[index]);
        if (candidates.any(
          (candidate) =>
              candidate == normalizedAlias ||
              ' $candidate '.contains(' $normalizedAlias '),
        )) {
          return entry.key;
        }
      }
    }
  }
  return null;
}
