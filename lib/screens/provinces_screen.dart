import 'package:hcm_explorer/widgets/app_ui.dart';
import '../models/tourist_place.dart';
import '../services/tourist_place_service.dart';
import '../widgets/app_image.dart';
import 'places_screen.dart';

class ProvinceItem {
  final String name;
  final List<String> searchKeywords;
  final List<String> featuredPlaceKeywords;
  final String region; // 'Bắc', 'Trung', 'Nam'
  final String specialty;
  final String imageUrl;

  ProvinceItem({
    required this.name,
    required this.searchKeywords,
    required this.featuredPlaceKeywords,
    required this.region,
    required this.specialty,
    required this.imageUrl,
  });
}

class ProvincesScreen extends StatefulWidget {
  const ProvincesScreen({super.key});

  @override
  State<ProvincesScreen> createState() => _ProvincesScreenState();
}

class _ProvincesScreenState extends State<ProvincesScreen> with AppLocaleAwareState<ProvincesScreen> {
  String _selectedRegion = 'Tất cả';
  String _searchQuery = '';
  List<TouristPlace> _allPlaces = [];
  bool _isLoadingPlaces = true;
  String? _placesLoadError;

  static const _northImage =
      'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=800';
  static const _centralImage =
      'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?q=80&w=800';
  static const _southImage =
      'https://images.unsplash.com/photo-1583417319070-4a69db38a482?q=80&w=800';

  final List<ProvinceItem> _provinces = [
    ProvinceItem(
        name: 'Hà Nội',
        searchKeywords: ['Hà Nội'],
        featuredPlaceKeywords: [
          'Hồ Hoàn Kiếm',
          'Văn Miếu',
          'Hoàng thành Thăng Long'
        ],
        region: 'Bắc',
        specialty: 'Phở, bún chả',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Cao Bằng',
        searchKeywords: ['Cao Bằng'],
        featuredPlaceKeywords: ['Thác Bản Giốc', 'Pác Bó'],
        region: 'Bắc',
        specialty: 'Bánh cuốn, hạt dẻ',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Tuyên Quang',
        searchKeywords: ['Tuyên Quang', 'Hà Giang'],
        featuredPlaceKeywords: [
          'Cao nguyên đá Đồng Văn',
          'Mã Pí Lèng',
          'Lũng Cú'
        ],
        region: 'Bắc',
        specialty: 'Thắng cố, bánh tam giác mạch',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Lào Cai',
        searchKeywords: ['Lào Cai', 'Yên Bái'],
        featuredPlaceKeywords: ['Fansipan', 'Sa Pa', 'Mù Cang Chải'],
        region: 'Bắc',
        specialty: 'Thắng cố, cá hồi Sa Pa',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Điện Biên',
        searchKeywords: ['Điện Biên'],
        featuredPlaceKeywords: ['Điện Biên Phủ', 'Đồi A1'],
        region: 'Bắc',
        specialty: 'Gà nướng mắc khén',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Lai Châu',
        searchKeywords: ['Lai Châu'],
        featuredPlaceKeywords: ['Ô Quy Hồ', 'Pu Si Lung'],
        region: 'Bắc',
        specialty: 'Thịt trâu gác bếp',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Sơn La',
        searchKeywords: ['Sơn La'],
        featuredPlaceKeywords: ['Mộc Châu', 'thác Dải Yếm'],
        region: 'Bắc',
        specialty: 'Bê chao Mộc Châu',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Thái Nguyên',
        searchKeywords: ['Thái Nguyên', 'Bắc Kạn'],
        featuredPlaceKeywords: ['Hồ Ba Bể', 'Hồ Núi Cốc'],
        region: 'Bắc',
        specialty: 'Chè Tân Cương',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Lạng Sơn',
        searchKeywords: ['Lạng Sơn'],
        featuredPlaceKeywords: ['Mẫu Sơn', 'Động Tam Thanh'],
        region: 'Bắc',
        specialty: 'Vịt quay, khâu nhục',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Quảng Ninh',
        searchKeywords: ['Quảng Ninh'],
        featuredPlaceKeywords: ['Vịnh Hạ Long', 'Yên Tử'],
        region: 'Bắc',
        specialty: 'Chả mực Hạ Long',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Bắc Ninh',
        searchKeywords: ['Bắc Ninh', 'Bắc Giang'],
        featuredPlaceKeywords: ['Chùa Vĩnh Nghiêm', 'Tây Yên Tử', 'Đền Đô'],
        region: 'Bắc',
        specialty: 'Bánh phu thê, dân ca quan họ',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Phú Thọ',
        searchKeywords: ['Phú Thọ', 'Vĩnh Phúc', 'Hòa Bình'],
        featuredPlaceKeywords: ['Đền Hùng', 'Tam Đảo', 'Mai Châu'],
        region: 'Bắc',
        specialty: 'Thịt chua, cá sông Đà',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Hải Phòng',
        searchKeywords: ['Hải Phòng'],
        featuredPlaceKeywords: ['Cát Bà', 'Đồ Sơn'],
        region: 'Bắc',
        specialty: 'Bánh đa cua',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Hưng Yên',
        searchKeywords: ['Hưng Yên', 'Thái Bình'],
        featuredPlaceKeywords: ['Chùa Keo', 'Phố Hiến'],
        region: 'Bắc',
        specialty: 'Nhãn lồng, bánh cáy',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Ninh Bình',
        searchKeywords: ['Ninh Bình', 'Hà Nam', 'Nam Định'],
        featuredPlaceKeywords: ['Tràng An', 'Tam Cốc', 'Bái Đính'],
        region: 'Bắc',
        specialty: 'Cơm cháy, phở bò',
        imageUrl: _northImage),
    ProvinceItem(
        name: 'Thanh Hóa',
        searchKeywords: ['Thanh Hóa'],
        featuredPlaceKeywords: ['Thành nhà Hồ', 'Pù Luông'],
        region: 'Trung',
        specialty: 'Nem chua',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Nghệ An',
        searchKeywords: ['Nghệ An'],
        featuredPlaceKeywords: ['Kim Liên', 'Quê Bác'],
        region: 'Trung',
        specialty: 'Cháo lươn',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Hà Tĩnh',
        searchKeywords: ['Hà Tĩnh'],
        featuredPlaceKeywords: ['Ngã ba Đồng Lộc', 'Kẻ Gỗ'],
        region: 'Trung',
        specialty: 'Kẹo cu đơ',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Quảng Trị',
        searchKeywords: ['Quảng Trị', 'Quảng Bình'],
        featuredPlaceKeywords: ['Phong Nha', 'Kẻ Bàng', 'Vĩnh Mốc'],
        region: 'Trung',
        specialty: 'Cháo bột, bánh khoái',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Huế',
        searchKeywords: ['Huế', 'Thừa Thiên Huế'],
        featuredPlaceKeywords: ['Cố đô Huế', 'Đại Nội', 'Lăng Khải Định'],
        region: 'Trung',
        specialty: 'Bún bò Huế',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Đà Nẵng',
        searchKeywords: ['Đà Nẵng', 'Quảng Nam'],
        featuredPlaceKeywords: ['Bà Nà Hills', 'Phố cổ Hội An', 'Mỹ Sơn'],
        region: 'Trung',
        specialty: 'Mì Quảng, cao lầu',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Quảng Ngãi',
        searchKeywords: ['Quảng Ngãi', 'Kon Tum'],
        featuredPlaceKeywords: ['Lý Sơn', 'Măng Đen'],
        region: 'Trung',
        specialty: 'Don, tỏi Lý Sơn',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Gia Lai',
        searchKeywords: ['Gia Lai', 'Bình Định'],
        featuredPlaceKeywords: ['Biển Quy Nhơn', 'Eo Gió', 'Biển Hồ'],
        region: 'Trung',
        specialty: 'Phở khô, bánh xèo tôm nhảy',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Đắk Lắk',
        searchKeywords: ['Đắk Lắk', 'Phú Yên'],
        featuredPlaceKeywords: [
          'Gành Đá Đĩa',
          'Tháp Nghinh Phong',
          'Thác Dray Nur'
        ],
        region: 'Trung',
        specialty: 'Cà phê, mắt cá ngừ đại dương',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Khánh Hòa',
        searchKeywords: ['Khánh Hòa', 'Ninh Thuận'],
        featuredPlaceKeywords: [
          'Vịnh Nha Trang',
          'Tháp Po Klong Garai',
          'Hang Rái'
        ],
        region: 'Trung',
        specialty: 'Bún chả cá, nho',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'Lâm Đồng',
        searchKeywords: ['Lâm Đồng', 'Đắk Nông', 'Bình Thuận'],
        featuredPlaceKeywords: ['Đà Lạt', 'Mũi Né', 'Tà Đùng'],
        region: 'Trung',
        specialty: 'Bánh xíu mại, thanh long',
        imageUrl: _centralImage),
    ProvinceItem(
        name: 'TP. Hồ Chí Minh',
        searchKeywords: ['Hồ Chí Minh', 'Bình Dương', 'Bà Rịa', 'Vũng Tàu'],
        featuredPlaceKeywords: ['Dinh Độc Lập', 'Landmark 81', 'Bến Bạch Đằng'],
        region: 'Nam',
        specialty: 'Hủ tiếu, bánh mì',
        imageUrl: _southImage),
    ProvinceItem(
        name: 'Đồng Nai',
        searchKeywords: ['Đồng Nai', 'Bình Phước'],
        featuredPlaceKeywords: ['Vườn Quốc gia Cát Tiên', 'Núi Bà Rá'],
        region: 'Nam',
        specialty: 'Gỏi cá Biên Hòa',
        imageUrl: _southImage),
    ProvinceItem(
        name: 'Tây Ninh',
        searchKeywords: ['Tây Ninh', 'Long An'],
        featuredPlaceKeywords: ['Núi Bà Đen', 'Tòa thánh Tây Ninh'],
        region: 'Nam',
        specialty: 'Bánh tráng phơi sương',
        imageUrl: _southImage),
    ProvinceItem(
        name: 'Đồng Tháp',
        searchKeywords: ['Đồng Tháp', 'Tiền Giang'],
        featuredPlaceKeywords: [
          'Tràm Chim',
          'Chùa Vĩnh Tràng',
          'Trại rắn Đồng Tâm'
        ],
        region: 'Nam',
        specialty: 'Hủ tiếu Mỹ Tho, nem Lai Vung',
        imageUrl: _southImage),
    ProvinceItem(
        name: 'Vĩnh Long',
        searchKeywords: ['Vĩnh Long', 'Bến Tre', 'Trà Vinh'],
        featuredPlaceKeywords: ['Cù lao An Bình', 'Ao Bà Om', 'Cồn Phụng'],
        region: 'Nam',
        specialty: 'Kẹo dừa, bánh tét Trà Cuôn',
        imageUrl: _southImage),
    ProvinceItem(
        name: 'Cần Thơ',
        searchKeywords: ['Cần Thơ', 'Sóc Trăng', 'Hậu Giang'],
        featuredPlaceKeywords: [
          'Chợ nổi Cái Răng',
          'Bến Ninh Kiều',
          'Chùa Som Rong'
        ],
        region: 'Nam',
        specialty: 'Lẩu mắm, bánh xèo',
        imageUrl: _southImage),
    ProvinceItem(
        name: 'An Giang',
        searchKeywords: ['An Giang', 'Kiên Giang'],
        featuredPlaceKeywords: ['Phú Quốc', 'Núi Sam', 'Rừng tràm Trà Sư'],
        region: 'Nam',
        specialty: 'Bún cá, nước mắm Phú Quốc',
        imageUrl: _southImage),
    ProvinceItem(
        name: 'Cà Mau',
        searchKeywords: ['Cà Mau', 'Bạc Liêu'],
        featuredPlaceKeywords: ['Mũi Cà Mau', 'Nhà Công tử Bạc Liêu'],
        region: 'Nam',
        specialty: 'Cua Cà Mau, bánh tằm Ngan Dừa',
        imageUrl: _southImage),
  ];

  @override
  void initState() {
    super.initState();
    _fetchPlaces();
  }

  // Gọi API lấy toàn bộ danh sách địa điểm để tính số lượng thực tế
  Future<void> _fetchPlaces() async {
    try {
      final places = await TouristPlaceService()
          .getTouristPlaces()
          .timeout(const Duration(seconds: 10));
      if (mounted) {
        setState(() {
          _allPlaces = places;
          _placesLoadError = null;
          _isLoadingPlaces = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _placesLoadError = error.toString();
          _isLoadingPlaces = false;
        });
      }
    }
  }

  // Loại bỏ dấu tiếng Việt để tìm kiếm chính xác
  String _removeDiacritics(String str) {
    var withDiacritics =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    var withoutDiacritics =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = str.toLowerCase();
    for (int i = 0; i < withDiacritics.length; i++) {
      result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
    }
    return result;
  }

  // Hàm tính số lượng địa điểm thực tế của tỉnh từ Database
  int _getSpotCount(ProvinceItem province) {
    final keywords = province.searchKeywords.map(_removeDiacritics).toList();

    return _allPlaces.where((place) {
      if (place.province.isNotEmpty) {
        final normProvince = _removeDiacritics(place.province);
        return keywords.any(normProvince.contains);
      }

      final normAddress = _removeDiacritics(place.address);
      return keywords.any(normAddress.contains);
    }).length;
  }

  String _getProvinceImage(ProvinceItem province) {
    final featuredKeywords =
        province.featuredPlaceKeywords.map(_removeDiacritics).toList();
    for (final keyword in featuredKeywords) {
      for (final place in _allPlaces) {
        if (_removeDiacritics(place.name).contains(keyword) &&
            place.imageUrl.trim().isNotEmpty) {
          return place.imageUrl;
        }
      }
    }

    final provinceKeywords = province.searchKeywords.map(_removeDiacritics);
    for (final place in _allPlaces) {
      if (place.imageUrl.trim().isEmpty) continue;
      final location = _removeDiacritics(
        place.province.isNotEmpty ? place.province : place.address,
      );
      if (provinceKeywords.any(location.contains)) {
        return place.imageUrl;
      }
    }
    return province.imageUrl;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProvinces = _provinces.where((item) {
      final matchesRegion =
          _selectedRegion == 'Tất cả' || item.region == _selectedRegion;
      final matchesQuery =
          item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.specialty.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesRegion && matchesQuery;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Nền kem VN Guide
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          '34 Tỉnh/Thành',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            tooltip: AppTranslations.translate('Tải lại địa điểm'),
            onPressed: _isLoadingPlaces
                ? null
                : () {
                    setState(() => _isLoadingPlaces = true);
                    _fetchPlaces();
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Ô TÌM KIẾM
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: AppTranslations.translate('Tìm tỉnh thành...'),
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // 2. BỘ LỌC VÙNG MIỀN BẮC - TRUNG - NAM
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: ['Tất cả', 'Bắc', 'Trung', 'Nam'].map((region) {
                final isSelected = _selectedRegion == region;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                        region == 'Tất cả' ? 'Tất cả 34 Tỉnh' : 'Miền $region'),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0F5B49),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _selectedRegion = region),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // 3. DANH SÁCH TỈNH THÀNH VỚI SỐ ĐIỂM THỰC TẾ
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredProvinces.length,
              itemBuilder: (context, index) {
                final item = filteredProvinces[index];
                final dynamicSpotCount = _getSpotCount(item);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AppImage(
                        source: _getProvinceImage(item),
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        fallbackIcon: Icons.location_city,
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87),
                    ),
                    subtitle: Text(
                      _isLoadingPlaces
                          ? 'Đang đếm điểm...'
                          : _placesLoadError != null
                              ? 'Không tải được dữ liệu địa điểm'
                              : '$dynamicSpotCount điểm · ${item.specialty}',
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    trailing: const Icon(Icons.chevron_right,
                        color: Color(0xFFB83B26), size: 24),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlacesScreen(
                            provinceName: item.name,
                            provinceAliases: item.searchKeywords,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
