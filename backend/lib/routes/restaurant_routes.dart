import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/repositories/restaurant_repository.dart';

class RestaurantRoutes {
  final RestaurantRepository repository;

  RestaurantRoutes(this.repository);

  Router get router {
    final router = Router();

    router.get('/api/restaurants', (Request request) async {
      final restaurants = await repository.findAll();

      return Response.ok(
        jsonEncode(restaurants),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/api/restaurants/<id>', (Request request, String id) async {
      final restaurant = await repository.findById(id);

      if (restaurant == null) {
        return Response.notFound(
          jsonEncode({'message': 'Restaurant not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode(restaurant),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/restaurants', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      await repository.create(
        id: data['id'],
        name: data['name'],
        address: data['address'],
        foodId: data['food_id'],
        latitude: double.parse(data['latitude'].toString()),
        longitude: double.parse(data['longitude'].toString()),
        imageUrl: data['image_url'],
        rating: double.parse(data['rating'].toString()),
        openingHours: data['opening_hours']?.toString() ?? '',
        openingHoursSource: data['opening_hours_source']?.toString() ?? '',
        imageIsIllustrative: data['image_is_illustrative'] == true,
      );

      return Response(
        201,
        body: jsonEncode({'message': 'Restaurant created successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.put('/api/restaurants/<id>', (Request request, String id) async {
      final existingRestaurant = await repository.findById(id);

      if (existingRestaurant == null) {
        return Response.notFound(
          jsonEncode({'message': 'Restaurant not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      await repository.update(
        id: id,
        name: data['name'],
        address: data['address'],
        foodId: data['food_id'],
        latitude: double.parse(data['latitude'].toString()),
        longitude: double.parse(data['longitude'].toString()),
        imageUrl: data['image_url'],
        rating: double.parse(data['rating'].toString()),
        openingHours:
            data['opening_hours']?.toString() ??
            existingRestaurant['opening_hours']?.toString() ??
            '',
        openingHoursSource:
            data['opening_hours_source']?.toString() ??
            existingRestaurant['opening_hours_source']?.toString() ??
            '',
        imageIsIllustrative: data['image_is_illustrative'] == null
            ? existingRestaurant['image_is_illustrative']?.toString() == '1'
            : data['image_is_illustrative'] == true,
      );

      return Response.ok(
        jsonEncode({'message': 'Restaurant updated successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.delete('/api/restaurants/<id>', (Request request, String id) async {
      final existingRestaurant = await repository.findById(id);

      if (existingRestaurant == null) {
        return Response.notFound(
          jsonEncode({'message': 'Restaurant not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await repository.delete(id);

      return Response.ok(
        jsonEncode({'message': 'Restaurant deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    return router;
  }
}
