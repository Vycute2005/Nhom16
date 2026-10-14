import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/tourist_place.dart';
import '../widgets/app_image.dart';
import 'map_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  final TouristPlace place;

  const PlaceDetailScreen({
    super.key,
    required this.place,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> {
  Map<String, dynamic>? _weather;
  bool _isLoadingWeather = true;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  // Gọi API lấy thời tiết theo lat, lng từ object place
  Future<void> _fetchWeather() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://103.82.26.171:8080/api/weather?lat=${widget.place.latitude}&lng=${widget.place.longitude}',
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _weather = jsonDecode(response.body);
            _isLoadingWeather = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingWeather = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppImage(
              source: widget.place.imageUrl,
              width: double.infinity,
              height: 230,
              fit: BoxFit.cover,
              fallbackIcon: Icons.location_city_outlined,
              fallbackIconSize: 56,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.place.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),

                  // ==========================================
                  // KHUNG HIỂN THỊ THỜI TIẾT TẠI ĐIỂM ĐẾN
                  // ==========================================
                  Card(
                    color: Colors.lightBlue[50],
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _isLoadingWeather
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : _weather != null
                              ? Row(
                                  children: [
                                    Image.network(
                                      _weather!['icon_url'],
                                      width: 48,
                                      height: 48,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.wb_sunny,
                                        color: Colors.orange,
                                        size: 40,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Thời tiết điểm đến: ${_weather!['temperature']}°C',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                          Text(
                                            '${_weather!['description']} • Độ ẩm: ${_weather!['humidity']}%',
                                            style: TextStyle(color: Colors.grey[700]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : const Text('Không thể lấy thông tin thời tiết'),
                    ),
                  ),

                  Text(
                    'Address',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(widget.place.address),
                  const SizedBox(height: 16),
                  Text(
                    'History',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(widget.place.history),
                  const SizedBox(height: 16),
                  Text(
                    'Culture',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(widget.place.culture),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapScreen(
                              title: widget.place.name,
                              latitude: widget.place.latitude,
                              longitude: widget.place.longitude,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}