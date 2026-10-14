import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' show parse;
import 'package:puppeteer/puppeteer.dart';
import 'package:backend/utils/food_estimates.dart';
import 'package:backend/utils/openverse_image.dart';

Future<String?> _findChromeExecutable() async {
  final candidates = <String?>[
    Platform.environment['PUPPETEER_EXECUTABLE_PATH'],
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  ];

  for (final candidate in candidates) {
    if (candidate != null &&
        candidate.isNotEmpty &&
        await File(candidate).exists()) {
      return candidate;
    }
  }

  return null;
}

String _readAddress(Element element) {
  Element? current = element;

  for (var depth = 0; depth < 6 && current != null; depth++) {
    final address = current.querySelector(
      '.address, [class*="address"], [itemprop="address"]',
    );
    if (address != null) {
      final text = _normalizeText(address.text);
      if (_isAddress(text)) {
        return text;
      }
    }

    final addressMatch = RegExp(
      r'(?:Địa chỉ|Địa điểm)\s*:?\s*([^\r\n]+)',
      caseSensitive: false,
    ).firstMatch(current.text);
    if (addressMatch != null) {
      final text = _normalizeText(addressMatch.group(1)!);
      if (_isAddress(text)) {
        return text;
      }
    }

    final parent = current.parentNode;
    current = parent is Element ? parent : null;
  }

  return 'TP. Hồ Chí Minh';
}

String _normalizeText(String text) =>
    text.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

bool _isAddress(String text) =>
    text.isNotEmpty &&
    RegExp(
      r'quận|phường|đường|tp\.|thành phố|hồ chí minh',
      caseSensitive: false,
    ).hasMatch(text) &&
    !RegExp(
      r'chi nhánh|đóng góp bình luận|đánh giá về địa điểm',
      caseSensitive: false,
    ).hasMatch(text);

String _addressFromStructuredData(dynamic value) {
  if (value is String && _isAddress(_normalizeText(value))) {
    return _normalizeText(value);
  }
  if (value is! Map<String, dynamic>) {
    return 'TP. Hồ Chí Minh';
  }

  final parts =
      [
            value['streetAddress'],
            value['addressLocality'],
            value['addressRegion'],
            value['addressCountry'] is Map<String, dynamic>
                ? (value['addressCountry'] as Map<String, dynamic>)['name']
                : value['addressCountry'],
          ]
          .whereType<String>()
          .map(_normalizeText)
          .where((part) => part.isNotEmpty)
          .toList();
  final address = _normalizeText(parts.join(', '));
  return _isAddress(address) ? address : 'TP. Hồ Chí Minh';
}

double? _ratingFromStructuredData(dynamic value) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  final rawRating = value['ratingValue'];
  final rating = rawRating is num
      ? rawRating.toDouble()
      : double.tryParse(rawRating?.toString() ?? '');
  if (rating == null || rating < 0) {
    return null;
  }
  final rawMaximum = value['bestRating'];
  final maximum = rawMaximum is num
      ? rawMaximum.toDouble()
      : double.tryParse(rawMaximum?.toString() ?? '') ?? (rating > 5 ? 10 : 5);
  if (maximum <= 0 || rating > maximum) {
    return null;
  }

  return (rating * 5 / maximum).clamp(0, 5).toDouble();
}

({double latitude, double longitude})? _coordinatesFromStructuredData(
  dynamic value,
) {
  if (value is! Map<String, dynamic>) {
    return null;
  }
  final rawLatitude = value['latitude'];
  final rawLongitude = value['longitude'];
  final latitude = rawLatitude is num
      ? rawLatitude.toDouble()
      : double.tryParse(rawLatitude?.toString() ?? '');
  final longitude = rawLongitude is num
      ? rawLongitude.toDouble()
      : double.tryParse(rawLongitude?.toString() ?? '');
  if (latitude == null ||
      longitude == null ||
      latitude < 8 ||
      latitude > 24 ||
      longitude < 102 ||
      longitude > 110) {
    return null;
  }
  return (latitude: latitude, longitude: longitude);
}

double? _ratingFromElement(Element element) {
  Element? current = element;
  for (var depth = 0; depth < 4 && current != null; depth++) {
    final ratingElement = current.querySelector(
      '[itemprop="ratingValue"], [data-rating], [class*="rating"]',
    );
    if (ratingElement != null) {
      final rawRating =
          ratingElement.attributes['content'] ??
          ratingElement.attributes['data-rating'] ??
          ratingElement.attributes['aria-label'] ??
          ratingElement.text;
      final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(rawRating);
      if (match != null) {
        final rating = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (rating != null && rating >= 0 && rating <= 10) {
          return rating > 5 ? rating / 2 : rating;
        }
      }
    }
    final parent = current.parentNode;
    current = parent is Element ? parent : null;
  }
  return null;
}

class _FoodLocation {
  const _FoodLocation(this.name, this.latitude, this.longitude);

  final String name;
  final double latitude;
  final double longitude;
}

Map<String, dynamic> _traditionalDishRecord(String name) {
  final normalizedName = _normalizeText(name);
  final lowerName = normalizedName.toLowerCase();
  final location = switch (true) {
    _ when lowerName.contains('kon plông') || lowerName.contains('konplông') =>
      const _FoodLocation('Kon Plông', 14.7, 108.25),
    _
        when lowerName.contains('tiên yên') ||
            lowerName.contains('hạ long') ||
            lowerName.contains('chả mực') =>
      const _FoodLocation('Quảng Ninh', 20.951, 107.08),
    _ when lowerName.contains('mỹ tho') => const _FoodLocation(
      'Mỹ Tho',
      10.36,
      106.36,
    ),
    _
        when lowerName.contains('khánh hòa') ||
            lowerName.contains('yến sào') ||
            lowerName.contains('nha trang') ||
            lowerName.contains('bánh căn') =>
      const _FoodLocation('Nha Trang', 12.2388, 109.1967),
    _ when lowerName.contains('súp lươn') => const _FoodLocation(
      'Nghệ An',
      18.6796,
      105.6813,
    ),
    _
        when lowerName.contains('thịt lợn') ||
            lowerName.contains('mì quảng') ||
            lowerName.contains('bê thui') =>
      const _FoodLocation('Quảng Nam', 15.5736, 108.474),
    _ when lowerName.contains('lẩu thả') => const _FoodLocation(
      'Phan Thiết',
      10.9289,
      108.1021,
    ),
    _ when lowerName.contains('cao lầu') => const _FoodLocation(
      'Hội An',
      15.8801,
      108.338,
    ),
    _ when lowerName.contains('phở chua') => const _FoodLocation(
      'Lạng Sơn',
      21.8537,
      106.7611,
    ),
    _ when lowerName.contains('dê núi') || lowerName.contains('cơm cháy') =>
      const _FoodLocation('Ninh Bình', 20.2506, 105.9745),
    _ when lowerName.contains('quy nhơn') => const _FoodLocation(
      'Quy Nhơn',
      13.782,
      109.219,
    ),
    _ when lowerName.contains('trảng bàng') => const _FoodLocation(
      'Trảng Bàng',
      11.029,
      106.36,
    ),
    _
        when lowerName.contains('cơm hến') ||
            lowerName.contains('bánh khoái') ||
            lowerName.contains('bánh bèo') =>
      const _FoodLocation('Huế', 16.4637, 107.5909),
    _ when lowerName.contains('chắt chắt') => const _FoodLocation(
      'Quảng Bình',
      17.467,
      106.623,
    ),
    _ when lowerName.contains('cắp nách') => const _FoodLocation(
      'Sa Pa',
      22.3364,
      103.8438,
    ),
    _ when lowerName.contains('trâu khô') => const _FoodLocation(
      'Sơn La',
      21.325,
      103.91,
    ),
    _ when lowerName.contains('cá bống') => const _FoodLocation(
      'Quảng Ngãi',
      15.121,
      108.804,
    ),
    _ when lowerName.contains('bánh đa cua') => const _FoodLocation(
      'Hải Phòng',
      20.8449,
      106.6881,
    ),
    _ when lowerName.contains('bánh khọt') => const _FoodLocation(
      'Vũng Tàu',
      10.346,
      107.0843,
    ),
    _
        when lowerName.contains('cơm tấm') ||
            lowerName.contains('bánh mì') ||
            lowerName.contains('gỏi cuốn') =>
      const _FoodLocation('TP. Hồ Chí Minh', 10.7769, 106.7009),
    _ when lowerName.contains('bánh xèo') => const _FoodLocation(
      'Cần Thơ',
      10.0452,
      105.7469,
    ),
    _ => const _FoodLocation('Hà Nội', 21.0285, 105.8542),
  };
  final priceRange = switch (true) {
    _ when lowerName.contains('yến sào') => '100.000đ - 500.000đ (ước tính)',
    _
        when lowerName.contains('gà nướng') ||
            lowerName.contains('gà tiên yên') ||
            lowerName.contains('dê núi') ||
            lowerName.contains('lợn') ||
            lowerName.contains('bê thui') =>
      '150.000đ - 400.000đ (ước tính)',
    _
        when lowerName.contains('lẩu') ||
            lowerName.contains('chả mực') ||
            lowerName.contains('chả cá') =>
      '100.000đ - 300.000đ (ước tính)',
    _ => '30.000đ - 100.000đ (ước tính)',
  };

  return {
    'food_name': normalizedName,
    'restaurant_name': 'Món ăn truyền thống - ${location.name}',
    'address': '${location.name}, Việt Nam (tọa độ đại diện)',
    'price_range': priceRange,
    'image_url': '',
    'latitude': location.latitude,
    'longitude': location.longitude,
  };
}

List<Map<String, dynamic>> _readTraditionalDishes(Document document) {
  final dishes = <Map<String, dynamic>>[];
  final seenNames = <String>{};
  final openGraphImages = document
      .querySelectorAll('meta[property="og:image"]')
      .map((element) => element.attributes['content'])
      .whereType<String>()
      .where((image) => image.isNotEmpty)
      .toList();

  for (final script in document.querySelectorAll(
    'script[type="application/ld+json"]',
  )) {
    try {
      final data = jsonDecode(script.text);
      if (data is! Map<String, dynamic> || data['@type'] != 'ItemList') {
        continue;
      }

      final entries = data['itemListElement'];
      if (entries is! List) {
        continue;
      }

      for (final entry in entries) {
        final name = switch (entry) {
          String value => value,
          Map<String, dynamic> map =>
            (map['item'] is Map<String, dynamic>
                    ? (map['item'] as Map<String, dynamic>)['name']
                    : map['name'])
                as String?,
          _ => null,
        };
        if (name != null &&
            name.trim().isNotEmpty &&
            seenNames.add(name.trim().toLowerCase())) {
          dishes.add(_traditionalDishRecord(name));
        }
      }
    } on FormatException catch (error) {
      stderr.writeln('⚠️ Bỏ qua JSON-LD không hợp lệ: $error');
    }
  }

  final dishImageOffset = openGraphImages.length >= dishes.length + 1 ? 1 : 0;
  for (var index = 0; index < dishes.length; index++) {
    final imageIndex = index + dishImageOffset;
    if (imageIndex >= openGraphImages.length) {
      break;
    }
    dishes[index]['image_url'] = Uri.parse('https://toplist.vn')
        .resolve(openGraphImages[imageIndex])
        .toString();
  }

  return dishes;
}

String _readImage(Element element) {
  Element? current = element;

  for (var depth = 0; depth < 4 && current != null; depth++) {
    final image = current.querySelector('img');
    var source =
        image?.attributes['data-original'] ??
        image?.attributes['data-lazy-src'] ??
        image?.attributes['data-src'] ??
        image?.attributes['src'];
    if (source == null || source.startsWith('data:')) {
      final srcset =
          image?.attributes['data-srcset'] ?? image?.attributes['srcset'];
      if (srcset != null && srcset.isNotEmpty) {
        source = srcset.split(',').last.trim().split(RegExp(r'\s+')).first;
      }
    }
    if (source != null && source.isNotEmpty) {
      final uri = Uri.parse('https://www.foody.vn').resolve(source);
      final cleanPath = uri.path.replaceFirst(
        RegExp(r'@resize_(?:w\d+|ss\d+x\d+)$'),
        '',
      );
      return uri.replace(path: cleanPath).toString();
    }

    final parent = current.parentNode;
    current = parent is Element ? parent : null;
  }

  return '';
}

String _normalizeImageUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasScheme) {
    return value;
  }
  final cleanPath = uri.path.replaceFirst(
    RegExp(r'@resize_(?:w\d+|ss\d+x\d+)$'),
    '',
  );
  return uri.replace(path: cleanPath).toString();
}

String _foodRecordKey(Map<String, dynamic> record) =>
    '${record['restaurant_name']?.toString().trim().toLowerCase()}|'
    '${record['food_name']?.toString().trim().toLowerCase()}';

void main() async {
  print('🚀 Bắt đầu cào dữ liệu ẩm thực từ Foody.vn và Toplist.vn...');

  final chromePath = await _findChromeExecutable();
  if (chromePath == null) {
    stderr.writeln(
      '❌ Không tìm thấy Chrome/Edge. Cài trình duyệt hoặc đặt '
      'PUPPETEER_EXECUTABLE_PATH trỏ tới file chrome.exe.',
    );
    exitCode = 1;
    return;
  }

  Browser? browser;
  try {
    browser = await puppeteer.launch(
      headless: true,
      executablePath: chromePath,
      args: ['--no-sandbox', '--disable-setuid-sandbox'],
    );
    final page = await browser.newPage();
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36',
    );

    const foodyUrl = 'https://www.foody.vn/ho-chi-minh/dia-diem';
    print('Đang truy cập $foodyUrl ...');
    try {
      await page.goto(
        foodyUrl,
        wait: Until.domContentLoaded,
        timeout: const Duration(seconds: 30),
      );
    } on TimeoutException {
      stderr.writeln(
        '⚠️ Foody chưa báo tải xong; thử đọc nội dung trang đã tải được.',
      );
    }

    final document = parse(await page.content);
    final resultList = <Map<String, dynamic>>[];
    final placesByName = <String, Map<String, dynamic>>{};

    void addPlace({
      required String name,
      String address = 'TP. Hồ Chí Minh',
      String image = '',
      double? rating,
      ({double latitude, double longitude})? coordinates,
    }) {
      final normalizedName = name.trim();
      if (normalizedName.isEmpty) {
        return;
      }

      final nameKey = normalizedName.toLowerCase();
      final estimatedCoordinates = estimatedFoodCoordinates(
        normalizedName,
        address,
      );
      final record = {
        'food_name': 'Ẩm thực đa dạng',
        'restaurant_name': normalizedName,
        'address': address,
        'price_range': estimatedFoodPriceRange(normalizedName),
        'image_url': _normalizeImageUrl(image),
        'latitude': coordinates?.latitude ?? estimatedCoordinates.latitude,
        'longitude': coordinates?.longitude ?? estimatedCoordinates.longitude,
        'rating': rating ?? 0.0,
      };
      final existing = placesByName[nameKey];
      if (existing != null) {
        if ((existing['image_url'] as String? ?? '').isEmpty &&
            (record['image_url'] as String).isNotEmpty) {
          existing['image_url'] = record['image_url'];
        }
        if ((existing['rating'] as num? ?? 0) <= 0 &&
            (record['rating'] as num) > 0) {
          existing['rating'] = record['rating'];
        }
        if ((existing['address'] as String? ?? 'TP. Hồ Chí Minh') ==
                'TP. Hồ Chí Minh' &&
            address != 'TP. Hồ Chí Minh') {
          existing['address'] = address;
          existing['latitude'] = record['latitude'];
          existing['longitude'] = record['longitude'];
        }
        return;
      }
      placesByName[nameKey] = record;
      resultList.add(record);
    }

    for (final script in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      try {
        final data = jsonDecode(script.text);
        if (data is! Map<String, dynamic> || data['@type'] != 'ItemList') {
          continue;
        }

        final entries = data['itemListElement'];
        if (entries is! List) {
          continue;
        }

        for (final entry in entries) {
          if (entry is! Map<String, dynamic>) {
            continue;
          }
          final item = entry['item'];
          final place = item is Map<String, dynamic> ? item : entry;
          final name = place['name'];
          if (name is String) {
            final geo = _coordinatesFromStructuredData(place['geo']);
            final rating = _ratingFromStructuredData(place['aggregateRating']);
            addPlace(
              name: name,
              address: _addressFromStructuredData(place['address']),
              image: place['image'] is String
                  ? _normalizeImageUrl(place['image'] as String)
                  : '',
              rating: rating,
              coordinates: geo,
            );
          }
        }
      } on FormatException catch (error) {
        stderr.writeln('⚠️ Bỏ qua JSON-LD không hợp lệ: $error');
      }
    }

    // Foody currently renders restaurant names in heading links, not an ItemList.
    for (final link in document.querySelectorAll(
      'h2 a, .content-item a.title, .row-item a.title',
    )) {
      final name = link.text.trim();
      if (name.isEmpty) {
        continue;
      }
      addPlace(
        name: name,
        address: _readAddress(link),
        image: _readImage(link),
        rating: _ratingFromElement(link),
      );
    }

    if (resultList.isEmpty) {
      stderr.writeln(
        '⚠️ Không lấy được danh sách quán từ Foody; tiếp tục lấy món '
        'truyền thống từ Toplist.',
      );
    }

    const toplistUrl =
        'https://toplist.vn/top-list/mon-an-truyen-thong-viet-nam-ngon-va-noi-tieng-nhat-30689.htm';
    print('Đang truy cập $toplistUrl ...');
    try {
      await page.goto(
        toplistUrl,
        wait: Until.domContentLoaded,
        timeout: const Duration(seconds: 30),
      );
    } on TimeoutException {
      stderr.writeln(
        '⚠️ Toplist chưa báo tải xong; thử đọc nội dung trang đã tải được.',
      );
    }

    final traditionalDishes = _readTraditionalDishes(parse(await page.content));
    if (traditionalDishes.isEmpty) {
      throw StateError(
        'Không lấy được món ăn từ Toplist. Trang có thể đã đổi cấu trúc '
        'hoặc chặn truy cập; không ghi đè foods.json.',
      );
    }
    resultList.addAll(traditionalDishes);

    if (resultList.isEmpty) {
      throw StateError('Không thu thập được dữ liệu ẩm thực nào.');
    }

    final outputFile = File('assets/data/foods.json');
    if (await outputFile.exists()) {
      final existingData = jsonDecode(await outputFile.readAsString());
      if (existingData is! List) {
        throw const FormatException('foods.json phải chứa một JSON array.');
      }
      final resultByKey = {
        for (final record in resultList) _foodRecordKey(record): record,
      };
      for (final entry in existingData.whereType<Map<String, dynamic>>()) {
        final key = _foodRecordKey(entry);
        final current = resultByKey[key];
        if (current == null) {
          final oldRecord = Map<String, dynamic>.from(entry);
          oldRecord['image_url'] = _normalizeImageUrl(
            oldRecord['image_url']?.toString() ?? '',
          );
          resultList.add(oldRecord);
          resultByKey[key] = oldRecord;
          continue;
        }

        if ((current['image_url'] as String? ?? '').isEmpty) {
          current['image_url'] = _normalizeImageUrl(
            entry['image_url']?.toString() ?? '',
          );
        }
        final oldRating = entry['rating'];
        if ((current['rating'] as num? ?? 0) <= 0 &&
            oldRating is num &&
            oldRating > 0) {
          current['rating'] = oldRating;
        }
        if ((current['address'] as String? ?? 'TP. Hồ Chí Minh') ==
                'TP. Hồ Chí Minh' &&
            (entry['address'] as String? ?? '').isNotEmpty &&
            entry['address'] != 'TP. Hồ Chí Minh') {
          current['address'] = entry['address'];
          current['latitude'] = entry['latitude'];
          current['longitude'] = entry['longitude'];
        }
      }
    }

    for (final record in resultList) {
      record['image_url'] = _normalizeImageUrl(
        record['image_url']?.toString() ?? '',
      );
      final currentImage = record['image_url'] as String;
      final imageHost = Uri.tryParse(currentImage)?.host ?? '';
      if (currentImage.isNotEmpty &&
          imageHost != 'thumb.wikimedia.org' &&
          imageHost != 'down-vn.img.susercontent.com') {
        continue;
      }
      final foodName = record['food_name']?.toString() ?? '';
      final restaurantName = record['restaurant_name']?.toString() ?? '';
      final subject = foodName == 'Ẩm thực đa dạng'
          ? '${restaurantName.replaceFirst(RegExp(r'^Hệ thống\s+', caseSensitive: false), '')} restaurant Vietnam'
          : '$foodName Vietnamese dish';
      final image = await openverseImageFor(subject);
      if (image != null) {
        record['image_url'] = image;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final directory = Directory('assets/data');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(resultList),
    );
    print(
      '✅ Đã lưu ${resultList.length} mục (${traditionalDishes.length} món '
      'truyền thống từ Toplist) vào '
      'assets/data/foods.json.',
    );
  } catch (error, stackTrace) {
    stderr.writeln('❌ Không thể cào dữ liệu ẩm thực: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    await browser?.close();
  }
}
