import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

final Map<String, Future<String?>> _imageLookups = {};
DateTime _nextOpenverseRequest = DateTime.fromMillisecondsSinceEpoch(0);

Future<String?> openverseImageFor(String subject) {
  final key = subject.trim().toLowerCase();
  if (key.isEmpty) {
    return Future.value(null);
  }

  return _imageLookups.putIfAbsent(key, () => _searchOpenverse(subject));
}

Future<String?> _searchOpenverse(String subject) async {
  final wait = _nextOpenverseRequest.difference(DateTime.now());
  if (wait > Duration.zero) {
    await Future<void>.delayed(wait);
  }
  _nextOpenverseRequest = DateTime.now().add(const Duration(seconds: 4));

  final uri = Uri.https('api.openverse.org', '/v1/images/', {
    'q': subject,
    'license': 'cc0,pdm',
    'page_size': '5',
  });

  Future<http.Response?> sendRequest() async {
    try {
      return await http
          .get(
            uri,
            headers: {
              HttpHeaders.userAgentHeader:
                  'HCMExplorer/1.0 (CC0 image lookup for data crawler)',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException {
      stderr.writeln('Openverse image lookup timed out for "$subject".');
      return null;
    } on http.ClientException catch (error) {
      stderr.writeln('Openverse image lookup failed for "$subject": $error');
      return null;
    }
  }

  var response = await sendRequest();
  if (response == null) {
    return null;
  }
  if (response.statusCode == HttpStatus.tooManyRequests) {
    final retryAfter =
        int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
    final cooldown = Duration(seconds: retryAfter);
    stderr.writeln(
      'Openverse rate limited "$subject"; retrying after '
      '${cooldown.inSeconds}s.',
    );
    _nextOpenverseRequest = DateTime.now().add(cooldown);
    await Future<void>.delayed(cooldown);
    response = await sendRequest();
    if (response == null) {
      return null;
    }
    _nextOpenverseRequest = DateTime.now().add(const Duration(seconds: 4));
  }

  if (response.statusCode != HttpStatus.ok) {
    stderr.writeln(
      'Openverse image lookup for "$subject" returned HTTP '
      '${response.statusCode}.',
    );
    return null;
  }

  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Openverse returned an invalid JSON object.');
  }
  final results = decoded['results'];
  if (results is! List) {
    throw const FormatException('Openverse returned no image result list.');
  }

  final queryTokens = _searchTokens(subject);
  for (final result in results.whereType<Map<String, dynamic>>()) {
    if (result['mature'] == true ||
        !{'cc0', 'pdm'}.contains(result['license'])) {
      continue;
    }
    final searchableText = [
      result['title'],
      if (result['tags'] is List)
        ...(result['tags'] as List).whereType<Map<String, dynamic>>().map(
          (tag) => tag['name'],
        ),
    ].whereType<String>().join(' ');
    if (!_hasRelevantTitle(searchableText, queryTokens)) {
      continue;
    }
    final imageUrl = result['url'];
    if (imageUrl is String &&
        imageUrl.startsWith('https://') &&
        RegExp(
          r'\.(?:jpe?g|png|webp)(?:\?|$)',
          caseSensitive: false,
        ).hasMatch(imageUrl)) {
      return imageUrl;
    }
  }

  stderr.writeln('Openverse has no matching CC0 image for "$subject".');
  return null;
}

Set<String> _searchTokens(String value) {
  const replacements = {
    'a': 'áàảãạăắằẳẵặâấầẩẫậ',
    'e': 'éèẻẽẹêếềểễệ',
    'i': 'íìỉĩị',
    'o': 'óòỏõọôốồổỗộơớờởỡợ',
    'u': 'úùủũụưứừửữự',
    'y': 'ýỳỷỹỵ',
    'd': 'đ',
  };
  var normalized = value.toLowerCase();
  for (final entry in replacements.entries) {
    for (final rune in entry.value.runes) {
      normalized = normalized.replaceAll(String.fromCharCode(rune), entry.key);
    }
  }
  const ignored = {
    'file',
    'vietnam',
    'landmark',
    'restaurant',
    'food',
    'dish',
    'vietnamese',
    'ho',
    'chi',
    'minh',
    'city',
  };
  return normalized
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.length > 1 && !ignored.contains(token))
      .toSet();
}

bool _hasRelevantTitle(String title, Set<String> queryTokens) {
  if (queryTokens.isEmpty) {
    return false;
  }
  final resultTokens = _searchTokens(title);
  final matched = queryTokens
      .where(
        (queryToken) => resultTokens.any(
          (resultToken) =>
              queryToken == resultToken ||
              (queryToken.length > 3 &&
                  resultToken.length > 3 &&
                  (queryToken.startsWith(resultToken) ||
                      resultToken.startsWith(queryToken))),
        ),
      )
      .length;
  return matched >= (queryTokens.length > 2 ? 2 : queryTokens.length);
}
