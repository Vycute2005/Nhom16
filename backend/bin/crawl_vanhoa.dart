import 'dart:convert';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:html/parser.dart' show parse;

// Hàm tự động tạo URL đọc phát âm tiếng Việt (Google TTS)
String generateAudioUrl(String text) {
  final cleanText = text.length > 80 ? text.substring(0, 80) : text;
  final encodedText = Uri.encodeComponent(cleanText);
  return 'https://translate.google.com/translate_tts?ie=UTF-8&q=$encodedText&tl=vi&client=tw-ob';
}

void main() async {
  print(
    '🚀 Bắt đầu cào dữ liệu Tiếng lóng & Văn hóa (Puppeteer + Audio TTS)...',
  );

  List<Map<String, dynamic>> resultList = [];
  Browser? browser;

  try {
    browser = await puppeteer.launch(headless: true);
    final page = await browser.newPage();
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    );

    // 1. CÀO NGHENGU.VN
    print('Đang truy cập Nghengu.vn...');
    try {
      await page.goto(
        'https://nghengu.vn/',
        wait: Until.networkIdle,
        timeout: const Duration(seconds: 25),
      );
      final content = await page.content;
      final document = parse(content);

      final items = document.querySelectorAll(
        'article, .post-item, .entry-title',
      );
      for (var item in items) {
        final term = item.querySelector('a, h2, h3')?.text.trim() ?? '';
        final meaning =
            item.querySelector('.entry-excerpt, p')?.text.trim() ??
            'Tiếng lóng & từ ngữ Nam Bộ';

        if (term.isNotEmpty &&
            term.length < 60 &&
            !resultList.any((e) => e['term'] == term)) {
          resultList.add({
            'term': term,
            'meaning': meaning.isEmpty
                ? 'Từ ngữ địa phương đặc trưng Sài Gòn'
                : meaning,
            'audio_url': generateAudioUrl(term), // <--- CHÈN LINK AUDIO PHÁT ÂM
            'context': 'Tiếng lóng Nam Bộ',
          });
        }
      }
    } catch (e) {
      print('⚠️ Không tải được Nghengu.vn ($e), chuyển sang nguồn khác...');
    }

    // 2. CÀO BÁO TUỔI TRẺ (VĂN HÓA)
    print('Đang truy cập Báo Tuổi Trẻ Văn Hóa...');
    try {
      await page.goto(
        'https://tuoitre.vn/van-hoa.htm',
        wait: Until.domContentLoaded,
        timeout: const Duration(seconds: 25),
      );
      final content = await page.content;
      final document = parse(content);

      final articles = document.querySelectorAll(
        '.box-category-item, .title-news',
      );
      for (var article in articles) {
        final title =
            article.querySelector('.box-category-link-title')?.text.trim() ??
            article.querySelector('a')?.text.trim() ??
            '';
        final desc =
            article.querySelector('.box-category-sapo, p')?.text.trim() ??
            'Nét đẹp văn hóa và nếp sống Sài Gòn';

        if (title.isNotEmpty &&
            title.length < 80 &&
            !resultList.any((e) => e['term'] == title)) {
          resultList.add({
            'term': title,
            'meaning': desc,
            'audio_url': generateAudioUrl(
              title,
            ), // <--- CHÈN LINK AUDIO PHÁT ÂM
            'context': 'Văn hóa Sài Gòn (Tuổi Trẻ)',
          });
        }
      }
    } catch (e) {
      print('⚠️ Không tải được TuoiTre ($e)...');
    }
  } catch (e) {
    print('❌ Lỗi trình duyệt Puppeteer: $e');
  } finally {
    await browser?.close();
  }

  // 3. BỘ DỮ LIỆU CHUẨN DỰ PHÒNG (Đảm bảo JSON luôn có dữ liệu tiếng lóng Sài Gòn chất lượng)
  if (resultList.length < 5) {
    print('💡 Đang nạp danh sách từ lóng Sài Gòn đặc trưng làm dữ liệu nền...');
    final sampleSlangs = [
      {
        'term': 'Ủa',
        'meaning':
            'Từ cảm thán cửa miệng phổ biến nhất Sài Gòn thể hiện sự bất ngờ.',
        'context': 'Tiếng lóng Sài Gòn',
      },
      {
        'term': 'Thèo lèo',
        'meaning': 'Tên gọi kẹo đậu phụng (lạc) ngọt bùi đặc trưng.',
        'context': 'Tiếng lóng Nam Bộ',
      },
      {
        'term': 'Chơi xả láng',
        'meaning': 'Thoải mái hết mình, không tính toán hay lo nghĩ.',
        'context': 'Tiếng lóng Sài Gòn',
      },
      {
        'term': 'Cà phê bệt',
        'meaning': 'Văn hóa thưởng thức cà phê ngồi thảm/báo ở công viên.',
        'context': 'Nếp sống Sài Gòn',
      },
      {
        'term': 'Hẻm Sài Gòn',
        'meaning': 'Không gian sinh hoạt cộng đồng ấm áp tình người làng phố.',
        'context': 'Văn hóa Sài Gòn',
      },
      {
        'term': 'Hết nước chấm',
        'meaning': 'Khen ngợi điều gì đó quá xuất sắc, không còn gì để chê.',
        'context': 'Tiếng lóng Giới trẻ',
      },
      {
        'term': 'Táp-lô',
        'meaning':
            'Từ mượn tiếng Pháp chỉ bảng điều khiển hoặc đồ vật gắn liền.',
        'context': 'Từ ngữ Sài Gòn xưa',
      },
    ];

    for (var item in sampleSlangs) {
      if (!resultList.any((e) => e['term'] == item['term'])) {
        resultList.add({
          'term': item['term']!,
          'meaning': item['meaning']!,
          'audio_url': generateAudioUrl(item['term']!),
          'context': item['context']!,
        });
      }
    }
  }

  // 4. XUẤT FILE JSON
  final directory = Directory('assets/data');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final outputFile = File('assets/data/slangs.json');
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(resultList),
  );

  print(
    '🎉 Đã hoàn tất! Cào được ${resultList.length} từ (đã gắn link Audio TTS) vào assets/data/slangs.json',
  );
}
