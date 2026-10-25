import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:backend/config/database.dart';
import 'package:backend/auth_api.dart';
import 'package:backend/repositories/food_repository.dart';
import 'package:backend/routes/food_routes.dart';
import 'package:backend/repositories/restaurant_repository.dart';
import 'package:backend/routes/restaurant_routes.dart';
import 'package:backend/repositories/phrase_repository.dart';
import 'package:backend/routes/phrase_routes.dart';
import 'package:backend/repositories/ca_dao_repository.dart';
import 'package:backend/routes/ca_dao_routes.dart';
import 'package:backend/repositories/tourist_place_repository.dart';
import 'package:backend/routes/tourist_place_routes.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/storage/rustfs_storage_service.dart';
import 'package:backend/routes/upload_routes.dart';
import 'package:backend/routes/contact_routes.dart';

Future<void> main() async {
  final db = await Database.connect();

  await _ensureFestivalDateColumn(db);

  final rustFs = RustFsStorageService();
  final bucketExists = await rustFs.bucketExists();
  print('RustFS bucket exists: $bucketExists');

  final uploadRoutes = UploadRoutes(rustFs);

  final foodRepository = FoodRepository(db);
  await foodRepository.ensureSchema();
  final foodRoutes = FoodRoutes(foodRepository);

  final restaurantRepository = RestaurantRepository(db);
  await restaurantRepository.ensureSchema();
  final restaurantRoutes = RestaurantRoutes(restaurantRepository);

  final touristPlaceRepository = TouristPlaceRepository(db);
  await touristPlaceRepository.ensureSchema();
  await touristPlaceRepository.syncDestinationsIfAvailable();
  final touristPlaceRoutes = TouristPlaceRoutes(touristPlaceRepository);

  final phraseRepository = PhraseRepository(db);
  await phraseRepository.ensureSchema();
  final phraseRoutes = PhraseRoutes(phraseRepository); 

  final caDaoRepository = CaDaoRepository(db);
  await caDaoRepository.ensureSchema();
  await caDaoRepository.seedBundledData();
  final caDaoRoutes = CaDaoRoutes(caDaoRepository);

  final router = Router();
  final authApi = AuthApi();
  await authApi.initialize();
  authApi.registerRoutes(router);

  // =======================================================
  // ẨM THỰC: API Lấy danh sách món ăn & nhà hàng tương ứng
  // =======================================================
  router.get('/api/foods', (Request request) async {
    try {
      final result = await db.execute('''
        SELECT 
          f.id, f.category, f.region, f.province, f.name, 
          f.description, f.cultural_story, f.price_range, f.image_url,
          s.id as spot_id, s.spot_name, s.address, s.price as spot_price, s.rating, s.open_hours
        FROM foods f
        LEFT JOIN food_spots s ON f.id = s.food_id
        ORDER BY f.id DESC, s.id ASC;
      ''');

      Map<dynamic, Map<String, dynamic>> foodsMap = {};

      for (var row in result.rows) {
        final data = row.assoc();
        dynamic foodId = data['id'];

        if (!foodsMap.containsKey(foodId)) {
          foodsMap[foodId] = {
            'id': data['id'],
            'category': data['category'],
            'region': data['region'],
            'province': data['province'],
            'name': data['name'],
            'description': data['description'],
            'cultural_story': data['cultural_story'],
            'price_range': data['price_range'],
            'image_url': data['image_url'],
            'spots': [],
          };
        }

        if (data['spot_id'] != null) {
          (foodsMap[foodId]!['spots'] as List).add({
            'id': data['spot_id'],
            'spot_name': data['spot_name'],
            'address': data['address'],
            'price': data['spot_price'],
            'rating': data['rating'],
            'open_hours': data['open_hours'],
          });
        }
      }

      return Response.ok(
        jsonEncode(foodsMap.values.toList()),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e, stackTrace) {
      print('❌ Lỗi API /api/foods: $e\n$stackTrace');
      return Response.internalServerError(
        body: jsonEncode({'error': e.toString()}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
  });

  // Mount các Route có sẵn
  router.mount('/', foodRoutes.router.call);
  router.mount('/', restaurantRoutes.router.call);
  router.mount('/', touristPlaceRoutes.router.call);
  router.mount('/', phraseRoutes.router.call);
  router.mount('/', caDaoRoutes.router.call);
  router.mount('/', uploadRoutes.router.call);
  router.mount('/', ContactRoutes().router.call);

  router.get('/api/server-info', (Request request) {
    return Response.ok(
      jsonEncode({'service': 'vn-guide-backend', 'api_version': 2}),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.get('/api/health', (Request request) async {
    await db.execute('SELECT 1');
    final total = await touristPlaceRepository.countAll();
    return Response.ok(
      jsonEncode({
        'status': 'ok',
        'database_connected': true,
        'tourist_places_count': total,
      }),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  // =======================================================
  // 1. ENDPOINT THỜI TIẾT OPENWEATHERMAP
  // =======================================================
  router.get('/api/weather', (Request request) async {
    final queryParams = request.url.queryParameters;
    final lat = queryParams['lat'] ?? '10.7769';
    final lng = queryParams['lng'] ?? '106.7009';
    const apiKey = 'YOUR_OPENWEATHERMAP_API_KEY';

    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lng&units=metric&lang=vi&appid=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = {
          'location_name': data['name'] ?? 'TP. Hồ Chí Minh',
          'temperature': (data['main']['temp'] as num).round(),
          'description': (data['weather'][0]['description'] ?? '')
              .toString()
              .toUpperCase(),
          'humidity': data['main']['humidity'],
          'wind_speed': (data['wind']['speed'] as num).toDouble(),
          'icon_url':
              'https://openweathermap.org/img/wn/${data['weather'][0]['icon']}@2x.png',
        };
        return Response.ok(
          jsonEncode(result),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      } else {
        return Response.internalServerError(
          body: jsonEncode({'error': 'Lỗi gọi API OpenWeatherMap'}),
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

  // =======================================================
  // 2. ENDPOINT SỰ KIỆN & LỄ HỘI
  // =======================================================
  router.get('/api/events', (Request request) async {
    final result = await db.execute('''
      SELECT id, name, event_date, event_end_date, time_period, location, highlights, travel_info
      FROM festivals ORDER BY id DESC
    ''');
    return Response.ok(
      jsonEncode(result.rows.map((row) => row.assoc()).toList()),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  router.post('/api/events', (Request request) async {
    final data = jsonDecode(await request.readAsString());
    final eventDate = DateTime.tryParse(data['event_date']?.toString() ?? '');
    final eventEndDate =
        DateTime.tryParse(data['event_end_date']?.toString() ?? '');
    if (eventDate == null ||
        eventEndDate == null ||
        eventEndDate.isBefore(eventDate)) {
      return Response(
        400,
        body: jsonEncode({'message': 'Valid start and end dates are required.'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    await db.execute('''
      INSERT INTO festivals (
        name, event_date, event_end_date, time_period, location, highlights, travel_info, source
      ) VALUES (
        :name, :event_date, :event_end_date, :time_period, :location, :highlights, :travel_info, :source
      )
    ''', {
      'name': data['name']?.toString() ?? '',
      'event_date': _festivalDateForSql(eventDate),
      'event_end_date': _festivalDateForSql(eventEndDate),
      'time_period': _festivalPeriodFor(eventDate),
      'location': data['location']?.toString() ?? '',
      'highlights': data['highlights']?.toString() ?? '',
      'travel_info': data['travel_info']?.toString() ?? '',
      'source': '',
    });
    return Response(201, body: jsonEncode({'message': 'Event created'}));
  });

  router.put('/api/events/<id>', (Request request, String id) async {
    final existing = await db.execute(
      'SELECT id FROM festivals WHERE id = :id', {'id': id},
    );
    if (existing.rows.isEmpty) {
      return Response.notFound(jsonEncode({'message': 'Event not found'}));
    }
    final data = jsonDecode(await request.readAsString());
    final eventDate = DateTime.tryParse(data['event_date']?.toString() ?? '');
    final eventEndDate =
        DateTime.tryParse(data['event_end_date']?.toString() ?? '');
    if (eventDate == null ||
        eventEndDate == null ||
        eventEndDate.isBefore(eventDate)) {
      return Response(
        400,
        body: jsonEncode({'message': 'Valid start and end dates are required.'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }
    await db.execute('''
      UPDATE festivals SET name = :name, event_date = :event_date,
        event_end_date = :event_end_date,
        time_period = :time_period, location = :location,
        highlights = :highlights, travel_info = :travel_info
      WHERE id = :id
    ''', {
      'id': id,
      'name': data['name']?.toString() ?? '',
      'event_date': _festivalDateForSql(eventDate),
      'event_end_date': _festivalDateForSql(eventEndDate),
      'time_period': _festivalPeriodFor(eventDate),
      'location': data['location']?.toString() ?? '',
      'highlights': data['highlights']?.toString() ?? '',
      'travel_info': data['travel_info']?.toString() ?? '',
    });
    return Response.ok(jsonEncode({'message': 'Event updated'}));
  });
  router.delete('/api/events/<id>', (Request request, String id) async {
    final result = await db.execute(
      'DELETE FROM festivals WHERE id = :id', {'id': id},
    );
    if (result.affectedRows == 0) {
      return Response.notFound(jsonEncode({'message': 'Event not found'}));
    }
    return Response.ok(jsonEncode({'message': 'Event deleted'}));
  });

  // =======================================================
  // 3. ENDPOINT LỊCH TRÌNH GỢI Ý
  // =======================================================
  router.get('/api/itineraries', (Request request) async {
    final result = await db.execute('SELECT * FROM itineraries');
    final list = result.rows.map((r) => r.assoc()).toList();
    return Response.ok(
      jsonEncode(list),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  // =======================================================
  // 4. ENDPOINT HOTLINE TIỆN ÍCH
  // =======================================================
  router.get('/api/utilities', (Request request) async {
    final result = await db.execute('SELECT * FROM utilities');
    final list = result.rows.map((r) => r.assoc()).toList();
    return Response.ok(
      jsonEncode(list),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsHeaders())
      .addMiddleware(_logUnhandledErrors())
      .addHandler(router.call);

  final host = Platform.environment['HOST'] ?? '0.0.0.0';
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  HttpServer server;
  try {
    server = await shelf_io.serve(handler, host, port);
  } on SocketException catch (error) {
    if (_isAddressInUse(error) && await _isHealthyServer(host, port)) {
      print('VN Guide Server is already running on port $port.');
      return;
    }

    stderr.writeln('Could not start VN Guide Server on $host:$port: $error');
    if (_isAddressInUse(error)) {
      stderr.writeln(
        'Port $port is already in use. Stop the other process, or set PORT '
        'to an unused port and configure the app API_BASE_URL to match.',
      );
      stderr.writeln(
        'An older VN Guide backend may be occupying this port. Stop that '
        'process and restart this server so profile, favorites, check-in, '
        'review, and avatar-upload routes are active.',
      );
    }
    exitCode = 1;
    return;
  }

  print('🚀 VN Guide Server listening on port ${server.port}');
}

Future<void> _ensureFestivalDateColumn(DatabaseConnection db) async {
  final result = await db.execute('''
    SELECT COUNT(*) AS total
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'festivals'
      AND column_name = 'event_date'
  ''');
  final hasEventDate =
      int.tryParse(result.rows.first.assoc()['total'] ?? '') ?? 0;
  if (hasEventDate == 0) {
    await db.execute(
      'ALTER TABLE festivals ADD COLUMN event_date DATE NULL',
    );
  }
  final endDateResult = await db.execute('''
    SELECT COUNT(*) AS total
    FROM information_schema.columns
    WHERE table_schema = DATABASE()
      AND table_name = 'festivals'
      AND column_name = 'event_end_date'
  ''');
  final hasEventEndDate =
      int.tryParse(endDateResult.rows.first.assoc()['total'] ?? '') ?? 0;
  if (hasEventEndDate == 0) {
    await db.execute(
      'ALTER TABLE festivals ADD COLUMN event_end_date DATE NULL',
    );
  }
}

String _festivalDateForSql(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _festivalPeriodFor(DateTime date) {
  final now = DateTime.now().toUtc().add(const Duration(hours: 7));
  if (date.year == now.year && date.month == now.month) return 'Tháng này';
  if (date.isAfter(DateTime(now.year, now.month, 1))) return 'Sắp tới';
  return 'Cả năm';
}
bool _isAddressInUse(SocketException error) {
  final osError = error.osError;
  return osError?.errorCode == 10048 ||
      osError?.errorCode == 98 ||
      error.message.toLowerCase().contains('address already in use') ||
      error.message.toLowerCase().contains('only one usage of each socket');
}

Future<bool> _isHealthyServer(String host, int port) async {
  final probeHost = host == '0.0.0.0' || host == '::' ? '127.0.0.1' : host;
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final request = await client
        .getUrl(
          Uri(
            scheme: 'http',
            host: probeHost,
            port: port,
            path: '/api/server-info',
          ),
        )
        .timeout(const Duration(seconds: 2));
    final response = await request.close().timeout(const Duration(seconds: 2));
    if (response.statusCode != HttpStatus.ok) return false;

    final body = await utf8.decoder
        .bind(response)
        .join()
        .timeout(const Duration(seconds: 2));
    final payload = jsonDecode(body);
    return payload is Map &&
        payload['service'] == 'vn-guide-backend' &&
        payload['api_version'] == 2;
  } on SocketException {
    return false;
  } on TimeoutException {
    return false;
  } on HttpException {
    return false;
  } on FormatException {
    return false;
  } finally {
    client.close(force: true);
  }
}

Middleware _logUnhandledErrors() {
  return (innerHandler) {
    return (request) async {
      try {
        return await innerHandler(request);
      } catch (error, stackTrace) {
        stderr.writeln(
          'Unhandled API error for ${request.method} ${request.url}: $error',
        );
        stderr.writeln(stackTrace);
        return Response.internalServerError(
          body: jsonEncode({'error': 'Internal server error'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
    };
  };
}
