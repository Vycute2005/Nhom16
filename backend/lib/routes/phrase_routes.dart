import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:backend/repositories/phrase_repository.dart';

class PhraseRoutes {
  final PhraseRepository repository;

  PhraseRoutes(this.repository);

  Router get router {
    final router = Router();

    router.get('/api/phrases', (Request request) async {
      final phrases = await repository.findAll();

      return Response.ok(
        jsonEncode(phrases),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.get('/api/phrases/<id>', (Request request, String id) async {
      final phrase = await repository.findById(id);

      if (phrase == null) {
        return Response.notFound(
          jsonEncode({
            'message': 'Phrase not found',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }

      return Response.ok(
        jsonEncode(phrase),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.post('/api/phrases', (Request request) async {
      final body = await request.readAsString();
      final data = jsonDecode(body);

      await repository.create(
        id: data['id'],
        vietnamese: data['vietnamese'],
        pronunciation: data['pronunciation'],
        english: data['english'],
        explanation: data['explanation'],
      );

      return Response(
        201,
        body: jsonEncode({
          'message': 'Phrase created successfully',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.put('/api/phrases/<id>', (Request request, String id) async {
      final existingPhrase = await repository.findById(id);

      if (existingPhrase == null) {
        return Response.notFound(
          jsonEncode({
            'message': 'Phrase not found',
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
        vietnamese: data['vietnamese'],
        pronunciation: data['pronunciation'],
        english: data['english'],
        explanation: data['explanation'],
      );

      return Response.ok(
        jsonEncode({
          'message': 'Phrase updated successfully',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    router.delete('/api/phrases/<id>', (Request request, String id) async {
      final existingPhrase = await repository.findById(id);

      if (existingPhrase == null) {
        return Response.notFound(
          jsonEncode({
            'message': 'Phrase not found',
          }),
          headers: {
            'Content-Type': 'application/json',
          },
        );
      }

      await repository.delete(id);

      return Response.ok(
        jsonEncode({
          'message': 'Phrase deleted successfully',
        }),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    });

    return router;
  }
}