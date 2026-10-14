import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:backend/config/database.dart';
import 'package:backend/repositories/food_repository.dart';
import 'package:backend/routes/food_routes.dart';
import 'package:backend/repositories/restaurant_repository.dart';
import 'package:backend/routes/restaurant_routes.dart';
import 'package:backend/repositories/phrase_repository.dart';
import 'package:backend/routes/phrase_routes.dart';
import 'package:backend/repositories/tourist_place_repository.dart';
import 'package:backend/routes/tourist_place_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/storage/rustfs_storage_service.dart';
import 'package:backend/routes/upload_routes.dart';

Future<void> main() async {
  final db = await Database.connect();

  final rustFs = RustFsStorageService();

  final bucketExists = await rustFs.bucketExists();

  print('RustFS bucket exists: $bucketExists');

  final uploadRoutes = UploadRoutes(rustFs);

  final foodRepository = FoodRepository(db);
  final foodRoutes = FoodRoutes(foodRepository);

  final restaurantRepository = RestaurantRepository(db);
  final restaurantRoutes = RestaurantRoutes(restaurantRepository);

  final touristPlaceRepository = TouristPlaceRepository(db);
  final touristPlaceRoutes = TouristPlaceRoutes(touristPlaceRepository);

  final phraseRepository = PhraseRepository(db);
  final phraseRoutes = PhraseRoutes(phraseRepository);

  final router = Router();

  router.get('/health', (Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.mount('/', foodRoutes.router.call);
  router.mount('/', restaurantRoutes.router.call);
  router.mount('/', touristPlaceRoutes.router.call);
  router.mount('/', phraseRoutes.router.call);
  router.mount('/', uploadRoutes.router.call);

  // ==========================================
  // BỔ SUNG ROUTE THỜI TIẾT (OPENWEATHERMAP)
  // ==========================================
  router.get('/api/weather', (Request request) async {
    final queryParams = request.url.queryParameters;
    final lat = queryParams['lat'] ?? '10.7769';
    final lng = queryParams['lng'] ?? '106.7009';
    const apiKey = '71049fbf55ffa2b1362694e50af7468a'; 

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&units=metric&lang=vi&appid=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = {
          'location_name': data['name'] ?? 'Địa điểm',
          'temperature': (data['main']['temp'] as num).round(),
          'description': (data['weather'][0]['description'] ?? '').toString().toUpperCase(),
          'humidity': data['main']['humidity'],
          'wind_speed': (data['wind']['speed'] as num).toDouble(),
          'icon_url': 'https://openweathermap.org/img/wn/${data['weather'][0]['icon']}@2x.png',
        };
        return Response.ok(
          jsonEncode(result),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Lỗi lấy dữ liệu từ OpenWeatherMap'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addHandler(router.call);

  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await shelf_io.serve(handler, host, port);

  print('Server listening on ${server.address.address}:${server.port}');
}