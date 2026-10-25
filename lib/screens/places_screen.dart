import 'package:hcm_explorer/widgets/app_ui.dart';
import '../models/tourist_place.dart';
import '../services/tourist_place_service.dart';
import '../widgets/app_image.dart';
import '../services/favorites_store.dart';
import '../widgets/favorite_button.dart';
import 'place_detail_screen.dart';

class PlacesScreen extends StatefulWidget {
  final String? provinceName;
  final List<String>? provinceAliases;
  final String? initialSearchQuery;

  const PlacesScreen({
    super.key,
    this.provinceName,
    this.provinceAliases,
    this.initialSearchQuery,
  });

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> with AppLocaleAwareState<PlacesScreen> {
  List<TouristPlace> _allPlaces = [];
  bool _isLoading = true;
  late String _searchQuery = widget.initialSearchQuery ?? '';
  late final TextEditingController _searchController;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchQuery);
    _fetchPlaces();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlaces() async {
    try {
      final provinces = widget.provinceAliases?.isNotEmpty == true
          ? widget.provinceAliases!
          : widget.provinceName == null
              ? <String>[]
              : [widget.provinceName!];
      final places = await TouristPlaceService()
          .getTouristPlaces(provinces: provinces)
          .timeout(const Duration(seconds: 3));
      if (!mounted) return;
      setState(() {
        _allPlaces = places;
        _loadError = null;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _allPlaces = [];
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    // Lọc theo Tỉnh và Từ khóa tìm kiếm
    List<TouristPlace> displayList = _allPlaces.where((place) {
      final normName = _removeDiacritics(place.name);
      final normAddress = _removeDiacritics(place.address);
      final normQuery = _removeDiacritics(_searchQuery);

      bool matchesProvince = true;
      if (widget.provinceName != null && widget.provinceName!.isNotEmpty) {
        final provinceKeywords = (widget.provinceAliases?.isNotEmpty == true
                ? widget.provinceAliases!
                : [widget.provinceName!])
            .map(_removeDiacritics);
        final location = _removeDiacritics(
          place.province.isNotEmpty ? place.province : place.address,
        );
        matchesProvince = provinceKeywords.any(
          location.contains,
        );
      }

      bool matchesSearch = normQuery.isEmpty ||
          normName.contains(normQuery) ||
          normAddress.contains(normQuery);

      return matchesProvince && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Nền kem VN Guide
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(
          widget.provinceName != null && widget.provinceName!.isNotEmpty
              ? 'Danh lam · ${widget.provinceName}'
              : 'Danh lam thắng cảnh',
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // THANH TÌM KIẾM
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: AppTranslations.translate('Tìm di tích, điểm tham quan...'),
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

          // DANH SÁCH ĐỊA ĐIỂM
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Không tải được địa điểm từ máy chủ.'),
                              const SizedBox(height: 8),
                              Text(
                                _loadError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () {
                                  setState(() => _isLoading = true);
                                  _fetchPlaces();
                                },
                                child: const Text('Thử lại'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : displayList.isEmpty
                        ? const Center(
                            child:
                                Text('Chưa có địa điểm trong tỉnh/thành này.'),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: displayList.length,
                            itemBuilder: (context, index) {
                              final place = displayList[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          PlaceDetailScreen(place: place),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.black12),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: AppImage(
                                          source: place.imageUrl,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          fallbackIcon:
                                              Icons.location_city_outlined,
                                          fallbackIconSize: 36,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              place.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.black87,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              place.address.isNotEmpty
                                                  ? place.address
                                                  : 'Việt Nam',
                                              style: const TextStyle(
                                                  color: Colors.black54,
                                                  fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      FavoriteButton(entry: FavoriteEntry.forPlace(place)),
                                    ],
                                  ),
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
