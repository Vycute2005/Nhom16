import 'dart:convert';
import 'dart:io';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

void main() async {
  print('Đang cào dữ liệu phương ngữ 3 miền từ Quantrimang...');
  final url = Uri.parse('https://quantrimang.com/cuoc-song/su-khac-nhau-trong-ngon-ngu-bac-nam-177473');

  try {
    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    );

    if (response.statusCode != 200) {
      print('Lỗi tải trang: Mã ${response.statusCode}');
      return;
    }

    // Sử dụng utf8.decode để tránh lỗi phông chữ tiếng Việt
    final htmlContent = utf8.decode(response.bodyBytes);
    final document = html_parser.parse(htmlContent);
    final List<Map<String, String>> phrasesList = [];

    final tables = document.querySelectorAll('table');
    for (var table in tables) {
      final rows = table.querySelectorAll('tr');
      for (var row in rows) {
        final cols = row.querySelectorAll('td, th');
        if (cols.isEmpty) continue;

        final cellTexts = cols.map((c) => c.text.trim()).toList();
        final firstCell = cellTexts[0];

        // Bỏ qua các hàng tiêu đề
        if (firstCell.contains('STT') ||
            firstCell.contains('Miền Bắc') ||
            firstCell.contains('Từ ngữ') ||
            firstCell.isEmpty) {
          continue;
        }

        String meaning = '';
        String north = '';
        String central = '';
        String south = '';

        // Tự động phân loại cấu trúc số cột của bảng
        if (cellTexts.length >= 4) {
          // Bảng 4 cột: [Từ ngữ/Nghĩa, Miền Bắc, Miền Trung, Miền Nam]
          meaning = cellTexts[0];
          north = cellTexts[1];
          central = cellTexts[2];
          south = cellTexts[3];
        } else if (cellTexts.length == 3) {
          // Bảng 3 cột: [Từ ngữ/Nghĩa, Miền Bắc, Miền Nam]
          meaning = cellTexts[0];
          north = cellTexts[1];
          central = cellTexts[1]; // Mặc định gán bằng miền Bắc nếu không có cột miền Trung
          south = cellTexts[2];
        } else if (cellTexts.length == 2) {
          // Bảng 2 cột: [Miền Bắc, Miền Nam]
          meaning = cellTexts[0];
          north = cellTexts[0];
          central = cellTexts[0];
          south = cellTexts[1];
        }

        if (north.isNotEmpty || south.isNotEmpty) {
          phrasesList.add({
            'category': 'Phương ngữ 3 miền',
            'meaning': meaning,
            'north_word': north,
            'central_word': central,
            'south_word': south,
          });
        }
      }
    }

    // GHI RA FILE JSON VỚI ĐỊNH DẠNG ĐẸP
    final file = File('phrases.json');
    final jsonString = const JsonEncoder.withIndent('  ').convert(phrasesList);
    await file.writeAsString(jsonString, encoding: utf8);

    print('Thành công! Đã lưu ${phrasesList.length} cặp từ phương ngữ vào file: phrases.json');
  } catch (e) {
    print('Lỗi cào dữ liệu: $e');
  }
}