import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/repositories/tourist_place_repository.dart';
import 'package:backend/utils/tourist_province.dart';

class TouristPlaceRoutes {
  final TouristPlaceRepository repository;

  TouristPlaceRoutes(this.repository);

  Router get router {
    final router = Router();

    router.get('/api/tourist-places', (Request request) async {
      final provinces = request.url.queryParametersAll['province'] ?? const [];
      final places = await repository.findAll(provinces: provinces);

      return Response.ok(
        jsonEncode(places),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/api/tourist-places/<id>', (Request request, String id) async {
      final place = await repository.findById(id);

      if (place == null) {
        return Response.notFound(
          jsonEncode({'message': 'Tourist place not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return Response.ok(
        jsonEncode(place),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.post('/api/tourist-places', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body);
      final name = data['name']?.toString().trim() ?? '';
      final address = data['address']?.toString().trim() ?? '';
      final province = resolveTouristProvince(
        name: name,
        address: address,
        province: data['province']?.toString(),
      );
      if (province == null) {
        return Response(
          400,
          body: jsonEncode({'message': 'A valid province is required.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await repository.create(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        imageUrl: data['image_url']?.toString() ?? '',
        history: data['history']?.toString() ?? '',
        culture: data['culture']?.toString() ?? '',
        address: address,
        province: province,
        latitude: double.tryParse(data['latitude']?.toString() ?? ''),
        longitude: double.tryParse(data['longitude']?.toString() ?? ''),
      );

      return Response(
        201,
        body: jsonEncode({'message': 'Tourist place created successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.put('/api/tourist-places/<id>', (Request request, String id) async {
      final existingPlace = await repository.findById(id);

      if (existingPlace == null) {
        return Response.notFound(
          jsonEncode({'message': 'Tourist place not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final body = await request.readAsString();
      final data = jsonDecode(body);
      final name = data['name']?.toString().trim() ?? '';
      final address = data['address']?.toString().trim() ?? '';
      final province = resolveTouristProvince(
        name: name,
        address: address,
        province:
            data['province']?.toString() ??
            existingPlace['province']?.toString(),
      );
      if (province == null) {
        return Response(
          400,
          body: jsonEncode({'message': 'A valid province is required.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await repository.update(
        id: id,
        name: name,
        imageUrl: data['image_url']?.toString() ?? '',
        history: data['history']?.toString() ?? '',
        culture: data['culture']?.toString() ?? '',
        address: address,
        province: province,
        latitude: double.tryParse(data['latitude']?.toString() ?? ''),
        longitude: double.tryParse(data['longitude']?.toString() ?? ''),
      );

      return Response.ok(
        jsonEncode({'message': 'Tourist place updated successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.delete('/api/tourist-places/<id>', (
      Request request,
      String id,
    ) async {
      final existingPlace = await repository.findById(id);

      if (existingPlace == null) {
        return Response.notFound(
          jsonEncode({'message': 'Tourist place not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      await repository.delete(id);

      return Response.ok(
        jsonEncode({'message': 'Tourist place deleted successfully'}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    return router;
  }
}
