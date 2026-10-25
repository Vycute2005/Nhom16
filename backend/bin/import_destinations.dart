import 'dart:io';

import 'package:backend/config/database.dart';
import 'package:backend/repositories/tourist_place_repository.dart';

Future<void> main() async {
  final db = await Database.connect();
  final repository = TouristPlaceRepository(db);

  try {
    await repository.ensureSchema();
    final syncedCount = await repository.syncDestinationsIfAvailable();
    final totalCount = await repository.countAll();

    print('Đã đồng bộ $syncedCount địa điểm từ destinations.');
    print('Tổng số địa điểm hiện có: $totalCount.');
  } catch (error, stackTrace) {
    stderr.writeln('Không thể đồng bộ bảng destinations: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    await db.close();
  }
}
