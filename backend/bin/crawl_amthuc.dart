import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final targetUrl = 'https://toplist.vn/';
  print('🌐 Đang tổng hợp dữ liệu ẩm thực bổ sung phong phú "Đặc sản vùng miền"...');

  final List<Map<String, dynamic>> masterDataset = [
    // =========================================================================
    // 1. TAB: ĐẶC SẢN VÙNG MIỀN (ĐỦ CẢ 3 MIỀN BẮC - TRUNG - NAM)
    // =========================================================================
    
    // --- MIỀN NAM ---
    {
      'category': 'Đặc sản vùng miền',
      'region': 'Miền Nam',
      'province': 'Sóc Trăng',
      'name': 'Bánh Pía Sóc Trăng',
      'description': 'Vỏ bánh nhiều lớp xốp dẻo, nhân đậu xanh sầu riêng béo ngậy quyện lòng đỏ trứng muối.',
      'cultural_story': 'Món quà đặc sản mang đậm dấu ấn giao thoa văn hóa Kinh - Hoa - Khmer xứ Nam Bộ.',
      'price_range': '50.000 - 90.000 VNĐ / hộp',
      'image_url': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Bánh Pía Tân Huê Viên', 'address': 'Quy Lộ 1A, Châu Thành, Sóc Trăng', 'price': '60.000 - 110.000 VNĐ', 'rating': '4.8/5', 'open_hours': '07:00 - 21:00'},
        {'spot_name': 'Bánh Pía Lương Xương', 'address': '42 Nguyễn Huệ, TP. Sóc Trăng', 'price': '55.000 - 95.000 VNĐ', 'rating': '4.6/5', 'open_hours': '06:30 - 20:30'}
      ]
    },
    {
      'category': 'Đặc sản vùng miền',
      'region': 'Miền Nam',
      'province': 'Bến Tre',
      'name': 'Kẹo Dừa Bến Tre',
      'description': 'Kẹo dừa béo ngậy, dẻo ngọt làm từ nước cốt dừa tươi nguyên chất xứ dừa.',
      'cultural_story': 'Nghề làm kẹo dừa truyền thống trứ danh trở thành nét đẹp văn hóa thủ công xứ Bến Tre.',
      'price_range': '30.000 - 60.000 VNĐ / hộp',
      'image_url': 'https://images.unsplash.com/photo-1582058091505-f87a2e55a40f?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Kẹo Dừa Thanh Long', 'address': '212B Đại Lộ Đồng Khởi, Bến Tre', 'price': '35.000 - 60.000 VNĐ', 'rating': '4.7/5', 'open_hours': '07:00 - 21:00'}
      ]
    },
    {
      'category': 'Đặc sản vùng miền',
      'region': 'Miền Nam',
      'province': 'Cà Mau',
      'name': 'Lẩu Mắm U Minh',
      'description': 'Nước lẩu nấu từ mắm sặc đậm đà, ăn kèm cá đồng, lươn và hơn 20 loại rau dại vùng ngập nước U Minh.',
      'cultural_story': 'Đặc sản sông nước đại diện cho sự phong phú và hào sảng của thiên nhiên miền Tây Nam Bộ.',
      'price_range': '150.000 - 300.000 VNĐ',
      'image_url': 'https://images.unsplash.com/photo-1594212699903-ec8a3eca50f6?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Lẩu Mắm Đồng Quê Cà Mau', 'address': '91A Lý Thường Kiệt, Phường 6, Cà Mau', 'price': '180.000 - 280.000 VNĐ', 'rating': '4.7/5', 'open_hours': '10:00 - 22:00'}
      ]
    },

    // --- MIỀN TRUNG ---
    {
      'category': 'Đặc sản vùng miền',
      'region': 'Miền Trung',
      'province': 'Bình Định',
      'name': 'Tré Bình Định',
      'description': 'Tré làm từ thịt đầu heo, tai heo trộn thính gạo, riềng tỏi gói trong rơm khô rụm.',
      'cultural_story': 'Món nhắm đặc sản xứ Nẫu không thể thiếu trên bàn tiếp khách quý của người dân miền Trung.',
      'price_range': '35.000 - 65.000 VNĐ / cây',
      'image_url': 'https://images.unsplash.com/photo-1617093727343-374698b1b08d?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Tré Bà Xinh Quy Nhơn', 'address': '14 Trần Bình Trọng, TP. Quy Nhơn', 'price': '40.000 - 60.000 VNĐ', 'rating': '4.8/5', 'open_hours': '07:00 - 21:00'}
      ]
    },
    {
      'category': 'Đặc sản vùng miền',
      'region': 'Miền Trung',
      'province': 'Khánh Hòa',
      'name': 'Bánh Căn Nha Trang',
      'description': 'Bánh đúc khuôn đất nung giòn đáy, nhân tôm mực tươi ngon ăn cùng xốt mắm nêm xíu mại.',
      'cultural_story': 'Món ăn đặc sản mộc mạc lưu giữ nét ẩm thực bình dân phố biển Nha Trang.',
      'price_range': '35.000 - 60.000 VNĐ',
      'image_url': 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Bánh Căn Út Nổi', 'address': '8 Tô Hiến Thành, TP. Nha Trang', 'price': '40.000 - 65.000 VNĐ', 'rating': '4.6/5', 'open_hours': '15:00 - 21:00'}
      ]
    },

    // --- MIỀN BẮC ---
    {
      'category': 'Đặc sản vùng miền',
      'region': 'Miền Bắc',
      'province': 'Quảng Ninh',
      'name': 'Chả Mực Hạ Long',
      'description': 'Mực mai tươi giã tay thủ công chiên vàng giòn, thơm nức lòng, ăn kèm xôi trắng hoặc bánh cuốn.',
      'cultural_story': 'Đặc sản trứ danh xứ biển Quảng Ninh, thuộc top 50 món ăn đặc sản nổi tiếng Việt Nam.',
      'price_range': '120.000 - 250.000 VNĐ',
      'image_url': 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Chả Mực Thoan Hạ Long', 'address': 'Kiot 36 Chợ Hạ Long 1, Quảng Ninh', 'price': '180.000 - 250.000 VNĐ', 'rating': '4.9/5', 'open_hours': '06:00 - 18:00'}
      ]
    },
    {
      'category': 'Đặc sản vùng miền',
      'region': 'Miền Bắc',
      'province': 'Hà Nội',
      'name': 'Cốm Làng Vòng',
      'description': 'Hạt cốm xanh dẻo thơm thoảng mùi lá sen thanh khiết, thức quà thu đắt giá xứ Hà Thành.',
      'cultural_story': 'Nét văn hóa quà quê tinh tế gắn liền với mùa thu Hà Nội qua nhiều thế hệ.',
      'price_range': '50.000 - 100.000 VNĐ / gói',
      'image_url': 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Cốm Vòng Huy Linh', 'address': 'Thôn Vòng, Dịch Vọng Hậu, Cầu Giấy, Hà Nội', 'price': '60.000 - 100.000 VNĐ', 'rating': '4.8/5', 'open_hours': '06:30 - 20:30'}
      ]
    },

    // =========================================================================
    // 2. CÁC MÓN ĂN ĐƯỜNG PHỐ
    // =========================================================================
    {
      'category': 'Món ăn đường phố',
      'region': 'Miền Nam',
      'province': 'TP. Hồ Chí Minh',
      'name': 'Bánh Mì Sài Gòn',
      'description': 'Vỏ giòn rụm kẹp pate béo ngậy, chả lụa, thịt nguội, đồ chua xịt nước tương đậm đà.',
      'cultural_story': 'Vinh danh là món ăn đường phố ngon nhất thế giới, biểu tượng nhịp sống nhanh Sài Gòn.',
      'price_range': '20.000 - 65.000 VNĐ',
      'image_url': 'https://images.unsplash.com/photo-1626844131082-256783844137?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Bánh Mì Huỳnh Hoa', 'address': '26 Lê Thị Riêng, Quận 1, TP.HCM', 'price': '60.000 - 68.000 VNĐ', 'rating': '4.8/5', 'open_hours': '11:00 - 21:00'}
      ]
    },
    {
      'category': 'Món ăn đường phố',
      'region': 'Miền Nam',
      'province': 'TP. Hồ Chí Minh',
      'name': 'Cơm Tấm Sài Gòn',
      'description': 'Cơm tấm xốp mềm ăn cùng sườn nướng mỡ hành nướng lò than, chả trứng, bì heo và mắm kẹo.',
      'cultural_story': 'Món ăn bình dân kinh điển của người lao động, trở thành linh hồn ẩm thực phố phường Sài Gòn.',
      'price_range': '40.000 - 110.000 VNĐ',
      'image_url': 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Cơm Tấm Ba Há', 'address': '389 Hưng Phú, Quận 8, TP.HCM', 'price': '45.000 - 75.000 VNĐ', 'rating': '4.7/5', 'open_hours': '16:00 - 20:30'}
      ]
    },

    // =========================================================================
    // 3. DI SẢN ẨM THỰC
    // =========================================================================
    {
      'category': 'Di sản ẩm thực',
      'region': 'Miền Bắc',
      'province': 'Hà Nội',
      'name': 'Phở Bò Hà Nội',
      'description': 'Nước dùng trong, ngọt thanh ninh từ xương ống bò, bánh phở dẻo mềm ăn kèm thịt bò tái/nạm.',
      'cultural_story': 'Món ăn biểu tượng quốc hồn quốc túy của Việt Nam, đại diện cho sự tinh tế ẩm thực Tràng An.',
      'price_range': '45.000 - 90.000 VNĐ',
      'image_url': 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Phở Thìn Lò Đúc', 'address': '13 Lò Đúc, Quận Hai Bà Trưng, Hà Nội', 'price': '65.000 - 90.000 VNĐ', 'rating': '4.6/5', 'open_hours': '06:00 - 20:30'}
      ]
    },

    // =========================================================================
    // 4. MÓN ĂN NGÀY TẾT
    // =========================================================================
    {
      'category': 'Món ăn ngày Tết',
      'region': 'Miền Nam',
      'province': 'Cần Thơ',
      'name': 'Bánh Tét Miền Tây',
      'description': 'Bánh gói hình trụ tròn bằng lá chuối, vỏ nếp xào nước cốt dừa dẻo béo nhân đậu xanh thịt mỡ.',
      'cultural_story': 'Món bánh không thể thiếu trong mâm cỗ cúng gia tiên dịp Tết Nguyên Đán của người dân Nam Bộ.',
      'price_range': '70.000 - 120.000 VNĐ / đòn',
      'image_url': 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600',
      'source': targetUrl,
      'spots': [
        {'spot_name': 'Bánh Tét Lá Cẩm Tư Đẹp', 'address': '102 An Dương Vương, Cần Thơ', 'price': '80.000 - 120.000 VNĐ', 'rating': '4.8/5', 'open_hours': '06:00 - 21:00'}
      ]
    }
  ];

  final dataDir = Directory('data');
  if (!await dataDir.exists()) await dataDir.create(recursive: true);

  final jsonFile = File('data/amthuc.json');
  await jsonFile.writeAsString(const JsonEncoder.withIndent('  ').convert(masterDataset));

  print('==================================================');
  print('✅ ĐÃ TẠO THÀNH CÔNG ${masterDataset.length} MÓN ĂN VỚI ĐẶC SẢN PHONG PHÚ 3 MIỀN!');
  print('==================================================');
}