import 'package:hcm_explorer/widgets/app_ui.dart';

class CultureDetailScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String meaningDetail;

  const CultureDetailScreen({
    Key? key,
    required this.title,
    required this.subtitle,
    required this.meaningDetail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Màu nền be sáng
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Ý nghĩa câu nói',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: Colors.grey.shade200), // Đã sửa BorderSide thành Border.all
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05), // Dùng withValues thay cho withOpacity
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ],
),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, color: Color(0xFF1B6A5B), size: 40),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B6A5B), height: 1.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(),
                  ),
                  const Text(
                    'Giải nghĩa chi tiết:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    meaningDetail,
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.6),
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