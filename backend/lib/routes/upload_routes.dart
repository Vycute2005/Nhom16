import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import 'package:backend/storage/rustfs_storage_service.dart';

class UploadRoutes {
  final RustFsStorageService storageService;
  static const _allowedImageHosts = {
    'toplist.vn',
    'upload.wikimedia.org',
    'thumb.wikimedia.org',
    'live.staticflickr.com',
    'images.rawpixel.com',
    'bluediamondretreat.com',
  };

  UploadRoutes(this.storageService);

  Router get router {
    final router = Router();

    router.post('/api/uploads', (Request request) async {
      final folder = request.url.queryParameters['folder'] ?? 'foods';

      const allowedFolders = ['foods', 'restaurants', 'tourist-places'];

      if (!allowedFolders.contains(folder)) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Invalid upload folder.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final form = request.formData();

      if (form == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Request must be multipart/form-data'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      Uint8List? fileBytes;
      String? fileName;

      await for (final formData in form.formData) {
        if (formData.name == 'file') {
          fileBytes = await formData.part.readBytes();
          fileName = formData.filename;
        }
      }

      if (fileBytes == null || fileName == null) {
        return Response.badRequest(
          body: jsonEncode({'message': 'File is required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final safeFileName = fileName;
      final safeFileBytes = fileBytes;

      final extension = safeFileName.contains('.')
          ? safeFileName.split('.').last.toLowerCase()
          : 'jpg';

      final objectPath =
          '$folder/${DateTime.now().millisecondsSinceEpoch}.$extension';

      await storageService.uploadBytes(
        objectPath: objectPath,
        bytes: safeFileBytes,
      );

      return Response.ok(
        jsonEncode({'path': objectPath}),
        headers: {'Content-Type': 'application/json'},
      );
    });

    router.get('/api/images/<path|.*>', (Request request, String path) async {
      try {
        final object = await storageService.getObject(objectPath: path);

        final extension = path.split('.').last.toLowerCase();

        String contentType;

        switch (extension) {
          case 'png':
            contentType = 'image/png';
            break;
          case 'webp':
            contentType = 'image/webp';
            break;
          case 'gif':
            contentType = 'image/gif';
            break;
          case 'jpg':
          case 'jpeg':
          default:
            contentType = 'image/jpeg';
            break;
        }

        return Response.ok(object, headers: {'Content-Type': contentType});
      } catch (e) {
        return Response.notFound(
          jsonEncode({'message': 'Image not found'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    });

    router.get('/api/image-proxy', (Request request) async {
      final source = request.url.queryParameters['url'];
      final uri = source == null ? null : Uri.tryParse(source);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.userInfo.isNotEmpty ||
          (uri.hasPort && uri.port != 443) ||
          !_allowedImageHosts.contains(uri.host.toLowerCase())) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Unsupported image URL.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final client = http.Client();
      try {
        final request = http.Request('GET', uri)
          ..followRedirects = false
          ..headers['User-Agent'] = 'HCMExplorer/1.0';
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          return Response(
            502,
            body: jsonEncode({'message': 'Image source returned an error.'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final contentType = response.headers['content-type']
            ?.split(';')
            .first
            .trim()
            .toLowerCase();
        if (contentType == null ||
            !const {
              'image/jpeg',
              'image/png',
              'image/webp',
              'image/gif',
            }.contains(contentType)) {
          return Response(
            502,
            body: jsonEncode({
              'message': 'Image source returned invalid data.',
            }),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final imageBuilder = BytesBuilder(copy: false);
        var imageSize = 0;
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 15),
        )) {
          imageSize += chunk.length;
          if (imageSize > 10 * 1024 * 1024) {
            return Response(
              502,
              body: jsonEncode({
                'message': 'Image source returned invalid data.',
              }),
              headers: {'Content-Type': 'application/json'},
            );
          }
          imageBuilder.add(chunk);
        }

        return Response.ok(
          imageBuilder.takeBytes(),
          headers: {
            'Content-Type': contentType,
            'Cache-Control': 'public, max-age=86400',
          },
        );
      } on TimeoutException {
        return Response(
          504,
          body: jsonEncode({'message': 'Image source timed out.'}),
          headers: {'Content-Type': 'application/json'},
        );
      } on http.ClientException {
        return Response(
          502,
          body: jsonEncode({'message': 'Could not retrieve image source.'}),
          headers: {'Content-Type': 'application/json'},
        );
      } finally {
        client.close();
      }
    });

    return router;
  }
}
