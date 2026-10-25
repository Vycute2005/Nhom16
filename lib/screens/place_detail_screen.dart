import 'dart:convert';
import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import '../models/tourist_place.dart';
import '../services/auth_api_service.dart';
import '../services/favorites_store.dart';
import '../widgets/app_image.dart';
import 'account_access_screen.dart';
import 'map_screen.dart';
import 'checkin_screen.dart';

class PlaceDetailScreen extends StatefulWidget {
  final TouristPlace place;

  const PlaceDetailScreen({
    super.key,
    required this.place,
  });

  @override
  State<PlaceDetailScreen> createState() => _PlaceDetailScreenState();
}

class _PlaceDetailScreenState extends State<PlaceDetailScreen> with AppLocaleAwareState<PlaceDetailScreen> {
  Map<String, dynamic>? _weather;
  bool _isLoadingWeather = true;
  bool _isPlayingAudio = false;
  bool _isAudioPaused = false;
  bool _isPreparingAudio = false;
  double _audioProgress = 0;
  int _resumeOffset = 0;
  int _utteranceOffset = 0;
  final FlutterTts _flutterTts = FlutterTts();
  late final Future<bool> _ttsReady;
  String? _vietnameseLocale;
  Map<String, dynamic>? _myReview;
  Map<String, dynamic>? _myCheckin;
  bool _isLoadingReview = false;

  @override
  void initState() {
    super.initState();
    _configureTtsHandlers();
    _ttsReady = _initializeTts();
    _fetchWeather();
    _loadMyReview();
    _loadMyCheckin();
  }

  void _configureTtsHandlers() {
    _flutterTts.setStartHandler(() {
      if (!mounted) return;
      setState(() { _isPlayingAudio = true; _isAudioPaused = false; });
    });
    _flutterTts.setPauseHandler(() {
      if (!mounted) return;
      setState(() { _isPlayingAudio = false; _isAudioPaused = true; });
    });
    _flutterTts.setContinueHandler(() {
      if (!mounted) return;
      setState(() { _isPlayingAudio = true; _isAudioPaused = false; });
    });
    _flutterTts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = false;
        _isAudioPaused = false;
        _audioProgress = 1;
        _resumeOffset = 0;
      });
    });
    _flutterTts.setCancelHandler(() {
      if (!mounted) return;
      setState(() { _isPlayingAudio = false; _isAudioPaused = false; });
    });
    _flutterTts.setProgressHandler((text, start, end, word) {
      if (!mounted) return;
      final length = _narrationText.length;
      if (length == 0) return;
      final currentStart = (_utteranceOffset + start).clamp(0, length).toInt();
      final currentEnd = (_utteranceOffset + end).clamp(0, length).toInt();
      setState(() {
        _resumeOffset = currentStart;
        _audioProgress = currentEnd / length;
      });
    });
    _flutterTts.setErrorHandler((message) {
      if (!mounted) return;
      setState(() {
        _isPlayingAudio = false;
        _isAudioPaused = false;
        _isPreparingAudio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể phát thuyết minh lúc này.')),
      );
    });
  }

  Future<bool> _initializeTts() async {
    try {
      for (final locale in ['vi-VN', 'vi']) {
        if (await _flutterTts.isLanguageAvailable(locale) != true) continue;
        final result = await _flutterTts.setLanguage(locale);
        if (result != 0) {
          _vietnameseLocale = locale;
          break;
        }
      }
      if (_vietnameseLocale == null) return false;
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1);
      await _flutterTts.setPitch(1);
      return true;
    } catch (error) {
      debugPrint('Không thể khởi tạo giọng đọc: $error');
      return false;
    }
  }

  String get _narrationText {
    final parts = <String>['Chào mừng bạn đến với ${widget.place.name}.'];
    if (widget.place.address.trim().isNotEmpty) {
      parts.add('Địa chỉ: ${widget.place.address}.');
    }
    if (widget.place.history.trim().isNotEmpty) {
      parts.add('Lịch sử. ${widget.place.history.trim()}');
    }
    if (widget.place.culture.trim().isNotEmpty) {
      parts.add('Văn hóa. ${widget.place.culture.trim()}');
    }
    if (widget.place.history.trim().isEmpty &&
        widget.place.culture.trim().isEmpty) {
      parts.add('Hiện chưa có nội dung thuyết minh chi tiết cho địa điểm này.');
    }
    return parts.join('\n\n');
  }

  Future<void> _toggleNarration() async {
    if (_isPlayingAudio) {
      try {
        await _flutterTts.pause();
        if (mounted) {
          setState(() { _isPlayingAudio = false; _isAudioPaused = true; });
        }
      } catch (error) {
        debugPrint('Không thể tạm dừng thuyết minh: $error');
      }
      return;
    }
    if (_isPreparingAudio) return;

    setState(() => _isPreparingAudio = true);
    try {
      final ready = await _ttsReady;
      if (!mounted) return;
      if (!ready || _vietnameseLocale == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Thiết bị chưa có giọng đọc tiếng Việt. Hãy cài giọng tiếng Việt trong cài đặt chuyển văn bản thành giọng nói.',
          )),
        );
        return;
      }
      final text = _narrationText;
      final startAt = _isAudioPaused ? _resumeOffset : 0;
      await _flutterTts.stop();
      await _flutterTts.setLanguage(_vietnameseLocale!);
      _utteranceOffset = startAt.clamp(0, text.length).toInt();
      if (mounted) {
        setState(() {
          _isPreparingAudio = false;
          _isPlayingAudio = true;
          _isAudioPaused = false;
          if (_utteranceOffset == 0) _audioProgress = 0;
        });
      }
      await _flutterTts.speak(text.substring(_utteranceOffset));
    } catch (error) {
      debugPrint('Không thể phát thuyết minh: $error');
      if (mounted) {
        setState(() { _isPlayingAudio = false; _isAudioPaused = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể phát thuyết minh lúc này.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPreparingAudio = false);
    }
  }

  Widget _buildNarrationPlayer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFFB83B26),
            child: _isPreparingAudio
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    tooltip: AppTranslations.translate(_isPlayingAudio ? 'Tạm dừng' : 'Phát thuyết minh'),
                    icon: Icon(
                      _isPlayingAudio ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: _toggleNarration,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Thuyết minh tự động',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: _audioProgress,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFFB83B26),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('1x', style: TextStyle(
            fontWeight: FontWeight.bold, color: Colors.grey,
          )),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _loadMyReview() async {
    final token = userSession.token;
    if (token == null) return;
    final api = AuthApiService();
    try {
      final reviews = await api.getReviews(
        token: token,
        placeId: widget.place.id,
      );
      if (mounted) {
        setState(() => _myReview = reviews.isEmpty ? null : reviews.first);
      }
    } catch (_) {
      if (mounted) setState(() => _myReview = null);
    } finally {
      api.close();
    }
  }

  Future<void> _loadMyCheckin() async {
    final token = userSession.token;
    if (token == null || token.isEmpty) return;
    final api = AuthApiService();
    try {
      final checkins = await api.getCheckins(token: token);
      final matching = checkins.where(
        (item) => item['placeId']?.toString() == widget.place.id,
      );
      if (mounted) {
        setState(() => _myCheckin = matching.isEmpty ? null : matching.first);
      }
    } catch (_) {
      // Check-in history is optional on the place detail page.
    } finally {
      api.close();
    }
  }

  Future<void> _checkIn() async {
    final checkin = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CheckinCreateScreen(place: widget.place),
      ),
    );
    if (checkin == null || !mounted) return;
    setState(() => _myCheckin = checkin);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu check-in vào lịch sử của bạn.')),
    );
  }

  Widget _checkinSummary(Map<String, dynamic> checkin) {
    final date = DateTime.tryParse(
      (checkin['visitedAt'] ?? checkin['checkedInAt'] ?? '').toString(),
    );
    final imageUrl = (checkin['imageUrl'] ?? '').toString();
    final feeling = (checkin['feeling'] ?? '').toString();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: Color(0xFF0F5B49), size: 19),
              SizedBox(width: 7),
              Text('Bạn đã ghé thăm',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 5),
            Text('${date.day}/${date.month}/${date.year}',
                style: const TextStyle(color: Colors.black54)),
          ],
          if (imageUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AppImage(
                source: imageUrl,
                width: double.infinity,
                height: 170,
                fallbackIcon: Icons.location_city_outlined,
              ),
            ),
          ],
          if (feeling.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(feeling),
          ],
        ],
      ),
    );
  }

  Future<void> _writeReview() async {
    final signedIn = await requestAccountAccess(context);
    if (!signedIn || !mounted) return;
    final commentController = TextEditingController(
      text: _myReview?['isHidden'] == true
          ? ''
          : (_myReview?['comment'] ?? '').toString(),
    );
    var rating = int.tryParse((_myReview?['rating'] ?? 5).toString()) ?? 5;
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Đánh giá địa điểm'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  onPressed: () => setDialogState(() => rating = index + 1),
                  icon: Icon(
                    index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    color: const Color(0xFFB83B26),
                  ),
                )),
              ),
              TextField(
                controller: commentController,
                maxLength: 2000,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: AppTranslations.translate('Chia sẻ trải nghiệm của bạn'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Gửi đánh giá'),
            ),
          ],
        ),
      ),
    );
    if (shouldSave != true || !mounted) {
      commentController.dispose();
      return;
    }
    final token = userSession.token;
    if (token == null) {
      commentController.dispose();
      return;
    }
    setState(() => _isLoadingReview = true);
    final api = AuthApiService();
    try {
      await api.saveReview(
        token: token,
        placeId: widget.place.id,
        placeName: widget.place.name,
        rating: rating,
        comment: commentController.text,
      );
      await _loadMyReview();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu đánh giá của bạn.')),
        );
      }
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lưu đánh giá lúc này.')),
        );
      }
    } finally {
      api.close();
      commentController.dispose();
      if (mounted) setState(() => _isLoadingReview = false);
    }
  }

  Future<void> _fetchWeather() async {
    final latitude = widget.place.latitude;
    final longitude = widget.place.longitude;
    if (latitude == null || longitude == null) {
      if (mounted) setState(() => _isLoadingWeather = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'http://103.82.26.171:8080/api/weather?lat=$latitude&lng=$longitude',
        ),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _weather = jsonDecode(response.body);
            _isLoadingWeather = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingWeather = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final latitude = widget.place.latitude;
    final longitude = widget.place.longitude;
    final hasCoordinates = latitude != null && longitude != null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Nền kem VN Guide
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(widget.place.name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh danh lam
            AppImage(
              source: widget.place.imageUrl,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
              fallbackIcon: Icons.location_city_outlined,
              fallbackIconSize: 56,
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tên + Badge thời tiết 29°C
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.place.name,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.place.address} • ★ 4.8 (1,2k)',
                              style: const TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Text(
                          _isLoadingWeather
                              ? '...'
                              : _weather != null
                                  ? '${_weather!['temperature']}°C'
                                  : '29°C',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Trình phát thuyết minh đọc nội dung tiếng Việt của địa điểm.
                  _buildNarrationPlayer(),

                  const SizedBox(height: 16),

                  // GIỜ MỞ CỬA & VÉ
                  const Text(
                    'Giờ mở cửa: 07:00–21:00  •  Vé: 120.000đ',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F5B49), fontSize: 14),
                  ),

                  const SizedBox(height: 12),

Text(
  widget.place.history.isNotEmpty
      ? widget.place.history
      : 'Chưa có thông tin lịch sử chi tiết cho địa điểm này.',
  style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
),

const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checkIn,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Check-in tại địa điểm này'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F5B49),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                  if (_myCheckin != null) ...[
                    const SizedBox(height: 12),
                    _checkinSummary(_myCheckin!),
                  ],

                  const SizedBox(height: 8),

                  // MỤC ĐÁNH GIÁ (B3)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Đánh giá', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      TextButton(
                        onPressed: _isLoadingReview ? null : _writeReview,
                        child: Text(
                          _myReview == null
                              ? 'Viết đánh giá'
                              : _myReview?['isHidden'] == true
                                  ? 'Gửi lại đánh giá'
                                  : 'Sửa đánh giá',
                          style: const TextStyle(color: Color(0xFFB83B26), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: _myReview == null
                        ? const Text(
                            'Chưa có đánh giá của bạn cho địa điểm này.',
                            style: TextStyle(color: Colors.black54),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userSession.fullName?.isNotEmpty == true
                                          ? userSession.fullName!
                                          : userSession.username ?? 'Bạn',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _myReview?['isHidden'] == true
                                          ? 'Đánh giá này đã bị quản trị viên tắt.'
                                          : (_myReview?['comment'] ?? '').toString(),
                                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '★ ${_myReview?['rating'] ?? 0}',
                                style: const TextStyle(color: Color(0xFFB83B26), fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB83B26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: hasCoordinates
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapScreen(
                                    title: widget.place.name,
                                    latitude: latitude,
                                    longitude: longitude,
                                  ),
                                ),
                              );
                            }
                          : null,
                      child: const Text(
                        'Chỉ đường',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
