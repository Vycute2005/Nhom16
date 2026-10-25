import 'dart:convert';
import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../../services/upload_service.dart';
import '../../widgets/app_image.dart';

import '../account_access_screen.dart';

const Color _green = Color(0xFF176B5B);
const Color _red = Color(0xFFC6422D);
const Color _cream = Color(0xFFFAF7F2);
const Color _line = Color(0xFFE8DED0);
const Color _sidebarColor = Color(0xFF202B26);

const _vietnamProvinceOptions = <String>[
  'Hà Nội',
  'Cao Bằng',
  'Tuyên Quang',
  'Lào Cai',
  'Điện Biên',
  'Lai Châu',
  'Sơn La',
  'Thái Nguyên',
  'Lạng Sơn',
  'Quảng Ninh',
  'Bắc Ninh',
  'Phú Thọ',
  'Hải Phòng',
  'Hưng Yên',
  'Ninh Bình',
  'Thanh Hóa',
  'Nghệ An',
  'Hà Tĩnh',
  'Quảng Trị',
  'Huế',
  'Đà Nẵng',
  'Quảng Ngãi',
  'Gia Lai',
  'Đắk Lắk',
  'Khánh Hòa',
  'Lâm Đồng',
  'TP. Hồ Chí Minh',
  'Đồng Nai',
  'Tây Ninh',
  'Đồng Tháp',
  'Vĩnh Long',
  'Cần Thơ',
  'An Giang',
  'Cà Mau',
];

const _foodRegionOptions = <String>['Miền Bắc', 'Miền Trung', 'Miền Nam'];

InputDecoration _adminInputDecoration(String label, {Widget? suffixIcon}) {
  final radius = BorderRadius.circular(12);
  return InputDecoration(
    labelText: AppTranslations.translate(label),
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: radius),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: const BorderSide(color: _green, width: 1.5),
    ),
  );
}

String _formatDateForApi(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatDateForDisplay(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.token, required this.adminName});

  final String token;
  final String adminName;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

enum _AdminSection { overview, places, foods, events, itineraries, dialects, cadao, moderation, users }

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with AppLocaleAwareState<AdminDashboardScreen> {
  _AdminSection _section = _AdminSection.overview;
  String _search = '';
  bool _loadingRecords = false;
  bool _loadingUsers = false;
  bool _loadingModeration = false;
  String? _usersLoadError;
  String? _moderationLoadError;

  final List<_AdminRecord> _places = [
    _AdminRecord(title: 'Dinh Độc Lập', detail: 'Di tích lịch sử', area: 'TP. Hồ Chí Minh', status: 'Đang hiển thị'),
    _AdminRecord(title: 'Phố cổ Hội An', detail: 'Di sản văn hóa', area: 'Quảng Nam', status: 'Đang hiển thị'),
    _AdminRecord(title: 'Đại Nội Huế', detail: 'Di tích lịch sử', area: 'Thừa Thiên Huế', status: 'Đang hiển thị'),
  ];
  final List<_AdminRecord> _foods = [
    _AdminRecord(title: 'Phở', detail: 'Món ăn truyền thống', area: 'Miền Bắc', status: 'Đang hiển thị'),
    _AdminRecord(title: 'Bún bò Huế', detail: 'Món nước', area: 'Miền Trung', status: 'Đang hiển thị'),
    _AdminRecord(title: 'Cơm tấm', detail: 'Món ăn địa phương', area: 'TP. Hồ Chí Minh', status: 'Đang hiển thị'),
  ];
  final List<_AdminRecord> _events = [
    _AdminRecord(title: 'Lễ hội Áo dài', detail: 'Lễ hội văn hóa', area: 'TP. Hồ Chí Minh', status: 'Bản nháp'),
    _AdminRecord(title: 'Festival Huế', detail: 'Sự kiện văn hóa', area: 'Huế', status: 'Đang hiển thị'),
  ];
  final List<_AdminRecord> _itineraries = [
    _AdminRecord(title: 'Hà Nội 3 ngày 2 đêm', detail: '3 ngày', area: 'Hà Nội', status: 'Đang hiển thị'),
    _AdminRecord(title: 'Di sản miền Trung', detail: '4 ngày 3 đêm', area: 'Huế – Đà Nẵng – Hội An', status: 'Đang hiển thị'),
  ];
  final List<_AdminRecord> _dialects = [
    _AdminRecord(title: 'Mô', detail: 'Ở đâu', area: 'Miền Trung', status: 'Đang hiển thị'),
    _AdminRecord(title: 'Hổng', detail: 'Không', area: 'Miền Nam', status: 'Đang hiển thị'),
  ];
  final List<_AdminRecord> _cadao = [];
  final List<_ModerationRecord> _moderation = [];
  final List<_AdminUser> _users = [];

  String get _sectionTitle => switch (_section) {
        _AdminSection.overview => 'Tổng quan',
        _AdminSection.places => 'Quản lý địa điểm',
        _AdminSection.foods => 'Quản lý ẩm thực',
        _AdminSection.events => 'Sự kiện & lễ hội',
        _AdminSection.itineraries => 'Lịch trình gợi ý',
        _AdminSection.dialects => 'Tiếng địa phương',
        _AdminSection.cadao => 'Ca dao, tục ngữ',
        _AdminSection.moderation => 'Kiểm duyệt nội dung',
        _AdminSection.users => 'Quản lý người dùng',
      };

  IconData _sectionIcon(_AdminSection section) => switch (section) {
        _AdminSection.overview => Icons.grid_view_rounded,
        _AdminSection.places => Icons.place_outlined,
        _AdminSection.foods => Icons.restaurant_outlined,
        _AdminSection.events => Icons.event_outlined,
        _AdminSection.itineraries => Icons.route_outlined,
        _AdminSection.dialects => Icons.record_voice_over_outlined,
        _AdminSection.cadao => Icons.menu_book_outlined,
        _AdminSection.moderation => Icons.fact_check_outlined,
        _AdminSection.users => Icons.people_outline,
      };

  List<_AdminRecord> _recordsForCurrentSection() => switch (_section) {
        _AdminSection.places => _places,
        _AdminSection.foods => _foods,
        _AdminSection.events => _events,
        _AdminSection.itineraries => _itineraries,
        _AdminSection.dialects => _dialects,
        _AdminSection.cadao => _cadao,
        _ => <_AdminRecord>[],
      };

  String get _recordLabel => switch (_section) {
        _AdminSection.places => 'địa điểm',
        _AdminSection.foods => 'món ăn',
        _AdminSection.events => 'sự kiện',
        _AdminSection.itineraries => 'lịch trình',
        _AdminSection.dialects => 'từ địa phương',
        _AdminSection.cadao => 'câu ca dao, tục ngữ',
        _ => 'nội dung',
      };

  bool _managed(_AdminSection s) => s == _AdminSection.places ||
      s == _AdminSection.foods || s == _AdminSection.dialects ||
      s == _AdminSection.events || s == _AdminSection.cadao;
  String _path(_AdminSection s) => switch(s) {
    _AdminSection.places => '/api/tourist-places',
    _AdminSection.foods => '/api/foods',
    _AdminSection.events => '/api/events',
    _AdminSection.dialects => '/api/phrases',
    _AdminSection.cadao => '/api/cadao',
    _ => '',
  };
  Map<String,String> _fields(_AdminSection s) => switch(s) {
    _AdminSection.places => {'name':'T\u00ean \u0111\u1ecba \u0111i\u1ec3m','image_url':'URL \u1ea3nh','history':'L\u1ecbch s\u1eed','culture':'V\u0103n h\u00f3a','address':'\u0110\u1ecba ch\u1ec9','province':'T\u1ec9nh th\u00e0nh','latitude':'V\u0129 \u0111\u1ed9','longitude':'Kinh \u0111\u1ed9'},
    _AdminSection.foods => {'category':'Danh m\u1ee5c','region':'V\u00f9ng mi\u1ec1n','province':'T\u1ec9nh th\u00e0nh','name':'T\u00ean m\u00f3n','description':'M\u00f4 t\u1ea3','cultural_story':'C\u00e2u chuy\u1ec7n v\u0103n h\u00f3a','price_range':'Kho\u1ea3ng gi\u00e1','image_url':'URL \u1ea3nh'},
    _AdminSection.events => {'name':'T\u00ean s\u1ef1 ki\u1ec7n','event_date':'Ngày bắt đầu','event_end_date':'Ngày kết thúc','location':'\u0110\u1ecba đi\u1ec3m','highlights':'\u0110i\u1ec3m n\u1ed5i b\u1eadt','travel_info':'Th\u00f4ng tin đi l\u1ea1i'},
    _AdminSection.dialects => {'category':'Danh m\u1ee5c','region':'V\u00f9ng mi\u1ec1n','word':'T\u1eeb \u0111\u1ecba ph\u01b0\u01a1ng'},
    _AdminSection.cadao => {'type':'Loại nội dung','category':'Chủ đề','content':'Ca dao / tục ngữ','meaning':'Giải thích'},
    _ => <String,String>{},
  };
  void _selectSection(_AdminSection section, {required bool closeDrawer}) {
    setState(() { _section = section; _search = ''; });
    if (_managed(section)) _loadRecords(section);
    if (section == _AdminSection.users) _loadUsers();
    if (section == _AdminSection.moderation) _loadModeration();
    if (closeDrawer && Navigator.of(context).canPop()) Navigator.of(context).pop();
  }
  Future<Map<String, String>> _festivalImagesByName() async {
    try {
      final decoded = jsonDecode(
        await rootBundle.loadString('backend/data/lehoi.json'),
      );
      if (decoded is! List) return const {};
      final images = <String, String>{};
      for (final raw in decoded.whereType<Map>()) {
        final event = Map<String, dynamic>.from(raw);
        final name = (event['name'] ?? '').toString().trim().toLowerCase();
        final imageUrl = (event['image_url'] ?? '').toString().trim();
        if (name.isNotEmpty && imageUrl.isNotEmpty) {
          images[name] = imageUrl;
        }
      }
      return images;
    } catch (_) {
      return const {};
    }
  }

  Future<void> _loadRecords(_AdminSection section) async {
    setState(() => _loadingRecords = true);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}${_path(section)}'));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
      final rows = jsonDecode(utf8.decode(response.bodyBytes)) as List;
      final eventImages = section == _AdminSection.events
          ? await _festivalImagesByName()
          : const <String, String>{};
      final records = rows.map((raw) {
        final data = Map<String,dynamic>.from(raw as Map);
        final place = section == _AdminSection.places;
        final food = section == _AdminSection.foods;
        final event = section == _AdminSection.events;
        final folkSaying = section == _AdminSection.cadao;
        if (event && (data['image_url']?.toString().trim().isNotEmpty != true)) {
          final name = (data['name'] ?? '').toString().trim().toLowerCase();
          final imageUrl = eventImages[name];
          if (imageUrl != null) data['image_url'] = imageUrl;
        }
        final dialectTitle = [
          data['north_word'],
          data['central_word'],
          data['south_word'],
        ].firstWhere(
          (value) => value != null && value.toString().trim().isNotEmpty,
          orElse: () => '',
        );
        final title = folkSaying
            ? data['content']
            : place || food || event
                ? data['name']
                : dialectTitle;
        return _AdminRecord(id: data['id']?.toString(),
          title: (title ?? '').toString(),
          detail: folkSaying
              ? [data['type'], data['category']]
                  .where((value) => value != null && value.toString().isNotEmpty)
                  .join(' · ')
              : event
              ? [data['time_period'], data['location']].where((value) => value != null).join(' / ')
              : place
                  ? (data['culture'] ?? '').toString()
                  : food
                      ? (data['description'] ?? '').toString()
                      : [data['north_word'], data['central_word'], data['south_word']]
                          .where((value) => value != null && value.toString().isNotEmpty)
                          .join(' / '),
          area: (data[folkSaying ? 'category' : place ? 'province' : food ? 'region' : event ? 'location' : 'category'] ?? '').toString(),
          status: '\u0110ang hi\u1ec3n th\u1ecb', data: data);
      }).toList();
      if (!mounted) return;
      setState(() {
        if (section == _AdminSection.places) { _places..clear()..addAll(records); }
        if (section == _AdminSection.foods) { _foods..clear()..addAll(records); }
        if (section == _AdminSection.dialects) { _dialects..clear()..addAll(records); }
        if (section == _AdminSection.cadao) { _cadao..clear()..addAll(records); }
        if (section == _AdminSection.events) { _events..clear()..addAll(records); }
        _loadingRecords = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRecords = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kh\u00f4ng t\u1ea3i \u0111\u01b0\u1ee3c d\u1eef li\u1ec7u: $e')));
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersLoadError = null;
      _users.clear();
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/users'),
        headers: {'authorization': 'Bearer ${widget.token}'},
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map || decoded['users'] is! List) {
        throw const FormatException('Invalid users response');
      }
      final users = (decoded['users'] as List).whereType<Map>().map((raw) {
        final data = Map<String, dynamic>.from(raw);
        final active = data['is_active'];
        return _AdminUser(
          id: (data['id'] ?? '').toString(),
          username: (data['username'] ?? '').toString(),
          email: (data['email'] ?? '').toString(),
          role: (data['role'] ?? 'user').toString(),
          locked: active == false || active.toString() == '0',
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _users.addAll(users);
        _loadingUsers = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingUsers = false;
        _usersLoadError = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kh\u00f4ng t\u1ea3i \u0111\u01b0\u1ee3c ng\u01b0\u1eddi d\u00f9ng: $error')),
      );
    }
  }

  Future<void> _loadModeration() async {
    setState(() {
      _loadingModeration = true;
      _moderationLoadError = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/moderation'),
        headers: {'authorization': 'Bearer ${widget.token}'},
      );
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 || decoded is! Map || decoded['records'] is! List) {
        throw Exception(decoded is Map ? decoded['message'] : 'HTTP ${response.statusCode}');
      }
      final records = (decoded['records'] as List).whereType<Map>().map((raw) {
        final data = Map<String, dynamic>.from(raw);
        return _ModerationRecord(
          id: (data['id'] ?? '').toString(),
          type: (data['type'] ?? '').toString(),
          title: (data['title'] ?? '').toString(),
          content: (data['content'] ?? '').toString(),
          author: (data['author'] ?? 'Người dùng').toString(),
          rating: int.tryParse((data['rating'] ?? '').toString()),
          createdAt: (data['createdAt'] ?? '').toString(),
        );
      }).toList();
      if (!mounted) return;
      setState(() {
        _moderation
          ..clear()
          ..addAll(records);
        _loadingModeration = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingModeration = false;
        _moderationLoadError = error.toString();
      });
    }
  }

  Future<void> _moderate(_ModerationRecord item, String action) async {
    try {
      final response = await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/api/admin/moderation/${Uri.encodeComponent(item.type)}/${Uri.encodeComponent(item.id)}',
        ),
        headers: {
          'authorization': 'Bearer ${widget.token}',
          'content-type': 'application/json',
        },
        body: jsonEncode({'action': action}),
      );
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(decoded is Map ? decoded['message'] : 'HTTP ${response.statusCode}');
      }
      await _loadModeration();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(action == 'keep' ? 'Đã giữ lại nội dung.' : 'Đã tắt nội dung.'),
        ));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không cập nhật được nội dung: $error')),
      );
    }
  }

  Future<void> _setUserLocked(_AdminUser user, bool locked) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/users/${Uri.encodeComponent(user.id)}/status'),
        headers: {
          'authorization': 'Bearer ${widget.token}',
          'content-type': 'application/json',
        },
        body: jsonEncode({'isActive': !locked}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}');
      }
      if (!mounted) return;
      setState(() => user.locked = locked);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kh\u00f4ng c\u1eadp nh\u1eadt \u0111\u01b0\u1ee3c t\u00e0i kho\u1ea3n: $error')),
      );
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất quản trị?'),
        content: const Text('Bà có chắc muốn kết thúc phiên quản trị hiện tại không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Ở lại')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Đăng xuất')),
        ],
      ),
    );
    if (shouldLogout != true || !mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const AccountAccessScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        if (isWide) {
          return Scaffold(
            backgroundColor: _cream,
            body: Row(
              children: [
                SizedBox(width: 196, child: _sidebar(closeDrawer: false)),
                Expanded(child: _pageBody(isWide: true)),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: _cream,
          drawer: Drawer(width: 270, child: _sidebar(closeDrawer: true)),
          appBar: AppBar(
            backgroundColor: _cream,
            elevation: 0,
            title: Text(_sectionTitle, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
            iconTheme: const IconThemeData(color: _green),
          ),
          body: _pageBody(isWide: false),
        );
      },
    );
  }

  Widget _sidebar({required bool closeDrawer}) {
    final entries = <(_AdminSection, String)>[
      (_AdminSection.overview, 'Tổng quan'),
      (_AdminSection.places, 'Quản lý địa điểm'),
      (_AdminSection.foods, 'Quản lý ẩm thực'),
      (_AdminSection.events, 'Sự kiện & lễ hội'),
      (_AdminSection.itineraries, 'Lịch trình gợi ý'),
      (_AdminSection.dialects, 'Tiếng địa phương'),
      (_AdminSection.cadao, 'Ca dao, tục ngữ'),
      (_AdminSection.moderation, 'Kiểm duyệt'),
      (_AdminSection.users, 'Người dùng'),
    ];

    return Container(
      color: _sidebarColor,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(17, 22, 12, 15),
              child: Text(
                'VN Guide Admin',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: entries.map((entry) {
                  final selected = _section == entry.$1;
                  return SizedBox(
                    height: 38,
                    child: ListTile(
                      dense: true,
                      visualDensity: const VisualDensity(vertical: -2),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 9),
                      selected: selected,
                      selectedTileColor: Colors.transparent,
                      title: Text(
                        entry.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : const Color(0xFFD4DDD8),
                          fontSize: 13.5,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                      onTap: () =>
                          _selectSection(entry.$1, closeDrawer: closeDrawer),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 8, 12, 17),
              child: InkWell(
                onTap: _logout,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 7),
                  child: Text(
                    'Đăng xuất',
                    style: TextStyle(color: Color(0xFFD4DDD8), fontSize: 13.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pageBody({required bool isWide}) {
    // Desktop: giống bố cục bản thiết kế, không thêm thanh tiêu đề ngang.
    // Mobile/tablet hẹp: AppBar được đặt ở Scaffold bên ngoài.
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: switch (_section) {
        _AdminSection.overview => _buildOverview(),
        _AdminSection.places ||
        _AdminSection.foods ||
        _AdminSection.events ||
        _AdminSection.itineraries ||
        _AdminSection.dialects ||
        _AdminSection.cadao => _buildManagePage(),
        _AdminSection.moderation => _buildModerationPage(),
        _AdminSection.users => _buildUsersPage(),
      },
    );
  }

  Widget _buildOverview() {
    const topPlaces = <({String name, String type, String province, String views})>[
      (name: 'Phố cổ Hội An', type: 'Danh lam', province: 'Quảng Nam', views: '2.140'),
      (name: 'Phở Hà Nội', type: 'Món ăn', province: 'Hà Nội', views: '1.870'),
      (name: 'Đại Nội Huế', type: 'Danh lam', province: 'Thừa Thiên Huế', views: '1.320'),
    ];

    return ListView(
      key: const ValueKey('overview'),
      padding: const EdgeInsets.fromLTRB(30, 22, 30, 28),
      children: [
        const Text(
          'Tổng quan',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF202622),
          ),
        ),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            final count = constraints.maxWidth >= 730
                ? 4
                : constraints.maxWidth >= 430
                    ? 2
                    : 1;
            final gap = 12.0;
            final width = (constraints.maxWidth - (count - 1) * gap) / count;
            return Wrap(
              spacing: gap,
              runSpacing: 12,
              children: [
                _overviewMetric('Lượt truy cập', '12.480', width),
                _overviewMetric('Tài khoản đăng ký', '1.240', width),
                _overviewMetric('Lượt nghe audio guide', '3.215', width),
                _overviewMetric('Chờ kiểm duyệt', '7', width),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final tableWidth = constraints.maxWidth < 690 ? 690.0 : constraints.maxWidth;
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _line),
              ),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth - 36,
                  child: Column(
                    children: [
                      const _OverviewTableRow(
                        isHeader: true,
                        name: 'Top địa điểm',
                        type: 'Loại',
                        province: 'Tỉnh',
                        views: 'Lượt xem',
                        action: 'Thao tác',
                      ),
                      ...topPlaces.map((place) => _OverviewTableRow(
                            name: place.name,
                            type: place.type,
                            province: place.province,
                            views: place.views,
                            action: 'Xem',
                            onAction: () {
                              _selectSection(
                                place.type == 'Món ăn' ? _AdminSection.foods : _AdminSection.places,
                                closeDrawer: false,
                              );
                            },
                          )),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 18),
        _overviewInsights(),
        const SizedBox(height: 14),
        Text(
          'Số liệu minh họa.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
        ),
      ],
    );
  }

  Widget _overviewInsights() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxPanelHeight = constraints.maxWidth >= 1100 ? 420.0 : 340.0;
        final panelHeight = (MediaQuery.sizeOf(context).height * 0.42)
            .clamp(260.0, maxPanelHeight)
            .toDouble();
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              SizedBox(height: panelHeight, child: _trafficPanel()),
              const SizedBox(height: 14),
              SizedBox(height: panelHeight, child: _quickActionsPanel()),
            ],
          );
        }
        return SizedBox(
          height: panelHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: _trafficPanel()),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: _quickActionsPanel()),
            ],
          ),
        );
      },
    );
  }

  Widget _trafficPanel() {
    const traffic = <({String day, String count, double factor})>[
      (day: 'T2', count: '1.2k', factor: 0.42),
      (day: 'T3', count: '1.5k', factor: 0.56),
      (day: 'T4', count: '1.3k', factor: 0.48),
      (day: 'T5', count: '1.8k', factor: 0.68),
      (day: 'T6', count: '1.6k', factor: 0.61),
      (day: 'T7', count: '2.1k', factor: 0.82),
      (day: 'CN', count: '2.5k', factor: 1.0),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lượt truy cập 7 ngày',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF202622),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F2EC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '+12,8%',
                  style: TextStyle(
                    color: _green,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Lượt truy cập theo ngày · số liệu minh họa',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBarHeight =
                    (constraints.maxHeight - 52).clamp(40.0, 210.0).toDouble();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: traffic.map((item) {
                    final isToday = item.day == 'CN';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              item.count,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: maxBarHeight * item.factor,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? _green
                                    : _green.withOpacity(0.32),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              item.day,
                              style: TextStyle(
                                color: isToday ? _green : Colors.grey.shade600,
                                fontSize: 11,
                                fontWeight:
                                    isToday ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActionsPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Truy cập nhanh',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF202622),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                _overviewQuickAction(
                  icon: Icons.fact_check_outlined,
                  title: 'Kiểm duyệt nội dung',
                  detail: '7 nội dung đang chờ',
                  section: _AdminSection.moderation,
                ),
                const Divider(height: 1, color: _line),
                _overviewQuickAction(
                  icon: Icons.place_outlined,
                  title: 'Quản lý địa điểm',
                  detail: 'Cập nhật điểm đến',
                  section: _AdminSection.places,
                ),
                const Divider(height: 1, color: _line),
                _overviewQuickAction(
                  icon: Icons.people_outline,
                  title: 'Quản lý người dùng',
                  detail: 'Tài khoản và quyền truy cập',
                  section: _AdminSection.users,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewQuickAction({
    required IconData icon,
    required String title,
    required String detail,
    required _AdminSection section,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectSection(section, closeDrawer: false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.09),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: _green, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
            ],
          ),
        ),
      ),
    );
  }
  Widget _overviewMetric(String title, String value, double width) {
    return SizedBox(
      width: width,
      height: 88,
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 13, 12, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11.5),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w800,
                color: Color(0xFF202622),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagePage() {
    final records = _recordsForCurrentSection();
    final filtered = records.where((record) => '${record.title} ${record.detail} ${record.area} ${record.status}'.toLowerCase().contains(_search.toLowerCase())).toList();
    final title = _sectionTitle;
    final section = _section;
    return Column(
      key: ValueKey(section),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 12, spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), const SizedBox(height: 4), Text('Danh sách $_recordLabel (${records.length})', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))]),
            FilledButton.icon(onPressed: () => _openEditor(records, sectionTitle: _editorTitle(isNew: true)), icon: const Icon(Icons.add), label: const Text('Thêm mới'), style: FilledButton.styleFrom(backgroundColor: _green)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              hintText: AppTranslations.translate('Tìm kiếm $_recordLabel...'),
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: _line)),
            ),
          ),
        ),
        Expanded(
          child: _loadingRecords ? const Center(child: CircularProgressIndicator(color: _green)) : filtered.isEmpty
              ? Center(child: Text('Không tìm thấy $_recordLabel.', style: TextStyle(color: Colors.grey.shade600)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(22, 2, 22, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final imageUrl = (item.data['image_url'] ?? '').toString().trim();
                    return Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: imageUrl.isNotEmpty
                              ? AppImage(
                                  source: imageUrl,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  fallbackIcon: _sectionIcon(section),
                                  fallbackIconSize: 22,
                                )
                              : Container(
                                  width: 56,
                                  height: 56,
                                  color: _green.withOpacity(0.09),
                                  alignment: Alignment.center,
                                  child: Icon(_sectionIcon(section), color: _green),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text('${item.detail} · ${item.area}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          const SizedBox(height: 7),
                          _statusChip(item.status),
                        ])),
                        PopupMenuButton<String>(
                          tooltip: AppTranslations.translate('Thao tác'),
                          onSelected: (value) {
                            if (value == 'edit') _openEditor(records, record: item, sectionTitle: _editorTitle(isNew: false));
                            if (value == 'hide' && !_managed(section)) setState(() => item.status = item.status == 'Đang ẩn' ? 'Đang hiển thị' : 'Đang ẩn');
                            if (value == 'delete') _deleteRecord(records, item);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                            if (!_managed(section)) PopupMenuItem(value: 'hide', child: Text(item.status == 'Đang ẩn' ? 'Hiển thị lại' : 'Ẩn')),
                            const PopupMenuItem(value: 'delete', child: Text('Xóa')),
                          ],
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _editorTitle({required bool isNew}) {
    if (_section == _AdminSection.overview) return isNew ? 'Thêm nội dung' : 'Chỉnh sửa nội dung';
    final prefix = switch (_section) {
      _AdminSection.places => 'Địa điểm',
      _AdminSection.foods => 'Món ăn',
      _AdminSection.events => 'Sự kiện',
      _AdminSection.itineraries => 'Lịch trình gợi ý',
      _AdminSection.dialects => 'Từ địa phương',
      _AdminSection.cadao => 'Ca dao, tục ngữ',
      _ => 'Nội dung',
    };
    return isNew ? 'Thêm $prefix' : 'Sửa $prefix';
  }

  Future<void> _openEditor(List<_AdminRecord> records, { _AdminRecord? record, required String sectionTitle }) async {
    if (_managed(_section)) {
      await _openManagedEditor(record: record, sectionTitle: sectionTitle);
      return;
    }
    final titleController = TextEditingController(text: record?.title ?? '');
    final detailController = TextEditingController(text: record?.detail ?? '');
    final areaController = TextEditingController(text: record?.area ?? '');
    var status = record?.status ?? 'Bản nháp';

    final result = await showDialog<_AdminRecord>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(sectionTitle),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: titleController, autofocus: true, decoration: InputDecoration(labelText: AppTranslations.translate('Tên / tiêu đề *'))),
                const SizedBox(height: 12),
                TextField(controller: detailController, decoration: InputDecoration(labelText: AppTranslations.translate('Mô tả / phân loại'))),
                const SizedBox(height: 12),
                TextField(controller: areaController, decoration: InputDecoration(labelText: AppTranslations.translate('Địa phương / thông tin thêm'))),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(labelText: AppTranslations.translate('Trạng thái')),
                  items: const [
                    DropdownMenuItem(value: 'Đang hiển thị', child: Text('Đang hiển thị')),
                    DropdownMenuItem(value: 'Bản nháp', child: Text('Bản nháp')),
                    DropdownMenuItem(value: 'Đang ẩn', child: Text('Đang ẩn')),
                  ],
                  onChanged: (value) { if (value != null) setDialogState(() => status = value); },
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _green),
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(dialogContext, _AdminRecord(title: title, detail: detailController.text.trim(), area: areaController.text.trim(), status: status));
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    titleController.dispose();
    detailController.dispose();
    areaController.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (record == null) {
        records.insert(0, result);
      } else {
        final index = records.indexOf(record);
        if (index >= 0) records[index] = result;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(record == null ? 'Đã thêm (demo) ${result.title}.' : 'Đã cập nhật (demo) ${result.title}.')));
  }

  Future<void> _deleteRecord(List<_AdminRecord> records, _AdminRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa nội dung?'),
        content: Text('Bạn có chắc muốn xóa "${record.title}" khỏi danh sách?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: _red), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_managed(_section) && record.id != null) {
      try {
        final uri = Uri.parse('${ApiConfig.baseUrl}${_path(_section)}/${Uri.encodeComponent(record.id!)}');
        final response = await http.delete(uri);
        if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('HTTP ${response.statusCode}');
        await _loadRecords(_section);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kh\u00f4ng x\u00f3a \u0111\u01b0\u1ee3c: $e')));
      }
    } else {
      setState(() => records.remove(record));
    }
  }

  String _dialectRegionFor(Map<String, dynamic>? data) {
    if ((data?['north_word']?.toString().trim() ?? '').isNotEmpty) {
      return _foodRegionOptions[0];
    }
    if ((data?['central_word']?.toString().trim() ?? '').isNotEmpty) {
      return _foodRegionOptions[1];
    }
    if ((data?['south_word']?.toString().trim() ?? '').isNotEmpty) {
      return _foodRegionOptions[2];
    }
    return _foodRegionOptions[0];
  }

  String _dialectWordFor(Map<String, dynamic>? data) {
    final key = switch (_dialectRegionFor(data)) {
      'Miền Bắc' => 'north_word',
      'Miền Trung' => 'central_word',
      _ => 'south_word',
    };
    return data?[key]?.toString() ?? '';
  }

  String _dialectFieldForRegion(String region) => switch (region) {
        'Miền Bắc' => 'north_word',
        'Miền Trung' => 'central_word',
        _ => 'south_word',
      };

  Future<void> _openManagedEditor({
    _AdminRecord? record,
    required String sectionTitle,
  }) async {
    final fields = _fields(_section);
    final defaults = _section == _AdminSection.places
        ? {'latitude':'10.7769','longitude':'106.7009'}
        : _section == _AdminSection.foods
            ? {'category':'M\u00f3n \u0103n \u0111\u01b0\u1eddng ph\u1ed1','region':'Mi\u1ec1n Nam','province':'TP. H\u1ed3 Ch\u00ed Minh','price_range':'30.000 - 80.000 VN\u0110'}
            : _section == _AdminSection.events
                ? {}
          : _section == _AdminSection.cadao
              ? {'type':'Ca dao','category':'V\u0103n h\u00f3a & Phong t\u1ee5c'}
                : {'category':'Ph\u01b0\u01a1ng ng\u1eef 3 mi\u1ec1n','region':'Mi\u1ec1n B\u1eafc'};
    final controllers = <String,TextEditingController>{
      for (final key in fields.keys)
        key: TextEditingController(
          text: ((_section == _AdminSection.dialects && key == 'region'
                  ? _dialectRegionFor(record?.data)
                  : _section == _AdminSection.dialects && key == 'word'
                      ? _dialectWordFor(record?.data)
                      : record?.data[key]) ??
                  (key == 'event_end_date' ? record?.data['event_date'] : null) ??
                  defaults[key] ??
                  '')
              .toString(),
        ),
    };
    var uploadingImage = false;
    final result = await showDialog<Map<String,String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(sectionTitle),
          content: SizedBox(width: 500, child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: fields.entries.map((field) {
              if (field.key == 'event_date' || field.key == 'event_end_date') {
                final selectedDate =
                    DateTime.tryParse(controllers[field.key]!.text);
                final startDate =
                    DateTime.tryParse(controllers['event_date']?.text ?? '');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final now = DateTime.now();
                      final pickedDate = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ??
                            (field.key == 'event_end_date' ? startDate : null) ??
                            DateTime(now.year, now.month, now.day),
                        firstDate: field.key == 'event_end_date'
                            ? startDate ?? DateTime(1900)
                            : DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (pickedDate == null || !dialogContext.mounted) return;
                      setDialogState(() {
                        controllers[field.key]!.text =
                            _formatDateForApi(pickedDate);
                        if (field.key == 'event_date') {
                          final endDate = DateTime.tryParse(
                            controllers['event_end_date']?.text ?? '',
                          );
                          if (endDate == null || endDate.isBefore(pickedDate)) {
                            controllers['event_end_date']!.text =
                                _formatDateForApi(pickedDate);
                          }
                        }
                      });
                    },
                    child: InputDecorator(
                      decoration: _adminInputDecoration(
                        field.value,
                        suffixIcon: const Icon(Icons.calendar_month_outlined),
                      ),
                      child: Text(
                        selectedDate == null
                            ? (field.key == 'event_date'
                                ? 'Chọn ngày bắt đầu'
                                : 'Chọn ngày kết thúc')
                            : _formatDateForDisplay(selectedDate),
                        style: selectedDate == null
                            ? TextStyle(color: Theme.of(dialogContext).hintColor)
                            : null,
                      ),
                    ),
                  ),
                );
              }
              if (field.key == 'province' || field.key == 'region') {
                final isRegion = field.key == 'region';
                final currentOption = controllers[field.key]!.text;
                final options = isRegion
                    ? _foodRegionOptions
                    : _vietnamProvinceOptions;
                final availableOptions = <String>[
                  ...options,
                  if (currentOption.isNotEmpty &&
                      !options.contains(currentOption))
                    currentOption,
                ];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    value: currentOption.isEmpty ? null : currentOption,
                    isExpanded: true,
                    menuMaxHeight: 340,
                    decoration: _adminInputDecoration(field.value),
                    hint: Text(isRegion ? 'Chọn miền' : 'Chọn tỉnh/thành'),
                    items: availableOptions
                        .map((option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ))
                        .toList(),
                    onChanged: (option) {
                      if (option == null) return;
                      setDialogState(() {
                        controllers[field.key]!.text = option;
                      });
                    },
                  ),
                );
              }
              if (field.key == 'type') {
                const types = ['Ca dao', 'Tục ngữ'];
                final current = controllers[field.key]!.text;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: DropdownButtonFormField<String>(
                    value: types.contains(current) ? current : types.first,
                    decoration: _adminInputDecoration(field.value),
                    items: types
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (type) {
                      if (type == null) return;
                      setDialogState(() {
                        controllers[field.key]!.text = type;
                      });
                    },
                  ),
                );
              }
              final isMultilineField = const {
                'history',
                'culture',
                'description',
                'cultural_story',
                'address',
                'highlights',
                'travel_info',
              }.contains(field.key);
              final textField = TextField(
                controller: controllers[field.key],
                keyboardType: const {'latitude', 'longitude'}.contains(field.key)
                    ? const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      )
                    : TextInputType.text,
                minLines: 1,
                maxLines: isMultilineField ? 4 : 1,
                textAlignVertical: TextAlignVertical.center,
                decoration: _adminInputDecoration(field.value),
              );
              if (field.key != 'image_url') {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: textField,
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Expanded(child: textField),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: uploadingImage ? null : () async {
                      setDialogState(() => uploadingImage = true);
                      try {
                        final file = await FilePicker.pickFile(type: FileType.image);
                        if (file == null) return;
                        final path = await UploadService().uploadImage(
                          bytes: await file.readAsBytes(),
                          fileName: file.name,
                          folder: _section == _AdminSection.places
                              ? 'tourist-places'
                              : 'foods',
                        );
                        if (!dialogContext.mounted) return;
                        controllers[field.key]!.text = path;
                      } catch (error) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text('Kh\u00f4ng t\u1ea3i \u0111\u01b0\u1ee3c \u1ea3nh: $error')),
                          );
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => uploadingImage = false);
                        }
                      }
                    },
                    icon: uploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Ch\u1ECDn \u1EA3nh'),
                  ),
                ]),
              );
            }).toList()),
          )),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('H\u1ee7y')),
            FilledButton(onPressed: () {
              final values = {for (final entry in controllers.entries) entry.key: entry.value.text.trim()};
              final requiredKey = _section == _AdminSection.cadao
                  ? 'content'
                  : _section == _AdminSection.dialects
                      ? 'word'
                      : 'name';
              if (requiredKey.isNotEmpty &&
                  (values[requiredKey] ?? '').isEmpty) return;
              final startDate = DateTime.tryParse(values['event_date'] ?? '');
              final endDate =
                  DateTime.tryParse(values['event_end_date'] ?? '');
              if (_section == _AdminSection.events &&
                  (startDate == null ||
                      endDate == null ||
                      endDate.isBefore(startDate))) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Hãy chọn ngày bắt đầu và ngày kết thúc hợp lệ.')),
                );
                return;
              }
              Navigator.pop(dialogContext, values);
            }, child: const Text('L\u01b0u v\u00e0o MariaDB')),
          ],
        ),
      ),
    );
    for (final controller in controllers.values) { controller.dispose(); }
    if (result == null || !mounted) return;
    try {
      final id = record?.id;
      final payload = Map<String, String>.from(result);
      if (_section == _AdminSection.dialects) {
        final region = result['region'] ?? _foodRegionOptions.first;
        final selectedWordKey = _dialectFieldForRegion(region);
        for (final key in ['north_word', 'central_word', 'south_word']) {
          payload[key] = record?.data[key]?.toString() ?? '';
        }
        final oldWordKey = const [
          'north_word',
          'central_word',
          'south_word',
        ].firstWhere(
          (key) => (record?.data[key]?.toString().trim() ?? '').isNotEmpty,
          orElse: () => selectedWordKey,
        );
        if (record != null && oldWordKey != selectedWordKey) {
          payload[oldWordKey] = '';
        }
        payload[selectedWordKey] = result['word'] ?? '';
        payload['meaning'] = '';
        payload.remove('word');
        payload.remove('region');
      }
      final uri = Uri.parse('${ApiConfig.baseUrl}${_path(_section)}${id == null ? '' : '/${Uri.encodeComponent(id)}'}');
      final response = id == null
          ? await http.post(uri, headers: {'Content-Type':'application/json'}, body: jsonEncode(payload))
          : await http.put(uri, headers: {'Content-Type':'application/json'}, body: jsonEncode(payload));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
      await _loadRecords(_section);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(id == null ? '\u0110\u00e3 th\u00eam v\u00e0o MariaDB.' : '\u0110\u00e3 c\u1eadp nh\u1eadt trong MariaDB.')),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kh\u00f4ng l\u01b0u \u0111\u01b0\u1ee3c: $e')),
      );
    }
  }

  Widget _statusChip(String status) {
    final color = switch (status) {
      'Đang hiển thị' => _green,
      'Chờ duyệt' => const Color(0xFFB77824),
      'Đã duyệt' => _green,
      'Từ chối' || 'Đang ẩn' || 'Đã khóa' => _red,
      _ => const Color(0xFF68716D),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
      child: Text(status, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildModerationPage() {
    return ListView(
      key: const ValueKey('moderation'),
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Kiểm duyệt bài viết, đánh giá và bình luận', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Chọn giữ nguyên nội dung hoặc tắt để người dùng thấy thông báo.', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 18),
        if (_loadingModeration) const LinearProgressIndicator(color: _green),
        if (_moderationLoadError != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text('Không tải được nội dung kiểm duyệt: $_moderationLoadError'),
              TextButton.icon(
                onPressed: _loadModeration,
                icon: const Icon(Icons.refresh),
                label: const Text('Tải lại'),
              ),
            ]),
          ),
        ..._moderation.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(item.type == 'comment' ? Icons.mode_comment_outlined : Icons.rate_review_outlined, color: _green, size: 23),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), const SizedBox(height: 5), Text('${item.typeLabel} · ${item.author} · ${item.createdAt}', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
              if (item.rating != null) _statusChip('${item.rating}/5'),
            ]),
            if (item.content.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(item.content, style: const TextStyle(height: 1.4)),
            ],
            const SizedBox(height: 14),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: _loadingModeration ? null : () => _moderate(item, 'keep'), icon: const Icon(Icons.check, size: 18), label: const Text('Giữ nguyên'), style: FilledButton.styleFrom(backgroundColor: _green)),
              OutlinedButton.icon(onPressed: _loadingModeration ? null : () => _moderate(item, 'hide'), icon: const Icon(Icons.visibility_off_outlined, size: 18), label: const Text('Tắt nội dung'), style: OutlinedButton.styleFrom(foregroundColor: _red)),
            ]),
          ]),
        )),
        if (!_loadingModeration && _moderationLoadError == null && _moderation.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Không có nội dung chờ kiểm duyệt.'))),
      ],
    );
  }

  Widget _buildUsersPage() {
    return ListView(
      key: const ValueKey('users'),
      padding: const EdgeInsets.all(22),
      children: [
        const Text('Quản lý người dùng', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('Theo dõi vai trò và trạng thái tài khoản. Không thể khóa tài khoản admin đang đăng nhập.', style: TextStyle(color: Colors.grey.shade600)),
        const SizedBox(height: 18),
        if (_loadingUsers) const LinearProgressIndicator(color: _green),
        if (!_loadingUsers && _usersLoadError != null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Kh\u00f4ng t\u1ea3i \u0111\u01b0\u1ee3c danh s\u00e1ch: $_usersLoadError'),
          ),
        if (!_loadingUsers && _usersLoadError == null && _users.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('Ch\u01b0a c\u00f3 ng\u01b0\u1eddi d\u00f9ng.'),
          ),
        ..._users.map((user) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _line)),
          child: Row(children: [
            CircleAvatar(backgroundColor: user.role == 'admin' ? const Color(0xFFE4F1EB) : const Color(0xFFFFEEE8), child: Icon(user.role == 'admin' ? Icons.admin_panel_settings_outlined : Icons.person_outline, color: user.role == 'admin' ? _green : _red)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text(user.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), const SizedBox(height: 7), Wrap(spacing: 6, children: [_statusChip(user.role == 'admin' ? 'Quản trị viên' : 'Người dùng'), if (user.locked) _statusChip('Đã khóa')])])),
            if (user.role != 'admin')
              OutlinedButton(
                onPressed: () => _setUserLocked(user, !user.locked),
                style: OutlinedButton.styleFrom(foregroundColor: user.locked ? _green : _red),
                child: Text(user.locked ? 'Mở khóa' : 'Khóa'),
              ),
          ]),
        )),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _OverviewTableRow extends StatelessWidget {
  const _OverviewTableRow({
    required this.name,
    required this.type,
    required this.province,
    required this.views,
    required this.action,
    this.isHeader = false,
    this.onAction,
  });

  final String name;
  final String type;
  final String province;
  final String views;
  final String action;
  final bool isHeader;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      color: isHeader ? const Color(0xFF77817B) : const Color(0xFF343B37),
      fontSize: isHeader ? 11 : 12.5,
      fontWeight: isHeader ? FontWeight.w500 : FontWeight.w400,
    );
    return Container(
      height: isHeader ? 38 : 44,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _line.withOpacity(isHeader ? 0.9 : 0.75)),
        ),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle)),
          Expanded(flex: 1, child: Text(type, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle)),
          Expanded(flex: 1, child: Text(province, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle)),
          Expanded(flex: 1, child: Text(views, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle)),
          Expanded(
            flex: 1,
            child: isHeader
                ? Text(action, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle)
                : Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: _green,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(30, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(action, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AdminRecord {
  _AdminRecord({required this.title, required this.detail, required this.area, required this.status, this.id, this.data = const {}});
  final String title;
  final String detail;
  final String area;
  String status;
  final String? id;
  final Map<String,dynamic> data;
}

class _ModerationRecord {
  _ModerationRecord({required this.id, required this.title, required this.content, required this.author, required this.type, required this.createdAt, this.rating});
  final String id;
  final String title;
  final String content;
  final String author;
  final String type;
  final int? rating;
  final String createdAt;

  String get typeLabel => switch (type) {
        'review' => 'Đánh giá địa điểm',
        'post' => 'Bài đánh giá cộng đồng',
        'comment' => 'Bình luận',
        _ => 'Nội dung',
      };
}

class _AdminUser {
  _AdminUser({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.locked = false,
  });

  final String id;
  final String username;
  final String email;
  final String role;
  bool locked;
}
