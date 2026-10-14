import 'dart:typed_data';

import 'package:dotenv/dotenv.dart';
import 'package:minio/minio.dart';

class RustFsStorageService {
  late final Minio _minio;

  final String bucket;

  RustFsStorageService()
      : bucket = _loadBucket() {
    final dotenv = DotEnv()..load();

    _minio = Minio(
      endPoint: dotenv['RUSTFS_ENDPOINT'] ?? '',
      port: int.parse(dotenv['RUSTFS_PORT'] ?? '9000'),
      accessKey: dotenv['RUSTFS_ACCESS_KEY'] ?? '',
      secretKey: dotenv['RUSTFS_SECRET_KEY'] ?? '',
      region: dotenv['RUSTFS_REGION'] ?? 'us-east-1',
      useSSL: false,
      pathStyle: true,
    );
  }

  static String _loadBucket() {
    final dotenv = DotEnv()..load();

    return dotenv['RUSTFS_BUCKET'] ?? '';
  }

  Future<bool> bucketExists() async {
    return await _minio.bucketExists(bucket);
  }

  Future<void> uploadBytes({
    required String objectPath,
    required Uint8List bytes,
  }) async {
    await _minio.putObject(
      bucket,
      objectPath,
      Stream<Uint8List>.value(bytes),
      size: bytes.length,
    );
  }

  Future<MinioByteStream> getObject({
    required String objectPath,
  }) async {
    return await _minio.getObject(
      bucket,
      objectPath,
    );
  }
}