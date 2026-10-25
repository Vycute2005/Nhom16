import 'dart:convert';
import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'package:url_launcher/url_launcher.dart';

String _displayFestivalDate(dynamic value) {
  final text = value?.toString().trim() ?? '';
  final date = DateTime.tryParse(text);
  if (date == null) return text.isEmpty ? 'Đang cập nhật' : text;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String _displayFestivalDateRange(dynamic startValue, dynamic endValue) {
  final startText = startValue?.toString().trim() ?? '';
  final endText = endValue?.toString().trim() ?? '';
  if (startText.isEmpty) return _displayFestivalDate(endText);
  final startDate = DateTime.tryParse(startText);
  final endDate = DateTime.tryParse(endText);
  if (startDate == null || endDate == null || startDate == endDate) {
    return _displayFestivalDate(startText);
  }
  return '${_displayFestivalDate(startDate)} – ${_displayFestivalDate(endDate)}';
}

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> with AppLocaleAwareState<EventsScreen> {
  static const _periods = ['Tháng này', 'Sắp tới', 'Cả năm'];
  List<Map<String, dynamic>> _events = [];
  String _period = _periods.first;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/events'),
      );
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw const FormatException('Expected event list');

      // Keep MariaDB as the source for editable event data.
      // Fill event images and legacy dates from the bundled dataset.
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
        // Events can still load from MariaDB if the optional asset is missing.
      }

      final events = decoded.whereType<Map>().map((item) {
        final row = Map<String, dynamic>.from(item);
        final key = row['name']?.toString().trim().toLowerCase() ?? '';
        final fallback = bundledByName[key];
        if (fallback != null) {
          for (final field in ['image_url', 'event_date', 'event_end_date']) {
            if (row[field]?.toString().trim().isNotEmpty != true &&
                fallback[field] != null) {
              row[field] = fallback[field];
            }
          }
        }
        return row;
      }).toList();

      if (!mounted) return;
      setState(() {
        _events = events;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Kh\u00f4ng t\u1ea3i \u0111\u01b0\u1ee3c s\u1ef1 ki\u1ec7n: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _events
        .where((event) => event['time_period']?.toString() == _period)
        .toList();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Sự kiện & Lễ hội',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: _periods.map((period) {
                final selected = period == _period;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(period),
                    selected: selected,
                    showCheckmark: selected,
                    checkmarkColor: const Color(0xFFB83B26),
                    selectedColor: const Color(0xFF0F5B49),
                    backgroundColor: const Color(0xFFF6FAF7),
                    side: BorderSide(
                      color: selected
                          ? const Color(0xFF0F5B49)
                          : const Color(0xFFB8C9C1),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.black87,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => setState(() => _period = period),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _MessageState(
                        message: _error!,
                        onPressed: () {
                          setState(() => _loading = true);
                          _loadEvents();
                        },
                      )
                    : events.isEmpty
                        ? const Center(child: Text('Chưa có dữ liệu sự kiện.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                            itemCount: events.length,
                            itemBuilder: (context, index) {
                              final event = events[index];
                              return _FestivalCard(
                                event: event,
                                index: index,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        FestivalDetailScreen(event: event),
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

class _FestivalCard extends StatelessWidget {
  const _FestivalCard({
    required this.event,
    required this.index,
    required this.onTap,
  });
  final Map<String, dynamic> event;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        index.isEven ? const Color(0xFFB83B26) : const Color(0xFF0F5B49);
    final imageUrl = event['image_url']?.toString().trim() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE8E1D5)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 60,
                  height: 64,
                  child: imageUrl.isEmpty
                      ? _FestivalImageFallback(color: color)
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) =>
                              loadingProgress == null
                                  ? child
                                  : _FestivalImageFallback(color: color),
                          errorBuilder: (_, __, ___) =>
                              _FestivalImageFallback(color: color),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['name']?.toString() ?? 'Lễ hội',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event['location'] ?? 'Chưa cập nhật địa điểm'} · ${_displayFestivalDateRange(event['event_date'], event['event_end_date'])}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}

class FestivalDetailScreen extends StatelessWidget {
  const FestivalDetailScreen({super.key, required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final name = event['name']?.toString() ?? 'Lễ hội';
    final location = event['location']?.toString() ?? '';
    final coordinates = _coordinatesFor(location);
    final imageUrl = event['image_url']?.toString() ?? '';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Chi tiết lễ hội',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 190,
              width: double.infinity,
              child: imageUrl.isEmpty
                  ? const _FestivalImageFallback()
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const _FestivalImageFallback(),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          Text(name,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          _DetailRow(
            icon: Icons.location_on_outlined,
            label: 'Địa điểm',
            value: location,
          ),
          const SizedBox(height: 10),
          _DetailRow(
            icon: Icons.calendar_month_outlined,
            label: 'Thời gian',
            value: _displayFestivalDateRange(
              event['event_date']?.toString().trim().isNotEmpty == true
                  ? event['event_date']
                  : event['time_period'],
              event['event_end_date'],
            ),
          ),
          const SizedBox(height: 22),
          const Text('Điểm nổi bật',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(event['highlights']?.toString() ?? 'Đang cập nhật thông tin.',
              style: const TextStyle(fontSize: 15, height: 1.55)),
          const SizedBox(height: 22),
          const Text('Thông tin tham quan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(event['travel_info']?.toString() ?? 'Đang cập nhật thông tin.',
              style: const TextStyle(fontSize: 15, height: 1.55)),
          const SizedBox(height: 26),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F5B49),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () =>
                  _openGoogleMaps(context, name, location, coordinates),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Xem trên bản đồ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          if (coordinates == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Chưa có tọa độ cho địa điểm này.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
            ),
        ],
      ),
    );
  }

  (double, double)? _coordinatesFor(String location) {
    final text = location.toLowerCase();
    if (text.contains('hương')) return (20.612, 105.739);
    if (text.contains('nam định')) return (20.438, 106.162);
    if (text.contains('yên tử')) return (21.174, 106.718);
    if (text.contains('tây ninh')) return (11.360, 106.137);
    if (text.contains('đà nẵng')) return (16.054, 108.202);
    if (text.contains('nghệ an')) return (18.679, 105.681);
    if (text.contains('huế')) return (16.463, 107.590);
    if (text.contains('cần thơ')) return (10.046, 105.746);
    if (text.contains('đà lạt')) return (11.940, 108.458);
    if (text.contains('sóc trăng')) return (9.603, 105.980);
    if (text.contains('phú thọ')) return (21.356, 105.397);
    if (text.contains('an giang')) return (10.689, 105.074);
    if (text.contains('cần giờ')) return (10.411, 106.954);
    if (text.contains('ninh thuận') || text.contains('bình thuận')) {
      return (11.565, 108.996);
    }
    if (text.contains('bình dương')) return (10.980, 106.652);
    if (text.contains('hà nội')) return (20.723, 105.738);
    if (text.contains('hồ chí minh')) return (10.7769, 106.7009);
    return null;
  }
}

Future<void> _openGoogleMaps(
  BuildContext context,
  String name,
  String location,
  (double, double)? coordinates,
) async {
  final query = coordinates == null
      ? name + ', ' + location
      : coordinates.$1.toString() + ',' + coordinates.$2.toString();
  final uri = Uri.https(
    'www.google.com',
    '/maps/search/',
    {'api': '1', 'query': query},
  );
  try {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được Google Maps.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không mở được Google Maps.')),
      );
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0F5B49), size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 14),
                children: [
                  TextSpan(
                    text: AppTranslations.translate(label) + ': ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, required this.onPressed});
  final String message;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: onPressed, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}

class _FestivalImageFallback extends StatelessWidget {
  const _FestivalImageFallback({this.color = const Color(0xFFE9E2D4)});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.white, 0.3)!],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -18,
              left: -14,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
            ),
            Positioned(
              right: -16,
              bottom: -22,
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.08),
                ),
              ),
            ),
            Center(
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.55), width: 2),
                ),
              ),
            ),
          ],
        ),
      );
}
