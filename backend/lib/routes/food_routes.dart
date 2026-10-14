import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/repositories/food_repository.dart';

class FoodRoutes {
  final FoodRepository repository;

  FoodRoutes(this.repository);

  Router get router {
    final router = Router();

    router.get('/api/foods', (Request request) async {
      final foods = await repository.findAll();

      return Response.ok(
        jsonEncode(foods),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.get('/api/foods/<id>', (Request request, String id) async {
      final food = await repository.findById(id);

      if (food == null) {
        return Response.notFound(
          jsonEncode({
            'message': 'Food not found',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }

      return Response.ok(
        jsonEncode(food),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.post('/api/foods', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      await repository.create(
        id: data['id'],
        name: data['name'],
        description: data['description'],
        imageUrl: data['image_url'],
      );

      return Response(
        201,
        body: jsonEncode({
          'message': 'Food created successfully',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.put('/api/foods/<id>', (Request request, String id) async {
      final existingFood = await repository.findById(id);

      if (existingFood == null) {
        return Response.notFound(
          jsonEncode({
            'message': 'Food not found',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);

      await repository.update(
        id: id,
        name: data['name'],
        description: data['description'],
        imageUrl: data['image_url'],
      );

      return Response.ok(
        jsonEncode({
          'message': 'Food updated successfully',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.delete('/api/foods/<id>', (Request request, String id) async {
      final existingFood = await repository.findById(id);

      if (existingFood == null) {
        return Response.notFound(
          jsonEncode({
            'message': 'Food not found',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }

      try {
        await repository.delete(id);

        return Response.ok(
          jsonEncode({
            'message': 'Food deleted successfully',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      } catch (e) {
        return Response(
          409,
          body: jsonEncode({
            'message':
            'Cannot delete food because it is being used by one or more restaurants.',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }
    });

    return router;
  }
}