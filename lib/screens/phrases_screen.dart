import 'dart:convert';

import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/cadao.dart';
import '../models/phrase.dart';
import 'culture_detail_screen.dart';

class PhrasesScreen extends StatefulWidget {
  const PhrasesScreen({super.key});

  @override
  State<PhrasesScreen> createState() => _PhrasesScreenState();
}

class _PhrasesScreenState extends State<PhrasesScreen> with AppLocaleAwareState<PhrasesScreen> {
  int selectedRegionIndex = 0;
  final List<String> regions = ['Bắc', 'Trung', 'Nam'];

  List<Phrase> allPhrases = [];
  List<CaDao> allCaDao = [];

  bool isLoading = true;
  String? phraseError;
  String? caDaoError;

  final FlutterTts flutterTts = FlutterTts();
  late final Future<bool> _ttsReady;
  String? _vietnameseLocale;

  @override
  void initState() {
    super.initState();
    _ttsReady = _initTts();
    _fetchData();
  }

  Future<bool> _initTts() async {
    try {
      for (final locale in ['vi-VN', 'vi']) {
        if (await flutterTts.isLanguageAvailable(locale) != true) continue;
        final languageResult = await flutterTts.setLanguage(locale);
        if (languageResult != 0) {
          _vietnameseLocale = locale;
          break;
        }
      }

      if (_vietnameseLocale == null) {
        debugPrint('Thiet bi khong co giong doc tieng Viet.');
        return false;
      }
      await flutterTts.setSpeechRate(0.5);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
      return true;
    } catch (error) {
      debugPrint('Khong the khoi tao TTS: $error');
      return false;
    }
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      // Chon lai vi-VN truoc moi lan doc, tranh doc bang giong mac dinh
      // neu nguoi dung bam nut khi TTS chua khoi tao xong.
      final isVietnameseReady = await _ttsReady;
      final languageResult = isVietnameseReady
          ? await flutterTts.setLanguage(_vietnameseLocale!)
          : 0;
      if (!isVietnameseReady || languageResult == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Thiết bị chưa có giọng đọc tiếng Việt. Hãy cài giọng tiếng Việt trong cài đặt chuyển văn bản thành giọng nói.',
            ),
          ),
        );
        return;
      }
      await flutterTts.stop();
      await flutterTts.speak(text);
    } catch (error) {
      debugPrint('Loi phat am: $error');
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      phraseError = null;
      caDaoError = null;
    });

    List<CaDao> loadedCaDao = [];
    List<Phrase> loadedPhrases = [];
    String? nextCaDaoError;
    String? nextPhraseError;

    // Dùng dữ liệu MariaDB để các thay đổi từ trang quản trị hiện ngay ở đây.
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/api/cadao'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const FormatException('API ca dao phải trả về danh sách.');
      }
      loadedCaDao = decoded
          .whereType<Map>()
          .map((item) => CaDao.fromJson(Map<String, dynamic>.from(item)))
          .where(_isValidCaDao)
          .toList();
      final seen = <String>{};
      loadedCaDao = loadedCaDao.where((item) {
        final key = _cleanText(item.content).toLowerCase();
        return key.isNotEmpty && seen.add(key);
      }).toList();
      debugPrint('Đã tải ${loadedCaDao.length} mục ca dao từ MariaDB.');
    } catch (apiError, apiStackTrace) {
      debugPrint('Không tải được ca dao từ MariaDB: $apiError');
      debugPrintStack(stackTrace: apiStackTrace);
      try {
        final jsonString =
            await rootBundle.loadString('backend/data/cadao_vanhoa.json');
        final decoded = jsonDecode(jsonString);
        if (decoded is! List) {
          throw const FormatException('Dữ liệu ca dao phải là danh sách.');
        }
        loadedCaDao = decoded
            .whereType<Map>()
            .map((item) => CaDao.fromJson(Map<String, dynamic>.from(item)))
            .where(_isValidCaDao)
            .toList();
        final seen = <String>{};
        loadedCaDao = loadedCaDao.where((item) {
          final key = _cleanText(item.content).toLowerCase();
          return key.isNotEmpty && seen.add(key);
        }).toList();
      } catch (assetError, assetStackTrace) {
        nextCaDaoError =
            'Không tải được ca dao từ MariaDB hoặc dữ liệu dự phòng.';
        debugPrint('Không đọc được dữ liệu ca dao dự phòng: $assetError');
        debugPrintStack(stackTrace: assetStackTrace);
      }
    }

    // Uu tien API; neu API khong co du lieu phuong ngu hop le, dung JSON
    // dong goi cung ung dung de van hien tu khi backend chua chay.
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/api/phrases');
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 10));

      debugPrint('Phrase API: $uri');
      debugPrint('Phrase API status: ${response.statusCode}');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final rawList = _extractList(decoded);

      if (rawList == null) {
        throw const FormatException(
          'API phrases khong tra ve danh sach JSON hoac data/items/phrases.',
        );
      }

      loadedPhrases = _parsePhrases(rawList);
      if (loadedPhrases.isEmpty) {
        throw const FormatException('API chưa có từ địa phương.');
      }

      debugPrint('Da tai ${loadedPhrases.length} ban ghi tieng dia phuong.');
      if (loadedPhrases.isNotEmpty) {
        debugPrint('Truong API phrase mau: ${_extractMapKeys(rawList.first)}');
      }
    } catch (error, stackTrace) {
      debugPrint('Loi doc tieng dia phuong tu API: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        final jsonString = await rootBundle.loadString('backend/phrases.json');
        final decoded = jsonDecode(jsonString);
        final rawList = _extractList(decoded);
        if (rawList == null) {
          throw const FormatException('Du lieu tu ngu khong phai danh sach JSON.');
        }
        loadedPhrases = _parsePhrases(rawList);
        if (!_hasRegionalCoverage(loadedPhrases)) {
          throw const FormatException('Khong co tu ngu hop le trong JSON.');
        }
        debugPrint('Da tai ${loadedPhrases.length} tu ngu tu JSON du phong.');
      } catch (assetError, assetStackTrace) {
        nextPhraseError =
            'Khong tai duoc tu ngu. Kiem tra backend hoac file backend/phrases.json.';
        debugPrint('Loi doc JSON tu ngu du phong: $assetError');
        debugPrintStack(stackTrace: assetStackTrace);
      }
    }

    if (!mounted) return;

    setState(() {
      allCaDao = loadedCaDao;
      allPhrases = loadedPhrases;
      caDaoError = nextCaDaoError;
      phraseError = nextPhraseError;
      isLoading = false;
    });
  }

  dynamic _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in ['data', 'items', 'phrases', 'results']) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return null;
  }

  List<Phrase> _parsePhrases(List<dynamic> rawList) => rawList
      .whereType<Map>()
      .map((item) {
        final row = Map<String, dynamic>.from(item);
        _setIfEmpty(row, 'north_word', _findValue(row, [
          'north_word', 'northWord', 'north', 'bac', 'mien_bac', 'mienBac',
          'tieng_bac', 'tiengBac', 'tu_mien_bac', 'tuMienBac', 'vietnamese',
        ]));
        _setIfEmpty(row, 'central_word', _findValue(row, [
          'central_word', 'centralWord', 'central', 'trung', 'mien_trung',
          'mienTrung', 'tieng_trung', 'tiengTrung', 'tu_mien_trung', 'tuMienTrung',
        ]));
        _setIfEmpty(row, 'south_word', _findValue(row, [
          'south_word', 'southWord', 'south', 'nam', 'mien_nam', 'mienNam',
          'tieng_nam', 'tiengNam', 'tu_mien_nam', 'tuMienNam',
        ]));
        _setIfEmpty(row, 'meaning', _findValue(row, [
          'meaning', 'explanation', 'nghia', 'y_nghia', 'yNghia',
          'description', 'definition',
        ]));
        return Phrase.fromJson(row);
      })
      .toList();

  bool _hasRegionalCoverage(List<Phrase> phrases) =>
      phrases.any((phrase) => phrase.northWord.trim().isNotEmpty) &&
      phrases.any((phrase) => phrase.centralWord.trim().isNotEmpty) &&
      phrases.any((phrase) => phrase.southWord.trim().isNotEmpty);

  List<String> _extractMapKeys(dynamic item) {
    if (item is Map) return item.keys.map((key) => key.toString()).toList();
    return [];
  }

  String _normaliseKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[_\s-]'), '');

  dynamic _findValue(Map<String, dynamic> row, List<String> candidates) {
    for (final candidate in candidates) {
      final wanted = _normaliseKey(candidate);
      for (final entry in row.entries) {
        if (_normaliseKey(entry.key) == wanted &&
            entry.value != null &&
            entry.value.toString().trim().isNotEmpty) {
          return entry.value;
        }
      }
    }
    return null;
  }

  void _setIfEmpty(
    Map<String, dynamic> row,
    String target,
    dynamic value,
  ) {
    final current = row[target];
    if ((current == null || current.toString().trim().isEmpty) && value != null) {
      row[target] = value;
    }
  }

  String _cleanText(String value) {
    return value
        .replaceAll(RegExp(r'[\u2190-\u21FF]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Loai cac dong giao dien website bi crawler thu thap nham.
  bool _isValidCaDao(CaDao item) {
    final content = _cleanText(item.content).toLowerCase();
    if (content.isEmpty) return false;

    const noisePhrases = [
      'bỏ qua để tới nội dung',
      'đăng nhập',
      'quay về trang chính',
      'ca-dao.comkho dữ liệu ca dao',
      'kho dữ liệu ca dao - tục ngữ việt nam',
      'tất cả thể loại',
      'trang chủ',
      'đăng ký',
      'tìm kiếm',
      'xem thêm',
      'đọc thêm',
    ];

    if (noisePhrases.any((noise) => content == noise || content.startsWith(noise))) {
      return false;
    }

    // Bo cac chu de/ten website ro rang khong phai noi dung ca dao.
    if (content.startsWith('ca-dao.com') || content.contains('kho dữ liệu ca dao')) {
      return false;
    }

    return true;
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayedPhrases = allPhrases.where((phrase) {
      final word = switch (selectedRegionIndex) {
        0 => phrase.northWord,
        1 => phrase.centralWord,
        _ => phrase.southWord,
      };
      return word.trim().isNotEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tiếng địa phương',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        actions: [
          IconButton(
            tooltip: AppTranslations.translate('Tải lại dữ liệu'),
            onPressed: isLoading ? null : _fetchData,
            icon: const Icon(Icons.refresh, color: Colors.black87),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B6A5B)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(regions.length, (index) {
                      final isActive = selectedRegionIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: ChoiceChip(
                          label: Text(AppTranslations.translateRegion(regions[index])),
                          selected: isActive,
                          selectedColor: const Color(0xFF1B6A5B),
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: isActive ? Colors.white : Colors.black87,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          onSelected: (_) => setState(() => selectedRegionIndex = index),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Phan tieng dia phuong.
                  if (phraseError != null)
                    _buildErrorMessage(phraseError!)
                  else if (displayedPhrases.isEmpty)
                    _buildEmptyMessage(
                      'Chưa có dữ liệu từ ngữ cho vùng ${AppTranslations.translateRegion(regions[selectedRegionIndex])}.',
                      detail: 'Bạn có thể chọn miền khác hoặc thêm từ địa phương trong phần quản trị.',
                    )
                  else
                    ...displayedPhrases.map(_buildLocalWordCard),

                  const SizedBox(height: 24),
                  const Text(
                    'Ca dao, tục ngữ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),

                  if (caDaoError != null)
                    _buildErrorMessage(caDaoError!)
                  else if (allCaDao.isEmpty)
                    _buildEmptyMessage('Chưa có dữ liệu ca dao.')
                  else
                    ...allCaDao.map((item) => _buildFolkSayingCard(context, item)),

                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: isLoading ? null : _fetchData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tải lại dữ liệu'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF1B6A5B)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyMessage(String message, {String? detail}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Center(
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFF9A3D29))),
    );
  }

  Widget _buildLocalWordCard(Phrase phrase) {
    final localWord = switch (selectedRegionIndex) {
      0 => phrase.northWord,
      1 => phrase.centralWord,
      _ => phrase.southWord,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(localWord, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B6A5B))),
                    ),
                    IconButton(
                      tooltip: AppTranslations.translate('Phát âm'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _speak(localWord),
                      icon: const Icon(Icons.volume_up, color: Color(0xFFC6422D)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolkSayingCard(BuildContext context, CaDao caDao) {
    final cleanContent = _cleanText(caDao.content);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CultureDetailScreen(
              title: cleanContent,
              subtitle: '${caDao.type} · ${caDao.category}',
              meaningDetail: caDao.meaning,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFF1B6A5B), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cleanContent,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text('${caDao.type} · ${caDao.category}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFFC6422D), size: 16),
          ],
        ),
      ),
    );
  }
}
