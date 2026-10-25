import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:hcm_explorer/widgets/app_ui.dart';
import '../widgets/app_image.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/food.dart';
import '../models/tourist_place.dart';
import '../services/food_service.dart';
import '../services/tourist_place_service.dart';
import 'place_detail_screen.dart';
import 'places_screen.dart';
import 'foods_screen.dart';
import 'phrases_screen.dart';
import 'events_screen.dart';
import 'currency_converter_screen.dart';
import 'favorites_screen.dart';
import 'sos_screen.dart';
import 'provinces_screen.dart';
import 'lichtrinh_screen.dart';
import 'profile_screen.dart';
import 'community_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AppLocaleAwareState<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _weather;
  bool _isLoadingWeather = true;
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _searchLoaded = false;
  bool _searchLoadStarted = false;
  List<TouristPlace> _searchPlaces = [];
  List<Food> _searchFoods = [];
  List<Map<String, dynamic>> _searchFestivals = [];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _fetchWeather();
  }

  // Gọi API backend lấy thời tiết thực tế tại TP.HCM (hoặc tọa độ hiện tại)
  Future<void> _fetchWeather() async {
    try {
      final res = await http.get(
        Uri.parse('http://103.82.26.171:8080/api/weather?lat=10.7769&lng=106.7009'),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _weather = jsonDecode(res.body);
            _isLoadingWeather = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingWeather = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    _searchDebounce?.cancel();
    if (value.trim().isEmpty || _searchLoadStarted) return;
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      _loadSearchData,
    );
  }

  Future<void> _loadSearchData() async {
    if (_searchLoadStarted) return;
    _searchLoadStarted = true;

    final results = await Future.wait<Object>([
      _loadPlacesForSearch(),
      _loadFoodsForSearch(),
      _loadFestivalsForSearch(),
    ]);
    if (!mounted) return;
    setState(() {
      _searchPlaces = results[0] as List<TouristPlace>;
      _searchFoods = results[1] as List<Food>;
      _searchFestivals = results[2] as List<Map<String, dynamic>>;
      _searchLoaded = true;
    });
  }

  Future<List<TouristPlace>> _loadPlacesForSearch() async {
    try {
      return await TouristPlaceService()
          .getTouristPlaces()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return <TouristPlace>[];
    }
  }

  Future<List<Food>> _loadFoodsForSearch() async {
    try {
      return await FoodService()
          .getFoods()
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      return <Food>[];
    }
  }

  Future<List<Map<String, dynamic>>> _loadFestivalsForSearch() async {
    try {
      final response = await http
          .get(Uri.parse(ApiConfig.baseUrl + '/api/events'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return <Map<String, dynamic>>[];

      final bundledByName = <String, Map<String, dynamic>>{};
      try {
        final bundled = jsonDecode(
          await rootBundle.loadString('backend/data/lehoi.json'),
        );
        if (bundled is List) {
          for (final item in bundled.whereType<Map>()) {
            final row = Map<String, dynamic>.from(item);
            final key = row['name']?.toString().trim().toLowerCase() ?? '';
            if (key.isNotEmpty) bundledByName[key] = row;
          }
        }
      } catch (_) {
        // Search still works with events returned by the server.
      }

      return decoded.whereType<Map>().map((item) {
        final event = Map<String, dynamic>.from(item);
        final key = event['name']?.toString().trim().toLowerCase() ?? '';
        final fallback = bundledByName[key];
        if (fallback != null &&
            event['image_url']?.toString().trim().isNotEmpty != true) {
          event['image_url'] = fallback['image_url'] ?? '';
        }
        return event;
      }).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  String _normalizeSearchText(String value) {
    var result = value.toLowerCase();
    const groups = <String, String>{
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    for (final entry in groups.entries) {
      for (final rune in entry.value.runes) {
        result = result.replaceAll(String.fromCharCode(rune), entry.key);
      }
    }
    return result;
  }

  bool _matchesSearch(String query, Iterable<String> fields) {
    final normalizedQuery = _normalizeSearchText(query.trim());
    return normalizedQuery.isNotEmpty &&
        fields.any(
          (field) => _normalizeSearchText(field).contains(normalizedQuery),
        );
  }

  Widget _buildSearchResults() {
    if (!_searchLoaded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final query = _searchQuery;
    final places = _searchPlaces
        .where((place) => _matchesSearch(query, [
              place.name,
              place.address,
              place.province,
              place.history,
              place.culture,
            ]))
        .take(6)
        .map((place) => _HomeSearchResult(
              type: AppTranslations.translate('Danh lam'),
              title: place.name,
              subtitle: [place.province, place.address]
                  .where((part) => part.trim().isNotEmpty)
                  .toSet()
                  .join(' · '),
              imageUrl: place.imageUrl,
              icon: Icons.location_on_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PlaceDetailScreen(place: place),
                ),
              ),
            ))
        .toList();

    final foods = _searchFoods
        .where((food) => _matchesSearch(query, [
              food.name,
              food.description,
              food.province,
              food.region,
              food.culturalStory,
            ]))
        .take(6)
        .map((food) => _HomeSearchResult(
              type: AppTranslations.translate('Ẩm thực'),
              title: food.name,
              subtitle: [food.province, food.priceRange]
                  .where((part) => part.trim().isNotEmpty)
                  .join(' · '),
              imageUrl: food.imageUrl,
              icon: Icons.restaurant,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FoodsScreen(initialSearchQuery: food.name),
                ),
              ),
            ))
        .toList();

    final festivals = _searchFestivals
        .where((event) => _matchesSearch(query, [
              event['name']?.toString() ?? '',
              event['location']?.toString() ?? '',
              event['description']?.toString() ?? '',
            ]))
        .take(6)
        .map((event) => _HomeSearchResult(
              type: AppTranslations.translate('Lễ hội'),
              title: event['name']?.toString() ?? '',
              subtitle: event['location']?.toString() ?? '',
              imageUrl: event['image_url']?.toString() ?? '',
              icon: Icons.celebration_outlined,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => FestivalDetailScreen(event: event),
                ),
              ),
            ))
        .toList();

    if (places.isEmpty && foods.isEmpty && festivals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            AppTranslations.translate('Không tìm thấy kết quả phù hợp'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (places.isNotEmpty)
          _buildSearchSection(AppTranslations.translate('Danh lam'), places),
        if (foods.isNotEmpty)
          _buildSearchSection(AppTranslations.translate('Ẩm thực'), foods),
        if (festivals.isNotEmpty)
          _buildSearchSection(AppTranslations.translate('Lễ hội'), festivals),
      ],
    );
  }

  Widget _buildSearchSection(String title, List<_HomeSearchResult> results) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
          child: Text(
            title + ' (' + results.length.toString() + ')',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
        ...results.map(_buildSearchResultCard),
      ],
    );
  }

  Widget _buildSearchResultCard(_HomeSearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8E1D5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: result.onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AppImage(
                  source: result.imageUrl,
                  width: 68,
                  height: 68,
                  fit: BoxFit.cover,
                  fallbackIcon: result.icon,
                  fallbackIconSize: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (result.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        result.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                result.type,
                style: const TextStyle(
                  color: Color(0xFF0F5B49),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Nền kem chuẩn thiết kế VN Guide
      body: _currentIndex == 3
          ? const CommunityScreen()
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. LỜI CHÀO & TÌM KIẾM
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chào bạn', style: TextStyle(color: Colors.black54, fontSize: 14)),
                      SizedBox(height: 2),
                      Text(
                        'Khám phá Việt Nam',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.grey[300],
                    child: const Icon(Icons.person, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Thanh tìm kiếm
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: AppTranslations.translate('Tìm địa điểm, món ăn...'),
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: AppTranslations.translate('Xóa tìm kiếm'),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: const Icon(Icons.close, color: Colors.grey),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. WIDGET THỜI TIẾT (HÌNH 19 - F1)
              if (_searchQuery.trim().isNotEmpty)
                _buildSearchResults()
              else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F5B49), // Màu xanh ngọc sẫm
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _weather != null ? '${_weather!['temperature']}°' : '29°',
                                style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _weather != null ? _weather!['location_name'] : 'TP. Hồ Chí Minh',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _weather != null ? _weather!['description'] : 'NẮNG NHẸ',
                                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${AppTranslations.translate('Độ ẩm: ')}${_weather != null ? _weather!['humidity'] : 72}% • ${AppTranslations.translate('Gió: ')}${_weather != null ? _weather!['wind_speed'] : 12} km/h',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoadingWeather)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    else if (_weather != null && _weather!['icon_url'] != null)
                      Image.network(_weather!['icon_url'], width: 54, height: 54)
                    else
                      const Icon(Icons.wb_sunny, color: Colors.amber, size: 48),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. NÚT DANH MỤC CHÍNH (DL, AT, LH, ĐP)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                 _buildCategoryCard('DL', 'Danh lam', const Color(0xFFB83B26), () {
  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProvincesScreen()));
}),
                  _buildCategoryCard('AT', 'Ẩm thực', const Color(0xFF0F5B49), () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FoodsScreen()));
                  }),
                  _buildCategoryCard('LH', 'Lễ hội', const Color(0xFFB58328), () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EventsScreen()));
                  }),
                  _buildCategoryCard('ĐP', 'Địa phương', const Color(0xFF6E472B), () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PhrasesScreen()));
                  }),
                ],
              ),

              const SizedBox(height: 24),

              // 4. TIỆN ÍCH NHANH
              const Text('Tiện ích nhanh', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildUtilityCard('Tỷ giá', '\$', const Color(0xFF0F5B49), () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()));
                  }),
                  _buildUtilityCard('Từ điển', 'Aa', const Color(0xFFB83B26), () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PhrasesScreen()));
                  }),
                  _buildUtilityCard('Ngoại tuyến', '↓', const Color(0xFF6E472B), () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tính năng lưu ngoại tuyến đang được tải dữ liệu')),
                    );
                  }),
                  _buildUtilityCard('Đã lưu', '★', const Color(0xFFB58328), () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                  }),
                ],
              ),

              const SizedBox(height: 24),

              // 5. MỤC "GẦN BẠN"
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gần bạn', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  TextButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PlacesScreen()));
                    },
                    child: const Text('Xem tất cả', style: TextStyle(color: Color(0xFFB83B26), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildPlaceCard(
                      'Dinh Độc Lập',
                      'Quận 1, TP.HCM',
                      'https://thumb.wikimedia.org/wikipedia/commons/thumb/c/c3/Independence_Palace%2C_Ho_Chi_Minh_City.jpg/1280px-Independence_Palace%2C_Ho_Chi_Minh_City.jpg',
                      const Color(0xFF0F5B49),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PlacesScreen(
                            initialSearchQuery: 'Dinh Độc Lập',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPlaceCard(
                      'Chợ Bến Thành',
                      'Quận 1, TP.HCM',
                      'https://thumb.wikimedia.org/wikipedia/commons/thumb/f/fb/Ch%E1%BB%A3_B%E1%BA%BFn_Th%C3%A0nh_%283505833101%29.jpg/960px-Ch%E1%BB%A3_B%E1%BA%BFn_Th%C3%A0nh_%283505833101%29.jpg',
                      const Color(0xFF6E472B),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PlacesScreen(
                            initialSearchQuery: 'Chợ Bến Thành',
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 80), // Tạo khoảng trống cho Nút SOS
              ],
            ],
          ),
        ),
      ),

      // 6. NÚT SOS NỔI BẬT KHẨN CẤP
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        backgroundColor: const Color(0xFFB83B26),
        icon: const Icon(Icons.sos, color: Colors.white, size: 28),
        label: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SosScreen()));
        },
      ) : null,

      // 7. THANH ĐIỀU HƯỚNG DƯỚI CÙNG (BOTTOM NAVIGATION BAR)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFB83B26),
        unselectedItemColor: Colors.black45,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ProvincesScreen(),
              ),
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const LichTrinhScreen(),
              ),
            ).then((_) {
              if (mounted) setState(() => _currentIndex = 0);
            });
          } else if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ProfileScreen(),
              ),
            ).then((_) {
              if (mounted) setState(() => _currentIndex = 0);
            });
          }
        },
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: AppTranslations.translate('Trang chủ')),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), activeIcon: Icon(Icons.explore), label: AppTranslations.translate('Khám phá')),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), activeIcon: Icon(Icons.map), label: AppTranslations.translate('Lịch trình')),
          BottomNavigationBarItem(icon: Icon(Icons.people_outlined), activeIcon: Icon(Icons.people), label: AppTranslations.translate('Cộng đồng')),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: AppTranslations.translate('Cá nhân')),
        ],
      ),
    );
  }

  // WIDGET CON: Ô DANH MỤC KHÁM PHÁ (DL, AT, LH, ĐP)
  Widget _buildCategoryCard(String code, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              code,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
        ],
      ),
    );
  }

  // WIDGET CON: Ô TIỆN ÍCH NHANH (Tỷ giá, Từ điển...)
  Widget _buildUtilityCard(String label, String symbol, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          children: [
            Text(symbol, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  // WIDGET CON: THẺ ĐỊA ĐIỂM GẦN BẠN
  Widget _buildPlaceCard(
    String title,
    String subtitle,
    String imageUrl,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppImage(
                source: imageUrl,
                fit: BoxFit.cover,
                fallbackIcon: Icons.location_city,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0),
                      color.withValues(alpha: 0.94),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSearchResult {
  const _HomeSearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.icon,
    required this.onTap,
  });

  final String type;
  final String title;
  final String subtitle;
  final String imageUrl;
  final IconData icon;
  final VoidCallback onTap;
}
