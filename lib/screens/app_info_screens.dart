import 'dart:convert';

import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

const _supportEmail = 'letuongvy03082005@gmail.com';
const _brandGreen = Color(0xFF0F5B49);

class AboutVNGuideScreen extends StatelessWidget {
  const AboutVNGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Giới thiệu VN Guide')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _brandGreen,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.travel_explore, color: Colors.white, size: 34),
                SizedBox(height: 14),
                Text(
                  'Khám phá Việt Nam – Trọn vẹn từng hành trình',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'VN Guide là ứng dụng cẩm nang du lịch giúp bạn khám phá vẻ đẹp thiên nhiên, danh lam thắng cảnh, văn hóa và ẩm thực đặc sắc của Việt Nam.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Khám phá những trải nghiệm nổi bật',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          const _AboutFeature(
            icon: Icons.landscape_outlined,
            title: 'Danh lam thắng cảnh',
            description: 'Tìm hiểu các địa điểm du lịch theo vùng miền và tỉnh thành.',
          ),
          const _AboutFeature(
            icon: Icons.restaurant_outlined,
            title: 'Ẩm thực Việt Nam',
            description: 'Khám phá món ngon, đặc sản địa phương và quán ăn.',
          ),
          const _AboutFeature(
            icon: Icons.diversity_3_outlined,
            title: 'Văn hóa địa phương',
            description: 'Tìm hiểu ca dao, tục ngữ, tiếng địa phương và lễ hội truyền thống.',
          ),
          const _AboutFeature(
            icon: Icons.route_outlined,
            title: 'Lập lịch trình',
            description: 'Tham khảo lịch trình mẫu và tạo kế hoạch theo sở thích.',
          ),
          const _AboutFeature(
            icon: Icons.tour_outlined,
            title: 'Tiện ích du lịch',
            description: 'Tra cứu thời tiết, quy đổi tiền tệ và tìm thông tin hỗ trợ cần thiết.',
          ),
          const SizedBox(height: 14),
          _InfoSection(
            title: 'Sứ mệnh của VN Guide',
            child: Text(
              'VN Guide mong muốn giúp việc khám phá Việt Nam trở nên thuận tiện, gần gũi và thú vị hơn, đồng thời góp phần giới thiệu những giá trị văn hóa, du lịch và ẩm thực đặc sắc đến với mọi người.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              children: [
                Text(
                  'VN Guide – Đi để khám phá, trải nghiệm để yêu Việt Nam hơn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _brandGreen,
                    fontWeight: FontWeight.bold,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: 10),
                Text('Phiên bản: 1.0.0'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ContactVNGuideScreen extends StatefulWidget {
  const ContactVNGuideScreen({super.key});

  @override
  State<ContactVNGuideScreen> createState() => _ContactVNGuideScreenState();
}

class _ContactVNGuideScreenState extends State<ContactVNGuideScreen> with AppLocaleAwareState<ContactVNGuideScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liên hệ VN Guide')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Text(
              'Chúng tôi luôn lắng nghe ý kiến của bạn!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn có câu hỏi, góp ý hoặc phát hiện thông tin du lịch chưa chính xác? Hãy liên hệ với nhóm VN Guide để giúp ứng dụng ngày càng hoàn thiện hơn.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            const _InfoSection(
              title: 'Bạn cần hỗ trợ về vấn đề gì?',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContactTopic(title: 'Góp ý ứng dụng', description: 'Đề xuất tính năng hoặc cải thiện giao diện.'),
                  _ContactTopic(title: 'Báo lỗi', description: 'Thông báo lỗi khi sử dụng ứng dụng.'),
                  _ContactTopic(title: 'Thông tin du lịch', description: 'Đề xuất cập nhật địa điểm, món ăn, lễ hội hoặc thông tin văn hóa.'),
                  _ContactTopic(title: 'Hợp tác và đóng góp', description: 'Chia sẻ dữ liệu, hình ảnh hoặc kiến thức hữu ích về du lịch Việt Nam.'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Gửi phản hồi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Vui lòng cung cấp thông tin để nhóm có thể tiếp nhận và xem xét phản hồi của bạn.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _nameController,
              label: 'Họ và tên',
              validator: _requiredValidator,
            ),
            _inputField(
              controller: _emailController,
              label: 'Email liên hệ',
              keyboardType: TextInputType.emailAddress,
              validator: _emailValidator,
            ),
            _inputField(
              controller: _subjectController,
              label: 'Chủ đề',
              validator: _requiredValidator,
            ),
            _inputField(
              controller: _messageController,
              label: 'Nội dung góp ý',
              maxLines: 5,
              validator: _requiredValidator,
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: _isSending ? null : _sendFeedback,
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(_isSending ? 'Đang gửi...' : 'Gửi phản hồi qua email'),
              style: FilledButton.styleFrom(
                backgroundColor: _brandGreen,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 18),
            _InfoSection(
              title: 'Thông tin liên hệ',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Email hỗ trợ'),
                  const SelectableText(
                    _supportEmail,
                    style: TextStyle(
                      color: _brandGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Thời gian tiếp nhận: buổi sáng 8–11h, buổi chiều 14h–16h30 (trừ thứ Bảy và Chủ nhật).',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Center(child: Text('Cảm ơn bạn đã đồng hành cùng VN Guide!')),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) => AppTranslations.translateValidation(validator.call(value)),
        decoration: InputDecoration(
          labelText: AppTranslations.translate(label),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppTranslations.translate('Vui lòng nhập thông tin này.');
    return null;
  }

  String? _emailValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) return requiredError;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value!.trim())) {
      return AppTranslations.translate('Vui lòng nhập email hợp lệ.');
    }
    return null;
  }

  Future<void> _sendFeedback() async {
    if (_isSending || !_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    var sent = false;
    var resultMessage = 'Không kết nối được máy chủ. Vui lòng thử lại sau.';

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/contact'),
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'name': _nameController.text.trim(),
              'email': _emailController.text.trim(),
              'subject': _subjectController.text.trim(),
              'message': _messageController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        sent = true;
        resultMessage = 'Đã gửi phản hồi. Bạn có thể trả lời email nhận được để liên hệ lại.';
      } else if (response.statusCode == 404) {
        resultMessage = 'Backend chưa có API liên hệ mới. Hãy cập nhật và khởi động lại backend.';
      } else {
        try {
          final payload = jsonDecode(response.body);
          if (payload is Map && payload['message'] is String) {
            resultMessage = payload['message'] as String;
          } else {
            resultMessage = 'Chưa gửi được phản hồi. Vui lòng thử lại sau.';
          }
        } on FormatException {
          resultMessage = 'Chưa gửi được phản hồi. Vui lòng thử lại sau.';
        }
      }
    } catch (_) {
      resultMessage = 'Không kết nối được máy chủ. Vui lòng thử lại sau.';
    }

    if (!mounted) return;
    setState(() => _isSending = false);
    if (sent) {
      _nameController.clear();
      _emailController.clear();
      _subjectController.clear();
      _messageController.clear();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resultMessage),
        backgroundColor: sent ? _brandGreen : Theme.of(context).colorScheme.error,
      ),
    );
  }
}

class _AboutFeature extends StatelessWidget {
  const _AboutFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _brandGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ContactTopic extends StatelessWidget {
  const _ContactTopic({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: RichText(
          text: TextSpan(
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.45,
            ),
            children: [
              TextSpan(
                text: AppTranslations.translate(title) + ': ',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: AppTranslations.translate(description)),
            ],
          ),
        ),
      );
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );
}