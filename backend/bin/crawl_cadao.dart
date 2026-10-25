import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

Future<void> main() async {
  // Cấu hình các danh mục cần cào trên ca-dao.com
  final categoriesToCrawl = [
    {
      'url': 'https://ca-dao.com/danh-muc/ca-dao-ve-van-hoa',
      'type': 'Ca dao',
      'category': 'Văn hóa & Phong tục',
      'meaning': 'Bài ca dao thể hiện nét đẹp văn hóa, lễ nghi và phong tục tập quán truyền thống của người Việt.'
    },
    {
      'url': 'https://ca-dao.com/danh-muc/ca-dao-ve-hoc-tap',
      'type': 'Ca dao',
      'category': 'Lòng biết ơn & Rèn luyện',
      'meaning': 'Khuyên nhủ về tinh thần hiếu học, tôn sư trọng đạo và lòng biết ơn công lao sinh thành, dưỡng dục.'
    },
    {
      'url': 'https://ca-dao.com/danh-muc/tuc-ngu',
      'type': 'Tục ngữ',
      'category': 'Kinh nghiệm dân gian',
      'meaning': 'Đúc kết kinh nghiệm sống, triết lý ứng xử và kinh nghiệm sản xuất nông nghiệp của dân tộc.'
    }
  ];

  List<Map<String, String>> resultList = [];

  for (var target in categoriesToCrawl) {
    print('🌐 Đang cào [${target['type']}] - Chủ đề: ${target['category']}...');

    try {
      final response = await http.get(Uri.parse(target['url']!));
      if (response.statusCode != 200) continue;

      var document = html_parser.parse(response.body);
      var links = document.querySelectorAll('a');

      for (var link in links) {
        String text = link.text.trim();

        if (text.length > 8 &&
            !text.contains('Trang chủ') &&
            !text.contains('Thể loại') &&
            !text.contains('Tìm kiếm') &&
            !text.contains('Về chúng tôi') &&
            !text.contains('Xem tất cả')) {
          resultList.add({
            'type': target['type']!,
            'category': target['category']!,
            'content': text,
            'meaning': target['meaning']!,
            'source': target['url']!,
          });
        }
      }
    } catch (e) {
      print('❌ Lỗi khi cào ${target['url']}: $e');
    }
  }

  // Lưu dữ liệu vào file backend/data/cadao_vanhoa.json
  final dataDir = Directory('data');
  if (!await dataDir.exists()) await dataDir.create(recursive: true);

  final jsonFile = File('data/cadao_vanhoa.json');
  await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(resultList));

  print('\n==================================================');
  print('✅ ĐÃ CÀO THÀNH CÔNG ${resultList.length} BẢN GHI!');
  print('📁 File dữ liệu được tạo tại: backend/data/cadao_vanhoa.json');
  print('==================================================');
}