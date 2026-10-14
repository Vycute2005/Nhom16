import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' show parse;
import 'package:backend/utils/openverse_image.dart';

String _normalizePlaceName(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .trim()
    .replaceAll(RegExp(r'\s+'), ' ');

String _placeImageSearch(String name) {
  final aliases = {
    'dinh-doc-lap': 'Reunification Palace Saigon',
    'nha-tho-duc-ba': 'Notre Dame Cathedral Saigon',
    'cho-ben-thanh': 'Ben Thanh Market Ho Chi Minh City',
    'buu-dien-thanh-pho': 'Saigon Central Post Office',
    'cu-chi-tunnels': 'Cu Chi Tunnels Vietnam',
    'vuon-tao-dan': 'Tao Dan Park Ho Chi Minh City',
    'bao-tang-chung-tich-chien-tranh': 'War Remnants Museum Saigon',
    'khu-du-lich-thao-cam-vien': 'Saigon Zoo Botanical Gardens',
    'pho-di-bo-nguyen-hue': 'Nguyen Hue Walking Street Saigon',
    'nha-hat-thanh-pho-ho-chi-minh': 'Ho Chi Minh City Opera House',
    'toa-nha-bitexco-financial-tower': 'Bitexco Financial Tower Saigon',
    'landmark-81': 'Landmark 81 Ho Chi Minh City',
    'bao-tang-my-thuat-thanh-pho-ho-chi-minh':
        'Ho Chi Minh City Fine Arts Museum',
    'bao-tang-thanh-pho-ho-chi-minh': 'Ho Chi Minh City Museum',
    'nha-tho-tan-dinh': 'Tan Dinh Church Saigon',
    'chua-vinh-nghiem': 'Vinh Nghiem Pagoda Saigon',
    'chua-buu-long': 'Buu Long Pagoda Saigon',
    'cong-vien-van-hoa-dam-sen': 'Dam Sen Park Saigon',
    'khu-du-lich-suoi-tien': 'Suoi Tien Theme Park Saigon',
    'pho-tay-bui-vien': 'Bui Vien Walking Street Saigon',
    'ben-bach-dang': 'Bach Dang Wharf Saigon',
    'bao-tang-ho-chi-minh-ben-nha-rong': 'Nha Rong Wharf Ho Chi Minh Museum',
    'chua-huong': 'Perfume Pagoda Vietnam',
    'tam-coc-bich-dong-ninh-binh': 'Tam Coc Bich Dong Vietnam',
    'tam-dao': 'Tam Dao Vietnam',
    'thanh-dia-my-son': 'My Son Sanctuary Vietnam',
    'mui-ne': 'Mui Ne Vietnam',
    'vuon-quoc-gia-cat-tien': 'Cat Tien National Park Vietnam',
    'khu-du-tru-sinh-quyen-rung-ngap-man-can-gio':
        'Can Gio Mangrove Biosphere Reserve Vietnam',
    'khu-di-tich-hoang-thanh-thang-long': 'Imperial Citadel of Thang Long',
    'thanh-nha-ho-tai-thanh-hoa': 'Ho Citadel Thanh Hoa Vietnam',
    'quan-the-danh-thang-trang-an-ninh-binh': 'Trang An Landscape Complex',
    'quan-the-di-tich-co-do-hue': 'Imperial City Hue Vietnam',
    'cong-vien-dia-chat-dak-nong': 'Dak Nong UNESCO Global Geopark Vietnam',
    'dao-phu-quoc': 'Phu Quoc Island Vietnam',
  };
  return aliases[_placeId(name)] ?? '$name Vietnam landmark';
}

String _placeId(String name) {
  const replacements = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'e': 'éèẻẽẹêếềểễệ',
    'i': 'íìỉĩị',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'u': 'úùủũụưứừửữự',
    'y': 'ýỳỷỹỵ',
    'd': 'đ',
  };
  var normalized = name.toLowerCase();
  for (final entry in replacements.entries) {
    for (final codePoint in entry.value.runes) {
      normalized = normalized.replaceAll(
        String.fromCharCode(codePoint),
        entry.key,
      );
    }
  }
  return normalized
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
}

String _imageSource(Element? image) {
  if (image == null) {
    return '';
  }
  for (final attribute in [
    'data-lazy-src',
    'data-src',
    'data-original',
    'src',
  ]) {
    final value = image.attributes[attribute]?.trim();
    if (value != null && value.isNotEmpty && !value.startsWith('data:')) {
      return value;
    }
  }
  for (final attribute in ['data-lazy-srcset', 'data-srcset', 'srcset']) {
    final value = image.attributes[attribute]?.trim();
    if (value != null && value.isNotEmpty) {
      final url = value.split(',').first.trim().split(RegExp(r'\s+')).first;
      if (url.isNotEmpty && !url.startsWith('data:')) {
        return url;
      }
    }
  }
  return '';
}

Map<String, dynamic> _appPlace(Map<String, dynamic> place) {
  final name = (place['name'] as String? ?? '').trim();
  final rawLatitude = place['latitude'];
  final rawLongitude = place['longitude'];
  return {
    'id': (place['id'] as String?)?.trim().isNotEmpty == true
        ? place['id']
        : _placeId(name),
    'name': name,
    'image_url': place['image_url'] is String
        ? place['image_url']
        : place['image'] is String
        ? place['image']
        : '',
    'history': place['history'] ?? place['description'] ?? '',
    'culture': place['culture'] ?? place['type'] ?? '',
    'address': place['address'] ?? '',
    'latitude': rawLatitude is num ? rawLatitude : 0.0,
    'longitude': rawLongitude is num ? rawLongitude : 0.0,
  };
}

String _addressFromStructuredData(dynamic value) {
  if (value is String) {
    return value.trim();
  }
  if (value is! Map<String, dynamic>) {
    return '';
  }
  return [
    value['streetAddress'],
    value['addressLocality'],
    value['addressRegion'],
    value['addressCountry'] is Map<String, dynamic>
        ? (value['addressCountry'] as Map<String, dynamic>)['name']
        : value['addressCountry'],
  ]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .join(', ');
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

Future<Map<String, dynamic>?> _geocode(
  HttpClient client,
  String placeName,
  String articleText,
) async {
  final queryNames = <String>{placeName};
  final commaParts = placeName.split(',').map((part) => part.trim()).toList();
  queryNames.addAll(commaParts.reversed);
  final localityPattern = RegExp(
    r'(?:tỉnh|thành phố|huyện|thị xã|xã|phường|quận)\s+'
    r'([\p{L}]+(?:\s+[\p{L}]+){0,2})',
    caseSensitive: false,
    unicode: true,
  );
  for (final match in localityPattern.allMatches(articleText)) {
    final locality = match.group(1)?.trim();
    if (locality != null && locality.isNotEmpty) {
      queryNames.add('$placeName, $locality');
    }
  }
  final words = placeName.split(RegExp(r'\s+'));
  for (var count = words.length; count >= 2; count--) {
    queryNames.add(words.skip(words.length - count).join(' '));
  }

  for (final queryName in queryNames) {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'format': 'jsonv2',
      'limit': '1',
      'q': '$queryName, Vietnam',
    });
    final request = await client.getUrl(uri);
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'HCMExplorer/1.0 (tourism data crawler)',
    );
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      stderr.writeln(
        '⚠️ Geocoding "$queryName" thất bại: HTTP ${response.statusCode}.',
      );
      await response.drain<void>();
      await Future<void>.delayed(const Duration(seconds: 1));
      continue;
    }

    final decoded = jsonDecode(await response.transform(utf8.decoder).join());
    await Future<void>.delayed(const Duration(seconds: 1));
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      continue;
    }
    final result = decoded.first as Map;
    final category = result['category']?.toString();
    if (category != null &&
        !{
          'natural',
          'tourism',
          'historic',
          'boundary',
          'place',
          'leisure',
          'waterway',
          'mountain',
          'landuse',
          'man_made',
        }.contains(category)) {
      continue;
    }
    final latitude = double.tryParse(result['lat']?.toString() ?? '');
    final longitude = double.tryParse(result['lon']?.toString() ?? '');
    if (latitude == null || longitude == null) {
      continue;
    }

    return {
      'address': result['display_name']?.toString() ?? '$queryName, Vietnam',
      'latitude': latitude,
      'longitude': longitude,
    };
  }
  return null;
}

Future<List<Map<String, dynamic>>> _crawlBlueDiamond(Document document) async {
  final content =
      document.querySelector('.entry-content') ??
      document.querySelector('article') ??
      document.body;
  if (content == null) {
    return [];
  }

  final headings = content.querySelectorAll('h2');
  final client = HttpClient();
  final places = <Map<String, dynamic>>[];
  try {
    for (var index = 0; index < headings.length; index++) {
      final heading = headings[index];
      final headingText = heading.text.trim();
      if (!RegExp(r'^\d+\.\s*').hasMatch(headingText)) {
        continue;
      }
      final name = headingText.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim();
      final cleanName = name.replaceFirst(RegExp(r':.*$'), '').trim();
      final paragraphs = <String>[];
      var imageUrl = '';
      Element? sibling = heading.nextElementSibling;
      while (sibling != null &&
          !(sibling.localName == 'h2' &&
              RegExp(r'^\d+\.\s*').hasMatch(sibling.text.trim()))) {
        if (sibling.localName == 'p') {
          final text = sibling.text.trim();
          if (text.isNotEmpty) {
            paragraphs.add(text);
          }
        }
        if (imageUrl.isEmpty) {
          imageUrl = _imageSource(sibling.querySelector('img'));
        }
        sibling = sibling.nextElementSibling;
      }

      if (name.isEmpty || paragraphs.isEmpty) {
        continue;
      }

      final geocoded = await _geocode(client, cleanName, paragraphs.join(' '));
      if (geocoded == null) {
        stderr.writeln(
          '⚠️ Bỏ qua "$cleanName": không lấy được tọa độ từ OpenStreetMap.',
        );
        continue;
      }

      final image = imageUrl.isEmpty
          ? await openverseImageFor(_placeImageSearch(cleanName))
          : Uri.parse('https://bluediamondretreat.com')
                .resolve(imageUrl)
                .toString();
      places.add({
        'id': _placeId(cleanName),
        'name': cleanName,
        'image_url': image ?? '',
        'history': paragraphs.first,
        'culture': paragraphs.skip(1).join('\n\n'),
        ...geocoded,
      });
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  } finally {
    client.close();
  }
  return places;
}

List<Map<String, dynamic>> defaultPlaces() {
  return [
    {
      'name': 'Dinh Độc Lập',
      'address': 'Thành phố Hồ Chí Minh',
      'description': 'Di tích lịch sử nổi tiếng, biểu tượng của TP.HCM.',
      'image': '',
      'type': 'Di tích lịch sử',
      'latitude': 10.7769,
      'longitude': 106.6953,
    },
    {
      'name': 'Nhà thờ Đức Bà',
      'address': 'Thành phố Hồ Chí Minh',
      'description': 'Nhà thờ mang phong cách kiến trúc phương Tây và là điểm du lịch thu hút.',
      'image': '',
      'type': 'Nhà thờ',
      'latitude': 10.7797,
      'longitude': 106.6992,
    },
    {
      'name': 'Chợ Bến Thành',
      'address': 'Thành phố Hồ Chí Minh',
      'description':
          'Chợ truyền thống nổi tiếng với ẩm thực và văn hóa TP.HCM.',
      'image': '',
      'type': 'Chợ',
      'latitude': 10.772,
      'longitude': 106.698,
    },
    {
      'name': 'Bưu điện Thành phố',
      'address': 'Thành phố Hồ Chí Minh',
      'description': 'Công trình kiến trúc cổ điển nổi tiếng của thành phố.',
      'image': '',
      'type': 'Công trình kiến trúc',
      'latitude': 10.7791,
      'longitude': 106.6992,
    },
    {
      'name': 'Củ Chi Tunnels',
      'address': 'Thành phố Hồ Chí Minh',
      'description':
          'Khu di tích lịch sử và một điểm tham quan hấp dẫn gần TP.HCM.',
      'image': '',
      'type': 'Di tích lịch sử',
      'latitude': 11.2415,
      'longitude': 106.4186,
    },
    {
      'name': 'Vườn Tao Đàn',
      'address': 'Thành phố Hồ Chí Minh',
      'description':
          'Khu công viên xanh với không gian thư giãn ở trung tâm thành phố.',
      'image': '',
      'type': 'Công viên',
      'latitude': 10.7825,
      'longitude': 106.7005,
    },
    {
      'name': 'Bảo tàng Chứng tích chiến tranh',
      'address': 'Thành phố Hồ Chí Minh',
      'description':
          'Bảo tàng lịch sử phản ánh những sự kiện của chiến tranh Việt Nam.',
      'image': '',
      'type': 'Bảo tàng',
      'latitude': 10.7790,
      'longitude': 106.6900,
    },
    {
      'name': 'Khu du lịch Thảo Cầm Viên',
      'address': 'Thành phố Hồ Chí Minh',
      'description': 'Một điểm tham quan thú vị cho gia đình và du khách.',
      'image': '',
      'type': 'Khu du lịch',
      'latitude': 10.7878,
      'longitude': 106.7121,
    },
    {
      'name': 'Phố đi bộ Nguyễn Huệ',
      'address': 'Đường Nguyễn Huệ, Quận 1, Thành phố Hồ Chí Minh',
      'description': 'Không gian đi bộ trung tâm thành phố, nổi bật với quảng trường, đài phun nước và các hoạt động ngoài trời.',
      'image': '',
      'type': 'Phố đi bộ',
      'latitude': 10.7741,
      'longitude': 106.7031,
    },
    {
      'name': 'Nhà hát Thành phố Hồ Chí Minh',
      'address': 'Đường Đồng Khởi, Quận 1, Thành phố Hồ Chí Minh',
      'description': 'Công trình kiến trúc Pháp cổ điển, đồng thời là địa điểm biểu diễn nghệ thuật của thành phố.',
      'image': '',
      'type': 'Công trình kiến trúc',
      'latitude': 10.7769,
      'longitude': 106.7031,
    },
    {
      'name': 'Tòa nhà Bitexco Financial Tower',
      'address': 'Đường Hải Triều, Quận 1, Thành phố Hồ Chí Minh',
      'description': 'Tòa nhà biểu tượng với đài quan sát Saigon Skydeck nhìn ra trung tâm thành phố.',
      'image': '',
      'type': 'Công trình kiến trúc',
      'latitude': 10.7717,
      'longitude': 106.7042,
    },
    {
      'name': 'Landmark 81',
      'address':
          'Khu đô thị Vinhomes Central Park, Bình Thạnh, Thành phố Hồ Chí Minh',
      'description':
          'Tòa nhà cao tầng nổi bật với khu mua sắm, ẩm thực và đài quan sát.',
      'image': '',
      'type': 'Khu vui chơi / mua sắm',
      'latitude': 10.7951,
      'longitude': 106.7218,
    },
    {
      'name': 'Bảo tàng Mỹ thuật Thành phố Hồ Chí Minh',
      'address': 'Đường Phó Đức Chính, Quận 1, Thành phố Hồ Chí Minh',
      'description': 'Bảo tàng nghệ thuật trong một biệt thự cổ, trưng bày mỹ thuật Việt Nam qua nhiều thời kỳ.',
      'image': '',
      'type': 'Bảo tàng',
      'latitude': 10.7684,
      'longitude': 106.6992,
    },
    {
      'name': 'Bảo tàng Thành phố Hồ Chí Minh',
      'address': 'Đường Lý Tự Trọng, Quận 1, Thành phố Hồ Chí Minh',
      'description': 'Bảo tàng giới thiệu lịch sử, văn hóa và quá trình phát triển của thành phố.',
      'image': '',
      'type': 'Bảo tàng',
      'latitude': 10.7767,
      'longitude': 106.6994,
    },
    {
      'name': 'Nhà thờ Tân Định',
      'address': 'Đường Hai Bà Trưng, Quận 3, Thành phố Hồ Chí Minh',
      'description': 'Nhà thờ có mặt tiền màu hồng đặc trưng, là một trong những công trình kiến trúc nổi bật của thành phố.',
      'image': '',
      'type': 'Nhà thờ',
      'latitude': 10.7902,
      'longitude': 106.6917,
    },
    {
      'name': 'Chùa Vĩnh Nghiêm',
      'address': 'Đường Nam Kỳ Khởi Nghĩa, Quận 3, Thành phố Hồ Chí Minh',
      'description': 'Ngôi chùa lớn với kiến trúc truyền thống Việt Nam và tháp đá nhiều tầng.',
      'image': '',
      'type': 'Chùa',
      'latitude': 10.7892,
      'longitude': 106.6848,
    },
    {
      'name': 'Chùa Bửu Long',
      'address': 'Thành phố Thủ Đức, Thành phố Hồ Chí Minh',
      'description': 'Ngôi chùa có kiến trúc chịu ảnh hưởng Phật giáo Nam tông, nằm trong không gian yên tĩnh gần sông Đồng Nai.',
      'image': '',
      'type': 'Chùa',
      'latitude': 10.8442,
      'longitude': 106.7874,
    },
    {
      'name': 'Công viên văn hóa Đầm Sen',
      'address': 'Đường Hòa Bình, Quận 11, Thành phố Hồ Chí Minh',
      'description': 'Khu vui chơi giải trí với công viên nước, trò chơi và các hoạt động phù hợp cho gia đình.',
      'image': '',
      'type': 'Khu vui chơi',
      'latitude': 10.7756,
      'longitude': 106.6358,
    },
    {
      'name': 'Khu du lịch Suối Tiên',
      'address': 'Xa lộ Hà Nội, Thành phố Thủ Đức, Thành phố Hồ Chí Minh',
      'description': 'Công viên giải trí theo chủ đề văn hóa dân gian với nhiều trò chơi và khu tham quan.',
      'image': '',
      'type': 'Khu vui chơi',
      'latitude': 10.8677,
      'longitude': 106.8024,
    },
    {
      'name': 'Phố Tây Bùi Viện',
      'address': 'Đường Bùi Viện, Quận 1, Thành phố Hồ Chí Minh',
      'description':
          'Khu phố sôi động với nhiều quán ăn, cà phê và hoạt động về đêm.',
      'image': '',
      'type': 'Phố du lịch',
      'latitude': 10.7677,
      'longitude': 106.6931,
    },
    {
      'name': 'Bến Bạch Đằng',
      'address': 'Đường Tôn Đức Thắng, Quận 1, Thành phố Hồ Chí Minh',
      'description': 'Không gian ven sông Sài Gòn có công viên, bến tàu và tầm nhìn về trung tâm thành phố.',
      'image': '',
      'type': 'Công viên / bến tàu',
      'latitude': 10.7726,
      'longitude': 106.7061,
    },
    {
      'name': 'Bảo tàng Hồ Chí Minh - Bến Nhà Rồng',
      'address': 'Đường Nguyễn Tất Thành, Quận 4, Thành phố Hồ Chí Minh',
      'description': 'Di tích lịch sử bên sông Sài Gòn, nơi trưng bày tư liệu về cuộc đời và sự nghiệp của Chủ tịch Hồ Chí Minh.',
      'image': '',
      'type': 'Bảo tàng / di tích lịch sử',
      'latitude': 10.7688,
      'longitude': 106.7061,
    },
  ];
}

Future<String?> _findChromeExecutable() async {
  final candidates = <String?>[
    Platform.environment['PUPPETEER_EXECUTABLE_PATH'],
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe',
    'C:\\Program Files\\Chromium\\Application\\chrome.exe',
    'C:\\Program Files (x86)\\Chromium\\Application\\chrome.exe',
    'C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe',
    'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
  ];

  for (final candidate in candidates) {
    if (candidate == null || candidate.isEmpty) {
      continue;
    }

    final file = File(candidate);
    if (await file.exists()) {
      return candidate;
    }
  }

  return null;
}

void main() async {
  print('🚀 Bắt đầu cào dữ liệu...');

  final chromePath = await _findChromeExecutable();
  if (chromePath == null) {
    stderr.writeln(
      '❌ Không tìm thấy Chrome/Chromium trên máy. Hãy cài Google Chrome hoặc Edge trước khi chạy scraper.\n'
      'Hoặc thiết lập biến môi trường PUPPETEER_EXECUTABLE_PATH cho file chrome.exe.',
    );
    exitCode = 1;
    return;
  }

  print('🔎 Dùng trình duyệt: $chromePath');

  late final Browser browser;
  try {
    browser = await puppeteer.launch(
      headless: true,
      executablePath: chromePath,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
      ],
    );
  } catch (e, st) {
    stderr.writeln('❌ Không thể khởi động trình duyệt: $e');
    stderr.writeln(st);
    exitCode = 1;
    return;
  }

  try {
    final page = await browser.newPage();

    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    final targetUrl =
        'https://www.tripadvisor.com.vn/Attractions-g293925-Activities-a_allAttractions.true-Ho_Chi_Minh_City.html';

    final tripAdvisorPlaces = <Map<String, dynamic>>[];

    try {
      await page.goto(
        targetUrl,
        wait: Until.domContentLoaded,
        timeout: const Duration(seconds: 25),
      );

      final content = await page.content;
      final document = parse(content);
      final jsonLdScripts = document.querySelectorAll(
        'script[type="application/ld+json"]',
      );
      print('📦 Tìm thấy ${jsonLdScripts.length} script JSON-LD.');

      for (var script in jsonLdScripts) {
        try {
          final dynamic data = jsonDecode(script.text);
          if (data is Map<String, dynamic> && data['@type'] == 'ItemList') {
            final itemList = data['itemListElement'] as List?;
            if (itemList != null) {
              for (var item in itemList) {
                if (item is! Map<String, dynamic>) {
                  continue;
                }
                final place = item['item'] is Map<String, dynamic>
                    ? item['item'] as Map<String, dynamic>
                    : item;
                final name = place['name'];
                final address = _addressFromStructuredData(place['address']);
                final coordinates = _coordinatesFromStructuredData(
                  place['geo'],
                );
                if (name is String &&
                    name.trim().isNotEmpty &&
                    address.isNotEmpty &&
                    coordinates != null) {
                  tripAdvisorPlaces.add({
                    'name': name.trim(),
                    'address': address,
                    'description': place['description'] is String
                        ? place['description']
                        : 'Điểm tham quan nổi tiếng tại TP.HCM',
                    'image': place['image'] is String ? place['image'] : '',
                    'type': 'Di tích / Bảo tàng',
                    'latitude': coordinates.latitude,
                    'longitude': coordinates.longitude,
                  });
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      print('⚠️ TripAdvisor chặn bot hoặc timeout. Dùng dữ liệu dự phòng.');
      print('Chi tiết: $e');
    }

    if (tripAdvisorPlaces.isEmpty) {
      print('⚠️ Không có dữ liệu nào được parse. Dùng dữ liệu mặc định.');
      tripAdvisorPlaces.addAll(defaultPlaces());
    }

    const blueDiamondUrl =
        'https://bluediamondretreat.com/danh-lam-thang-canh-viet-nam-noi-tieng/';
    print('🌐 Đang cào danh thắng từ $blueDiamondUrl ...');
    try {
      await page.goto(
        blueDiamondUrl,
        wait: Until.domContentLoaded,
        timeout: const Duration(seconds: 45),
      );
    } on TimeoutException {
      stderr.writeln(
        '⚠️ Blue Diamond chưa báo tải xong; đọc nội dung đã tải được.',
      );
    }
    final blueDiamondPlaces = await _crawlBlueDiamond(
      parse(await page.content),
    );
    if (blueDiamondPlaces.isEmpty) {
      throw StateError(
        'Không lấy được danh sách danh thắng từ Blue Diamond Retreat. '
        'Không ghi đè places.json.',
      );
    }
    print('📍 Đã cào được ${blueDiamondPlaces.length} địa danh từ bài viết.');

    final directory = Directory('assets/data');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final outputFile = File('assets/data/places.json');
    final placesByName = <String, Map<String, dynamic>>{};
    if (await outputFile.exists()) {
      final existing = jsonDecode(await outputFile.readAsString());
      if (existing is! List) {
        throw const FormatException('places.json phải chứa một JSON array.');
      }
      for (final entry in existing.whereType<Map<String, dynamic>>()) {
        final place = _appPlace(entry);
        final key = _normalizePlaceName(place['name'] as String);
        if (key.isNotEmpty) {
          placesByName[key] = place;
        }
      }
    }

    for (final entry in tripAdvisorPlaces) {
      final place = _appPlace(entry);
      final key = _normalizePlaceName(place['name'] as String);
      if (key.isNotEmpty) {
        placesByName[key] = place;
      }
    }
    for (final place in blueDiamondPlaces) {
      placesByName[_normalizePlaceName(place['name'] as String)] = place;
    }

    final resultList = placesByName.values.toList();
    for (final place in resultList) {
      final imageUrl = place['image_url'] as String? ?? '';
      final imageHost = Uri.tryParse(imageUrl)?.host ?? '';
      if (imageUrl.isNotEmpty && imageHost != 'thumb.wikimedia.org') {
        continue;
      }
      final name = place['name'] as String? ?? '';
      final image = await openverseImageFor(_placeImageSearch(name));
      if (image != null) {
        place['image_url'] = image;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    await outputFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(resultList),
    );

    print(
      '✅ Đã lưu ${resultList.length} địa điểm ('
      '${blueDiamondPlaces.length} từ Blue Diamond Retreat) vào '
      'assets/data/places.json!',
    );
  } finally {
    await browser.close();
  }
}
