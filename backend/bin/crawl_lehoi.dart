import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Refresh lead photos from the cited pages' Open Graph metadata.
/// Curated schedules and existing image URLs remain as fallbacks.
Future<void> main() async {
  final file = File('data/lehoi.json');
  if (!await file.exists()) {
    stderr.writeln('Không tìm thấy data/lehoi.json. Hãy chạy từ thư mục backend.');
    exitCode = 1;
    return;
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! List) {
    stderr.writeln('data/lehoi.json phải là một danh sách JSON.');
    exitCode = 1;
    return;
  }

  final client = http.Client();
  var refreshed = 0;
  try {
    for (var index = 0; index < decoded.length; index++) {
      final raw = decoded[index];
      if (raw is! Map) continue;
      final event = Map<String, dynamic>.from(raw);
      final source = Uri.tryParse(event['source']?.toString() ?? '');
      if (source == null || !source.hasScheme) continue;

      try {
        final response = await client
            .get(source, headers: {'User-Agent': 'VNGuideFestivalCrawler/1.0'})
            .timeout(const Duration(seconds: 12));
        if (response.statusCode != 200) continue;
        final imageUrl = _openGraphImage(response.body, source);
        if (imageUrl == null) continue;
        event['image_url'] = imageUrl;
        decoded[index] = event;
        refreshed++;
      } catch (error) {
        stderr.writeln('Bỏ qua ảnh của ${event['name']}: $error');
      }
    }
  } finally {
    client.close();
  }

  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(decoded));
  stdout.writeln('Đã làm mới $refreshed ảnh lễ hội; lịch và ảnh dự phòng được giữ nguyên.');
}

String? _openGraphImage(String html, Uri source) {
  final tags = RegExp(r'<meta\b[^>]*>', caseSensitive: false);
  for (final match in tags.allMatches(html)) {
    final tag = match.group(0)!;
    final property = RegExp(
      r'''(?:property|name)\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(tag)?.group(1)?.toLowerCase();
    if (property != 'og:image' && property != 'twitter:image') continue;

    final content = RegExp(
      r'''content\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(tag)?.group(1);
    if (content == null || content.trim().isEmpty) continue;
    return source.resolve(content.replaceAll('&amp;', '&')).toString();
  }
  return null;
}
