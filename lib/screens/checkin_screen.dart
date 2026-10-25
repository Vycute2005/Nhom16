import 'package:file_picker/file_picker.dart';
import 'package:hcm_explorer/widgets/app_ui.dart';

import '../models/tourist_place.dart';
import '../services/auth_api_service.dart';
import '../services/favorites_store.dart';
import '../services/upload_service.dart';
import '../widgets/app_image.dart';
import 'account_access_screen.dart';

const Color _checkinGreen = Color(0xFF0F5B49);
const Color _checkinBorder = Color(0xFFE8DED0);

class CheckinCreateScreen extends StatefulWidget {
  const CheckinCreateScreen({super.key, required this.place});

  final TouristPlace place;

  @override
  State<CheckinCreateScreen> createState() => _CheckinCreateScreenState();
}

class _CheckinCreateScreenState extends State<CheckinCreateScreen> with AppLocaleAwareState<CheckinCreateScreen> {
  final _feelingController = TextEditingController();
  DateTime _visitedAt = DateTime.now();
  String _imageUrl = '';
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _feelingController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitedAt.isAfter(today) ? today : _visitedAt,
      firstDate: DateTime(1980),
      lastDate: today,
      helpText: 'Chọn ngày bạn đã ghé thăm',
    );
    if (picked != null && mounted) {
      setState(() => _visitedAt = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickPhoto() async {
    if (_isUploading) return;
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      const maxPhotoBytes = 8 * 1024 * 1024;
      final fileSize = await file.length();
      if (fileSize != null && fileSize > maxPhotoBytes) {
        throw Exception('Ảnh cần nhỏ hơn 8 MB.');
      }
      if (!mounted) return;
      setState(() => _isUploading = true);
      final bytes = await file.readAsBytes();
      if (bytes.length > maxPhotoBytes) {
        throw Exception('Ảnh cần nhỏ hơn 8 MB.');
      }
      final path = await UploadService().uploadImage(
        bytes: bytes,
        fileName: file.name,
        folder: 'checkins',
      );
      if (mounted) setState(() => _imageUrl = path);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không tải được ảnh check-in: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _save() async {
    final feeling = _feelingController.text.trim();
    if (_imageUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy thêm ảnh để xác nhận chuyến ghé thăm.')),
      );
      return;
    }
    if (feeling.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy viết vài dòng cảm nhận trước khi lưu.')),
      );
      return;
    }
    if (_isSaving || _isUploading) return;

    final signedIn = await requestAccountAccess(context);
    if (!signedIn || !mounted) return;
    final token = userSession.token;
    if (token == null || token.isEmpty) return;

    setState(() => _isSaving = true);
    final api = AuthApiService();
    try {
      final result = await api.createCheckin(
        token: token,
        placeId: widget.place.id,
        placeName: widget.place.name,
        visitedAt: _visitedAt,
        imageUrl: _imageUrl,
        feeling: feeling,
      );
      final rawCheckin = result['checkin'];
      if (!mounted) return;
      Navigator.pop<Map<String, dynamic>>(
        context,
        rawCheckin is Map
            ? Map<String, dynamic>.from(rawCheckin)
            : <String, dynamic>{
                'placeId': widget.place.id,
                'placeName': widget.place.name,
                'checkedInAt': _visitedAt.toIso8601String(),
                'imageUrl': _imageUrl,
                'feeling': feeling,
              },
      );
    } on AuthApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không lưu được check-in: $error')),
        );
      }
    } finally {
      api.close();
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _formattedDate =>
      '${_visitedAt.day.toString().padLeft(2, '0')}/${_visitedAt.month.toString().padLeft(2, '0')}/${_visitedAt.year}';

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Check-in địa điểm'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _checkinBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, color: _checkinGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.place.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (widget.place.address.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(widget.place.address,
                                style: const TextStyle(color: Colors.black54)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text('Ngày ghé thăm',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_formattedDate),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _checkinGreen,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                  side: const BorderSide(color: _checkinBorder),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(
                    child: Text('Ảnh chuyến ghé thăm',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton.icon(
                    onPressed: _isUploading ? null : _pickPhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(_imageUrl.isEmpty ? 'Thêm ảnh' : 'Đổi ảnh'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _isUploading
                    ? const SizedBox(
                        height: 190,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _imageUrl.isEmpty
                        ? Container(
                            height: 190,
                            color: const Color(0xFFE9EEEA),
                            alignment: Alignment.center,
                            child: const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 42, color: _checkinGreen),
                                SizedBox(height: 6),
                                Text('Thêm ảnh ghi lại chuyến đi'),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              AppImage(
                                source: _imageUrl,
                                width: double.infinity,
                                height: 220,
                                fallbackIcon: Icons.image_outlined,
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: IconButton.filledTonal(
                                  tooltip: AppTranslations.translate('Xóa ảnh'),
                                  onPressed: () => setState(() => _imageUrl = ''),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
              ),
              const SizedBox(height: 18),
              const Text('Cảm nhận của bạn',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _feelingController,
                maxLength: 2000,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: AppTranslations.translate('Bạn đã trải nghiệm gì ở đây?'),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _checkinBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _checkinBorder),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSaving || _isUploading ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _checkinGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isSaving ? 'Đang lưu...' : 'Xác nhận check-in'),
                ),
              ),
            ],
          ),
        ),
      );
}
