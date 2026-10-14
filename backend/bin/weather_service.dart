import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  // Thay API Key bạn vừa copy ở Bước 1 vào đây
  static const String apiKey = 'YOUR_OPENWEATHERMAP_API_KEY';

  // Hàm lấy thời tiết theo vĩ độ (lat) và kinh độ (lng)
  static Future<Map<String, dynamic>?> fetchWeatherByCoordinates(double lat, double lng) async {
    // units=metric: Lấy độ C
    // lang=vi: Trả về kết quả mô tả thời tiết bằng tiếng Việt
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&units=metric&lang=vi&appid=$apiKey',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        return {
          'location_name': data['name'] ?? 'Địa điểm',
          'temperature': (data['main']['temp'] as num).round(), // Làm tròn nhiệt độ
          'description': (data['weather'][0]['description'] ?? '').toString().toUpperCase(), // Ví dụ: "MÂY RẢI RÁC"
          'humidity': data['main']['humidity'], // Độ ẩm %
          'wind_speed': (data['wind']['speed'] as num).toDouble(), // Tốc độ gió m/s
          'icon_url': 'https://openweathermap.org/img/wn/${data['weather'][0]['icon']}@2x.png', // Icon thời tiết
        };
      } else {
        print('❌ Lỗi OpenWeather API: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Lỗi kết nối thời tiết: $e');
    }
    return null;
  }
}