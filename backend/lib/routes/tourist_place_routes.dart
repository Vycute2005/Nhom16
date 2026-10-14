import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/repositories/tourist_place_repository.dart';

class TouristPlaceRoutes {
  final TouristPlaceRepository repository;

  TouristPlaceRoutes(this.repository);

  Router get router {
    final router = Router();

    router.get('/api/tourist-places', (Request request) async {
      final places = await repository.findAll();

      return Response.ok(
        jsonEncode(places),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.get(
      '/api/tourist-places/<id>',
          (Request request, String id) async {
        final place = await repository.findById(id);

        if (place == null) {
          return Response.notFound(
            jsonEncode({
              'message': 'Tourist place not found',
            }),
            headers: {
              'Content-Type': 'application/json',
            },
          );
        }

        return Response.ok(
          jsonEncode(place),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      },
    );

    router.post('/api/tourist-places', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      await repository.create(
        id: data['id'],
        name: data['name'],
        imageUrl: data['image_url'],
        history: data['history'],
        culture: data['culture'],
        address: data['address'],
        latitude: double.parse(data['latitude'].toString()),
        longitude: double.parse(data['longitude'].toString()),
      );

      return Response(
        201,
        body: jsonEncode({
          'message': 'Tourist place created successfully',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.put(
      '/api/tourist-places/<id>',
          (Request request, String id) async {
        final existingPlace = await repository.findById(id);

        if (existingPlace == null) {
          return Response.notFound(
            jsonEncode({
              'message': 'Tourist place not found',
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
          imageUrl: data['image_url'],
          history: data['history'],
          culture: data['culture'],
          address: data['address'],
          latitude: double.parse(data['latitude'].toString()),
          longitude: double.parse(data['longitude'].toString()),
        );

        return Response.ok(
          jsonEncode({
            'message': 'Tourist place updated successfully',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      },
    );

    router.delete(
      '/api/tourist-places/<id>',
          (Request request, String id) async {
        final existingPlace = await repository.findById(id);

        if (existingPlace == null) {
          return Response.notFound(
            jsonEncode({
              'message': 'Tourist place not found',
            }),
            headers: {
              'Content-Type': 'application/json',
            },
          );
        }

        await repository.delete(id);

        return Response.ok(
          jsonEncode({
            'message': 'Tourist place deleted successfully',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      },
    );

    return router;
  }
}