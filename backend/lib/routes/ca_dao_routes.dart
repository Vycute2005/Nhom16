import 'dart:convert';

import 'package:backend/repositories/ca_dao_repository.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class CaDaoRoutes {
  final CaDaoRepository repository;

  CaDaoRoutes(this.repository);

  Router get router {
    final router = Router();

    router.get('/api/cadao', (Request request) async {
      return Response.ok(
        jsonEncode(await repository.findAll()),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    router.get('/api/cadao/<id>', (Request request, String id) async {
      final entry = await repository.findById(id);
      if (entry == null) {
        return Response.notFound(jsonEncode({'message': 'Entry not found'}));
      }
      return Response.ok(
        jsonEncode(entry),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    router.post('/api/cadao', (Request request) async {
      final data = jsonDecode(await request.readAsString());
      if (data is! Map ||
          (data['content']?.toString().trim() ?? '').isEmpty) {
        return Response(
          400,
          body: jsonEncode({'message': 'Content is required.'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      await repository.create(Map<String, dynamic>.from(data));
      return Response(
        201,
        body: jsonEncode({'message': 'Entry created'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    router.put('/api/cadao/<id>', (Request request, String id) async {
      if (await repository.findById(id) == null) {
        return Response.notFound(jsonEncode({'message': 'Entry not found'}));
      }
      final data = jsonDecode(await request.readAsString());
      if (data is! Map ||
          (data['content']?.toString().trim() ?? '').isEmpty) {
        return Response(
          400,
          body: jsonEncode({'message': 'Content is required.'}),
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      await repository.update(id, Map<String, dynamic>.from(data));
      return Response.ok(
        jsonEncode({'message': 'Entry updated'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    router.delete('/api/cadao/<id>', (Request request, String id) async {
      if (await repository.findById(id) == null) {
        return Response.notFound(jsonEncode({'message': 'Entry not found'}));
      }
      await repository.delete(id);
      return Response.ok(
        jsonEncode({'message': 'Entry deleted'}),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    return router;
  }
}
