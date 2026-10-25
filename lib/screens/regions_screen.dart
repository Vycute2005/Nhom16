import 'package:hcm_explorer/widgets/app_ui.dart';
import 'provinces_screen.dart';

class RegionsScreen extends StatelessWidget {
  const RegionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text('Khám phá vùng miền',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn vùng miền bạn muốn đến',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87),
            ),
            const SizedBox(height: 16),

            // 1. MIỀN BẮC
            _buildRegionCard(
              context,
              title: 'Miền Bắc',
              subtitle:
                  '15 Tỉnh thành • Hà Nội, Cao Bằng, Lào Cai, Quảng Ninh...',
              imageUrl:
                  'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=800',
              color: const Color(0xFF0F5B49),
            ),

            const SizedBox(height: 16),

            // 2. MIỀN TRUNG
            _buildRegionCard(
              context,
              title: 'Miền Trung',
              subtitle: '11 Tỉnh thành • Thanh Hóa, Huế, Đà Nẵng, Khánh Hòa...',
              imageUrl:
                  'https://images.unsplash.com/photo-1555939594-58d7cb561ad1?q=80&w=800',
              color: const Color(0xFFB83B26),
            ),

            const SizedBox(height: 16),

            // 3. MIỀN NAM
            _buildRegionCard(
              context,
              title: 'Miền Nam',
              subtitle: '8 Tỉnh thành • TP.HCM, Cần Thơ, An Giang, Cà Mau...',
              imageUrl:
                  'https://images.unsplash.com/photo-1583417319070-4a69db38a482?q=80&w=800',
              color: const Color(0xFFB58328),
            ),

            const SizedBox(height: 24),

            // NÚT XEM TOÀN BỘ 34 TỈNH THÀNH
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0F5B49), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26)),
                ),
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProvincesScreen()));
                },
                child: const Text(
                  'Xem tất cả 34 tỉnh/thành',
                  style: TextStyle(
                      color: Color(0xFF0F5B49),
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String imageUrl,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ProvincesScreen()));
      },
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                height: 140,
                fit: BoxFit.cover,
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
