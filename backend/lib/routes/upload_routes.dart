import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
    'down-vn.img.susercontent.com',
    'thumb.wikimedia.org',
    'live.staticflickr.com',
    'images.rawpixel.com',
    'images.unsplash.com',
    'www.huongnghiepaau.com',
    'huongnghiepaau.com',
    'galatourist.com',
    'www.galatourist.com',
    'luhanhvietnam.com.vn',
    'www.luhanhvietnam.com.vn',
    'file.hstatic.net',
    'topnhatrang.com.vn',
    'www.topnhatrang.com.vn',
    'dulichvietnam.com.vn',
    'www.dulichvietnam.com.vn',
    's-aicmscdn.vietnamhoinhap.vn',
    'dynamic-media-cdn.tripadvisor.com',
    'catba.tours',
    'www.catba.tours',
    'langcomvong.com',
    'bluediamondretreat.com',
    'phunuvietnam.mediacdn.vn',
    'cdn.nhandan.vn',
    'media.vov.vn',
    'cafefcdn.com',
    'danang.gov.vn',
    'media.baovanhoa.vn',
    'vstatic.vietnam.vn',
    'imgchinhsachcuocsong.vnanet.vn',
    'bqn.1cdn.vn',
    'media.thanhtra.com.vn',
    'dientuungdung.vn',
    'congan.angiang.gov.vn',
    'images.baodantoc.vn',
    'nld.mediacdn.vn',
  };

  UploadRoutes(this.storageService);

  static bool _isAllowedImageUri(Uri uri) =>
      uri.scheme == 'https' &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      _allowedImageHosts.contains(uri.host.toLowerCase());

  static Uri? _resolveImageRedirect(Uri baseUri, String? location) {
    if (location == null || location.trim().isEmpty) return null;
    try {
      return baseUri.resolve(location.trim());
    } on FormatException {
      return null;
    }
  }

  Router get router {
    final router = Router();

    router.post('/api/uploads', (Request request) async {
      final folder = request.url.queryParameters['folder'] ?? 'foods';

      const allowedFolders = [
        'foods',
        'restaurants',
        'tourist-places',
        'community',
        'avatars',
        'checkins',
      ];

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
      if (uri == null || !_isAllowedImageUri(uri)) {
        return Response.badRequest(
          body: jsonEncode({'message': 'Unsupported image URL.'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final client = http.Client();
      try {
        http.StreamedResponse? response;
        for (var attempt = 0; attempt < 3; attempt++) {
          var requestUri = uri;
          for (var redirectCount = 0; redirectCount <= 5; redirectCount++) {
            final imageRequest = http.Request('GET', requestUri)
              ..followRedirects = false
              ..headers['User-Agent'] = 'HCMExplorer/1.0';
            final candidate = await client
                .send(imageRequest)
                .timeout(const Duration(seconds: 15));
            response = candidate;

            if (candidate.statusCode == HttpStatus.ok) break;

            const redirectStatuses = {301, 302, 303, 307, 308};
            if (!redirectStatuses.contains(candidate.statusCode) ||
                redirectCount == 5) {
              break;
            }

            final nextUri = _resolveImageRedirect(
              requestUri,
              candidate.headers['location'],
            );
            await candidate.stream.drain<void>();
            if (nextUri == null || !_isAllowedImageUri(nextUri)) {
              return Response(
                502,
                body: jsonEncode({
                  'message': 'Image source returned an unsupported redirect.',
                }),
                headers: {'Content-Type': 'application/json'},
              );
            }
            requestUri = nextUri;
          }

          final attemptResponse = response;
          if (attemptResponse == null ||
              attemptResponse.statusCode == HttpStatus.ok) {
            break;
          }

          final canRetry = const {
            HttpStatus.tooManyRequests,
            HttpStatus.badGateway,
            HttpStatus.serviceUnavailable,
            HttpStatus.gatewayTimeout,
          }.contains(attemptResponse.statusCode);
          if (!canRetry || attempt == 2) {
            return Response(
              502,
              body: jsonEncode({'message': 'Image source returned an error.'}),
              headers: {'Content-Type': 'application/json'},
            );
          }

          final retryAfterSeconds = int.tryParse(
            attemptResponse.headers['retry-after'] ?? '',
          );
          await attemptResponse.stream.drain<void>();
          await Future<void>.delayed(
            Duration(
              milliseconds: retryAfterSeconds == null
                  ? 500 * (attempt + 1)
                  : (retryAfterSeconds.clamp(1, 5) * 1000),
            ),
          );
        }

        final imageResponse = response;
        if (imageResponse == null ||
            imageResponse.statusCode != HttpStatus.ok) {
          return Response(
            502,
            body: jsonEncode({'message': 'Image source returned an error.'}),
            headers: {'Content-Type': 'application/json'},
          );
        }

        final contentType = imageResponse.headers['content-type']
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
        await for (final chunk in imageResponse.stream.timeout(
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
