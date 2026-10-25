import 'dart:convert';
import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../models/food.dart';
import '../services/favorites_store.dart';
import '../widgets/favorite_button.dart';
import '../widgets/app_image.dart';

class FoodsScreen extends StatefulWidget {
  final String? initialSearchQuery;

  const FoodsScreen({Key? key, this.initialSearchQuery}) : super(key: key);

  @override
  State<FoodsScreen> createState() => _FoodsScreenState();
}

class _FoodsScreenState extends State<FoodsScreen> with AppLocaleAwareState<FoodsScreen> {
  // 1. Danh mục mặc định (BỎ 'Tất cả', bổ sung 'Đặc sản vùng miền')
  String selectedCategory = 'Món ăn đường phố';
  String selectedRegion = 'Tất cả';
  String searchQuery = '';
  late final TextEditingController _searchController;

  final List<String> categories = [
    'Món ăn đường phố',
    'Di sản ẩm thực',
    'Món ăn ngày Tết',
    'Đặc sản vùng miền'
  ];

  final List<String> regions = ['Tất cả', 'Miền Bắc', 'Miền Trung', 'Miền Nam'];

  List<Food> foodsList = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    searchQuery = widget.initialSearchQuery ?? '';
    _searchController = TextEditingController(text: searchQuery);
    _fetchFoodsFromApi();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFoodsFromApi() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/foods'));

      if (response.statusCode == 200) {
        List<dynamic> jsonList = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          foodsList = jsonList.map((item) => Food.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Không thể tải dữ liệu (Lỗi ${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Lỗi kết nối Server: $e';
        isLoading = false;
      });
    }
  }

  // Hàm chuyển hướng mở Google Maps định vị quán ăn (Đã tối ưu tránh đơ ứng dụng)
  Future<void> _openGoogleMaps(String spotName, String address) async {
    final query = Uri.encodeComponent('$spotName, $address');
    final googleMapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      // 1. Mở trực tiếp bằng ứng dụng Google Maps ngoài (External Application)
      bool launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );

      // 2. Nếu không mở được app ngoài, mở trực tiếp trên tab trình duyệt
      if (!launched) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      // 3. Phương án dự phòng cuối cùng nếu trình duyệt chặn Pop-up
      try {
        await launchUrl(googleMapsUrl, mode: LaunchMode.inAppWebView);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể mở Google Maps: $err')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = foodsList.where((food) {
      bool matchCategory = widget.initialSearchQuery?.trim().isNotEmpty == true ||
          food.category == selectedCategory;
      bool matchRegion = selectedRegion == 'Tất cả' || food.region == selectedRegion;
      bool matchSearch = food.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
          food.province.toLowerCase().contains(searchQuery.toLowerCase());
      return matchCategory && matchRegion && matchSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Ẩm Thực & Văn Hóa Địa Phương', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        backgroundColor: const Color(0xFF8D0B0B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchFoodsFromApi,
          )
        ],
      ),
      body: Column(
        children: [
          // Tìm kiếm
          Container(
            color: const Color(0xFF8D0B0B),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: AppTranslations.translate('Tìm món ăn, tỉnh thành...'),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Tag Danh mục (Không có "Tất cả")
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: categories.map((cat) {
                bool isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF8D0B0B),
                    backgroundColor: Colors.grey[200],
                    onSelected: (_) => setState(() => selectedCategory = cat),
                  ),
                );
              }).toList(),
            ),
          ),

          // Lọc Vùng miền
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: regions.map((reg) {
                bool isSelected = selectedRegion == reg;
                return ChoiceChip(
                  label: Text(reg, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                  selected: isSelected,
                  selectedColor: Colors.orange[800],
                  backgroundColor: Colors.grey[300],
                  onSelected: (_) => setState(() => selectedRegion = reg),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 12),

          // Danh sách món ăn
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF8D0B0B)))
                : errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              onPressed: _fetchFoodsFromApi,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8D0B0B)),
                              child: const Text('Thử lại', style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      )
                    : filteredList.isEmpty
                        ? const Center(child: Text('Không có món ăn thuộc danh mục này'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filteredList.length,
                            itemBuilder: (context, index) {
                              final food = filteredList[index];
                              return _buildFoodCard(food);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFoodCard(Food food) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showFoodDetailBottomSheet(food),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hình ảnh món ăn
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AppImage(
                  source: food.imageUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  fallbackIcon: Icons.fastfood,
                ),
              ),
              const SizedBox(width: 12),

              // Thông tin món
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            food.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF8D0B0B)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(6)),
                          child: Text(food.region, style: TextStyle(fontSize: 10, color: Colors.orange[900], fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      food.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('💵 ${food.priceRange}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
                        Text(AppTranslations.isEnglish ? '${food.spots.length} restaurants >' : '${food.spots.length} quán phục vụ >', style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w500)),
                      ],
                    )
                  ],
                ),
              ),
              FavoriteButton(entry: FavoriteEntry.forFood(food)),
            ],
          ),
        ),
      ),
    );
  }

  void _showFoodDetailBottomSheet(Food food) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, controller) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                controller: controller,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 12),
                  
                  // Ảnh to trong BottomSheet
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AppImage(source: food.imageUrl, height: 180, width: double.infinity, fit: BoxFit.cover, fallbackIcon: Icons.fastfood),
                  ),
                  const SizedBox(height: 12),

                  Text(food.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF8D0B0B))),
                  const SizedBox(height: 4),
                  Text('${AppTranslations.translate('Danh mục: ')}${AppTranslations.translate(food.category)} | ${AppTranslations.translate(food.region)} (${food.province})', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const Divider(height: 24),
                  
                  const Text('📖 Câu chuyện văn hóa địa phương:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(food.culturalStory, style: const TextStyle(fontSize: 14, height: 1.4)),
                  
                  const SizedBox(height: 20),
                  const Text('📍 Quán ăn phục vụ (Bấm để xem định vị Google Maps):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF8D0B0B))),
                  const SizedBox(height: 8),

                  // Danh sách quán ăn có nút bấm mở Google Maps
                  ...food.spots.map((spot) => Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(spot.spotName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('⭐ ${spot.rating}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('🏠 ${spot.address}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text('⏰ ${spot.openHours} • 💰 ${spot.price}', style: const TextStyle(fontSize: 11, color: Colors.green)),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FavoriteButton(
                            entry: FavoriteEntry.forFoodSpot(spot),
                          ),
                          const Icon(
                            Icons.directions,
                            color: Colors.redAccent,
                            size: 28,
                          ),
                        ],
                      ),
                      onTap: () => _openGoogleMaps(spot.spotName, spot.address),
                    ),
                  )).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }
}