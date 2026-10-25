import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dotenv/dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mysql1/mysql1.dart';
import 'package:jose/jose.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Authentication API for the VN Guide Dart/Shelf backend.
///
/// Register this with the EXISTING Router. It intentionally does not create a
/// second HTTP server, so existing endpoints such as /api/phrases remain intact.
class AuthApi {
  AuthApi({this._settings});

  ConnectionSettings? _settings;
  String? _googleClientId;

  DotEnv? _dotenv;

  String _setting(String key, [String fallback = '']) =>
      Platform.environment[key] ?? _dotenv?[key] ?? fallback;

  String get _jwtSecret => _setting(
    'JWT_SECRET',
    'LOCAL-ONLY-CHANGE-THIS-VN-GUIDE-JWT-SECRET-32-CHARS',
  );

  bool get _showDevelopmentOtp =>
      _setting('DEV_SHOW_OTP', 'false').toLowerCase() == 'true';

  bool get _smtpConfigured =>
      _setting('SMTP_GMAIL_ADDRESS').trim().isNotEmpty &&
      _setting('SMTP_GMAIL_APP_PASSWORD').trim().isNotEmpty;

  Future<T> _withDb<T>(Future<T> Function(MySqlConnection db) action) async {
    final db = await MySqlConnection.connect(_settings!);
    try {
      return await action(db);
    } finally {
      await db.close();
    }
  }

  /// Create auth tables and seed admin/admin once, without resetting its password
  /// on subsequent server starts. The admin credentials are for local coursework
  /// only; change the password before exposing this server to other people.
  Future<void> initialize() async {
    _dotenv = File('.env').existsSync() ? (DotEnv()..load()) : null;
    _googleClientId = _setting('GOOGLE_CLIENT_ID').trim();
    _settings ??= _loadSettings();
    await _withDb((db) async {
      await db.query('''
        CREATE TABLE IF NOT EXISTS users (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          username VARCHAR(50) NOT NULL UNIQUE,
          email VARCHAR(254) NOT NULL UNIQUE,
          full_name VARCHAR(120) NULL,
          avatar_url VARCHAR(1024) NULL,
          nationality VARCHAR(80) NULL,
          password_hash VARCHAR(255) NOT NULL,
          role ENUM('user', 'admin') NOT NULL DEFAULT 'user',
          is_active TINYINT(1) NOT NULL DEFAULT 1,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      final googleSubjectColumn = await db.query(
        "SHOW COLUMNS FROM users LIKE 'google_subject'",
      );
      if (googleSubjectColumn.isEmpty) {
        await db.query(
          'ALTER TABLE users ADD COLUMN google_subject VARCHAR(191) NULL UNIQUE AFTER email',
        );
      }

      final sessionVersionColumn = await db.query(
        "SHOW COLUMNS FROM users LIKE 'session_version'",
      );
      if (sessionVersionColumn.isEmpty) {
        await db.query(
          'ALTER TABLE users ADD COLUMN session_version INT UNSIGNED NOT NULL DEFAULT 0 AFTER is_active',
        );
      }

      final avatarColumn = await db.query(
        "SHOW COLUMNS FROM users LIKE 'avatar_url'",
      );
      if (avatarColumn.isEmpty) {
        await db.query(
          'ALTER TABLE users ADD COLUMN avatar_url VARCHAR(1024) NULL AFTER full_name',
        );
      }
      final nationalityColumn = await db.query(
        "SHOW COLUMNS FROM users LIKE 'nationality'",
      );
      if (nationalityColumn.isEmpty) {
        await db.query(
          'ALTER TABLE users ADD COLUMN nationality VARCHAR(80) NULL AFTER avatar_url',
        );
      }

      await db.query('''
        CREATE TABLE IF NOT EXISTS password_reset_otps (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT UNSIGNED NOT NULL UNIQUE,
          otp_hash CHAR(64) NOT NULL,
          expires_at DATETIME NOT NULL,
          attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          CONSTRAINT fk_password_reset_user
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      // Keep account favorites separate from the application's existing
      // `favorites` table, whose legacy schema may be different.
      await db.query('''
        CREATE TABLE IF NOT EXISTS user_favorites (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT UNSIGNED NOT NULL,
          item_type VARCHAR(50) NOT NULL,
          item_id VARCHAR(191) NOT NULL,
          title VARCHAR(255) NOT NULL DEFAULT '',
          subtitle TEXT NULL,
          image_url TEXT NULL,
          metadata_json LONGTEXT NULL,
          created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_user_favorites_user (user_id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      final favoriteTypeColumn = await db.query(
        "SHOW COLUMNS FROM user_favorites LIKE 'item_type'",
      );
      if (favoriteTypeColumn.isNotEmpty &&
          !(favoriteTypeColumn.first['Type'] ?? '')
              .toString()
              .toLowerCase()
              .startsWith('varchar')) {
        await db.query(
          'ALTER TABLE user_favorites MODIFY item_type VARCHAR(50) NOT NULL',
        );
      }

      final favoriteIdColumn = await db.query(
        "SHOW COLUMNS FROM user_favorites LIKE 'item_id'",
      );
      if (favoriteIdColumn.isNotEmpty &&
          !(favoriteIdColumn.first['Type'] ?? '')
              .toString()
              .toLowerCase()
              .startsWith('varchar')) {
        await db.query(
          'ALTER TABLE user_favorites MODIFY item_id VARCHAR(191) NOT NULL',
        );
      }

      final favoriteTitleColumn = await db.query(
        "SHOW COLUMNS FROM user_favorites LIKE 'title'",
      );
      if (favoriteTitleColumn.isEmpty) {
        await db.query(
          "ALTER TABLE user_favorites ADD COLUMN title VARCHAR(255) NOT NULL DEFAULT '' AFTER item_id",
        );
      }
      final favoriteSubtitleColumn = await db.query(
        "SHOW COLUMNS FROM user_favorites LIKE 'subtitle'",
      );
      if (favoriteSubtitleColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_favorites ADD COLUMN subtitle TEXT NULL AFTER title',
        );
      }
      final favoriteImageColumn = await db.query(
        "SHOW COLUMNS FROM user_favorites LIKE 'image_url'",
      );
      if (favoriteImageColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_favorites ADD COLUMN image_url TEXT NULL AFTER subtitle',
        );
      }
      final favoriteMetadataColumn = await db.query(
        "SHOW COLUMNS FROM user_favorites LIKE 'metadata_json'",
      );
      if (favoriteMetadataColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_favorites ADD COLUMN metadata_json LONGTEXT NULL AFTER image_url',
        );
      }
      final favoriteCreatedColumn = await db.query(
        "SHOW COLUMNS FROM user_favorites LIKE 'created_at'",
      );
      if (favoriteCreatedColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_favorites ADD COLUMN created_at TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP',
        );
      }

      // Import account favorites saved by the previous API implementation.
      final legacyFavoritesTable = await db.query(
        "SHOW TABLES LIKE 'favorites'",
      );
      if (legacyFavoritesTable.isNotEmpty) {
        final legacyColumns = await db.query('SHOW COLUMNS FROM favorites');
        final legacyColumnNames = legacyColumns
            .map((column) => column['Field'].toString())
            .toSet();
        if (legacyColumnNames.containsAll(<String>{
          'device_id',
          'item_type',
          'item_id',
          'title',
          'subtitle',
          'image_url',
          'created_at',
        })) {
          await db.query('''
            INSERT INTO user_favorites
              (user_id, item_type, item_id, title, subtitle, image_url, created_at)
            SELECT account.id, saved.item_type, saved.item_id, saved.title,
                   saved.subtitle, saved.image_url, saved.created_at
            FROM favorites AS saved
            INNER JOIN users AS account
              ON account.id = CAST(SUBSTRING_INDEX(saved.device_id, ':', -1) AS UNSIGNED)
            WHERE saved.device_id LIKE 'user:%'
              AND NOT EXISTS (
                SELECT 1 FROM user_favorites AS existing
                WHERE existing.user_id = account.id
                  AND existing.item_type = saved.item_type
                  AND existing.item_id = saved.item_id
              )
          ''');
        }
      }

      await db.query('''
        CREATE TABLE IF NOT EXISTS user_checkins (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT UNSIGNED NOT NULL,
          place_id VARCHAR(191) NOT NULL,
          place_name VARCHAR(255) NOT NULL,
          checked_in_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_user_checkins_user_date (user_id, checked_in_at),
          CONSTRAINT fk_checkin_user
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      final checkinVisitedColumn = await db.query(
        "SHOW COLUMNS FROM user_checkins LIKE 'visited_on'",
      );
      if (checkinVisitedColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_checkins ADD COLUMN visited_on DATE NULL AFTER place_name',
        );
      }
      final checkinImageColumn = await db.query(
        "SHOW COLUMNS FROM user_checkins LIKE 'image_url'",
      );
      if (checkinImageColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_checkins ADD COLUMN image_url TEXT NULL AFTER visited_on',
        );
      }
      final checkinFeelingColumn = await db.query(
        "SHOW COLUMNS FROM user_checkins LIKE 'feeling'",
      );
      if (checkinFeelingColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_checkins ADD COLUMN feeling TEXT NULL AFTER image_url',
        );
      }

      await db.query('''
        CREATE TABLE IF NOT EXISTS user_reviews (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT UNSIGNED NOT NULL,
          place_id VARCHAR(191) NOT NULL,
          place_name VARCHAR(255) NOT NULL,
          rating TINYINT UNSIGNED NOT NULL,
          comment TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          UNIQUE KEY uq_user_review_place (user_id, place_id),
          INDEX idx_user_reviews_user_date (user_id, created_at),
          CONSTRAINT fk_review_user
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');


      final reviewCreatedAtColumn = await db.query(
        "SHOW COLUMNS FROM user_reviews LIKE 'created_at'",
      );
      if (reviewCreatedAtColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_reviews ADD COLUMN created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP',
        );
      }

      final reviewUpdatedAtColumn = await db.query(
        "SHOW COLUMNS FROM user_reviews LIKE 'updated_at'",
      );
      if (reviewUpdatedAtColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_reviews ADD COLUMN updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP',
        );
      }
      final reviewHiddenColumn = await db.query(
        "SHOW COLUMNS FROM user_reviews LIKE 'is_hidden'",
      );
      if (reviewHiddenColumn.isEmpty) {
        await db.query(
          'ALTER TABLE user_reviews ADD COLUMN is_hidden TINYINT(1) NOT NULL DEFAULT 0',
        );
      }
      final reviewModerationColumn = await db.query(
        "SHOW COLUMNS FROM user_reviews LIKE 'moderation_status'",
      );
      if (reviewModerationColumn.isEmpty) {
        await db.query(
          "ALTER TABLE user_reviews ADD COLUMN moderation_status VARCHAR(20) NOT NULL DEFAULT 'pending'",
        );
      }
      await db.query('''
        CREATE TABLE IF NOT EXISTS community_posts (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          user_id BIGINT UNSIGNED NULL,
          author_name VARCHAR(120) NOT NULL,
          place_id VARCHAR(191) NOT NULL,
          place_name VARCHAR(255) NOT NULL,
          rating TINYINT UNSIGNED NOT NULL,
          content TEXT NOT NULL,
          image_url TEXT NULL,
          likes_count INT UNSIGNED NOT NULL DEFAULT 0,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_community_posts_created (created_at),
          INDEX idx_community_posts_popular (likes_count, created_at),
          CONSTRAINT fk_community_post_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');
      final postHiddenColumn = await db.query(
        "SHOW COLUMNS FROM community_posts LIKE 'is_hidden'",
      );
      if (postHiddenColumn.isEmpty) {
        await db.query(
          'ALTER TABLE community_posts ADD COLUMN is_hidden TINYINT(1) NOT NULL DEFAULT 0',
        );
      }
      final postModerationColumn = await db.query(
        "SHOW COLUMNS FROM community_posts LIKE 'moderation_status'",
      );
      if (postModerationColumn.isEmpty) {
        await db.query(
          "ALTER TABLE community_posts ADD COLUMN moderation_status VARCHAR(20) NOT NULL DEFAULT 'pending'",
        );
      }
      await db.query('''
        CREATE TABLE IF NOT EXISTS community_comments (
          id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
          post_id BIGINT UNSIGNED NOT NULL,
          user_id BIGINT UNSIGNED NULL,
          parent_comment_id BIGINT UNSIGNED NULL,
          author_name VARCHAR(120) NOT NULL,
          content TEXT NOT NULL,
          created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
          INDEX idx_community_comments_post_date (post_id, created_at),
          INDEX idx_community_comments_parent (parent_comment_id),
          CONSTRAINT fk_community_comment_post FOREIGN KEY (post_id) REFERENCES community_posts(id) ON DELETE CASCADE,
          CONSTRAINT fk_community_comment_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
      ''');

      final parentCommentColumn = await db.query(
        "SHOW COLUMNS FROM community_comments LIKE 'parent_comment_id'",
      );
      if (parentCommentColumn.isEmpty) {
        await db.query(
          'ALTER TABLE community_comments ADD COLUMN parent_comment_id BIGINT UNSIGNED NULL AFTER user_id',
        );
      }
      final commentHiddenColumn = await db.query(
        "SHOW COLUMNS FROM community_comments LIKE 'is_hidden'",
      );
      if (commentHiddenColumn.isEmpty) {
        await db.query(
          'ALTER TABLE community_comments ADD COLUMN is_hidden TINYINT(1) NOT NULL DEFAULT 0',
        );
      }
      final commentModerationColumn = await db.query(
        "SHOW COLUMNS FROM community_comments LIKE 'moderation_status'",
      );
      if (commentModerationColumn.isEmpty) {
        await db.query(
          "ALTER TABLE community_comments ADD COLUMN moderation_status VARCHAR(20) NOT NULL DEFAULT 'pending'",
        );
      }

      final communitySeedCheck = await db.query(
        'SELECT id FROM community_posts LIMIT 1',
      );
      if (communitySeedCheck.isEmpty) {
        final samples = <Map<String, dynamic>>[
          {
            'author': 'Minh',
            'placeId': 'place:hoi-an',
            'placeName': 'Phố cổ Hội An',
            'rating': 5,
            'content': 'Đi Hội An 2 ngày là vừa đẹp. Buổi chiều dạo phố cổ, tối ngắm đèn lồng và sáng hôm sau ghé biển An Bàng. Nên mang giày dễ đi vì đường lát đá khá nhiều.',
            'image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
            'likes': 128,
            'age': 2,
            'comments': [
              ['Hà', 'Nhớ ghé sớm để chụp ảnh, buổi tối phố đông lắm!'],
              ['Quân', 'Cảm ơn bạn, mình đang lên lịch đi cuối tuần.'],
            ],
          },
          {
            'author': 'Lan',
            'placeId': 'restaurant:bun-cha-ha-noi',
            'placeName': 'Quán bún chả Hà Nội',
            'rating': 5,
            'content': 'Thịt nướng thơm, nước chấm vừa vị và rau ăn kèm khá tươi. Đi tầm trưa hơi đông nên mình thường đến sớm một chút.',
            'image': 'https://langcomvong.com/uploads/images/bun-cha-hang-quat.jpg',
            'likes': 87,
            'age': 4,
            'comments': [
              ['Vy', 'Bạn cho mình xin khu vực quán với nhé?'],
              ['Minh', 'Bún chả ngon nhất là ăn lúc thịt mới nướng.'],
            ],
          },
          {
            'author': 'Tuấn',
            'placeId': 'restaurant:banh-can-nha-trang',
            'placeName': 'Quán bánh căn Út Nổi',
            'rating': 4,
            'content': 'Bánh căn nóng giòn, nhân tôm mực tươi. Nước chấm có xoài bào ăn kèm rất hợp, quán đông hơn vào buổi tối.',
            'image': 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600',
            'likes': 42,
            'age': 0,
            'comments': [
              ['Minh Anh', 'Quán có chỗ đậu xe không bạn?'],
            ],
          },
          {
            'author': 'Ngọc',
            'placeId': 'place:ben-thanh',
            'placeName': 'Chợ Bến Thành',
            'rating': 4,
            'content': 'Nhiều món ăn và quà lưu niệm để chọn. Nhớ hỏi giá trước khi mua và thử các quầy đồ ăn ở khu bên trong.',
            'image': 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600',
            'likes': 32,
            'age': 1,
            'comments': [
              ['Thảo', 'Mình cũng thích khu đồ ăn trong chợ.'],
            ],
          },
          {
            'author': 'Phương',
            'placeId': 'restaurant:lau-mam-ca-mau',
            'placeName': 'Lẩu mắm Đồng Quê Cà Mau',
            'rating': 5,
            'content': 'Nước lẩu đậm đà, ăn cùng cá đồng và nhiều loại rau. Phần ăn khá lớn, hợp đi nhóm đông người.',
            'image': 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600',
            'likes': 53,
            'age': 6,
            'comments': [
              ['Huy', 'Vị mắm có nặng không bạn?'],
              ['Linh', 'Mình đã lưu lại quán này, cảm ơn bạn.'],
            ],
          },
          {
            'author': 'Khoa',
            'placeId': 'restaurant:banh-pia-tan-hue-vien',
            'placeName': 'Bánh Pía Tân Huê Viên',
            'rating': 4,
            'content': 'Bánh nhiều lớp, nhân sầu riêng thơm và không quá ngọt. Có nhiều loại hộp để mua làm quà, nhân viên đóng gói nhanh.',
            'image': 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=600',
            'likes': 18,
            'age': 3,
            'comments': [
              ['Bảo', 'Bánh để được bao lâu vậy?'],
            ],
          },
        ];
        for (final sample in samples) {
          final inserted = await db.query(
            '''INSERT INTO community_posts
               (user_id, author_name, place_id, place_name, rating, content, image_url, likes_count, created_at)
               VALUES (NULL, ?, ?, ?, ?, ?, ?, ?, DATE_SUB(NOW(), INTERVAL ? DAY))''',
            [
              sample['author'],
              sample['placeId'],
              sample['placeName'],
              sample['rating'],
              sample['content'],
              sample['image'],
              sample['likes'],
              sample['age'],
            ],
          );
          for (final comment in sample['comments'] as List<List<String>>) {
            await db.query(
              'INSERT INTO community_comments (post_id, user_id, author_name, content) VALUES (?, NULL, ?, ?)',
              [inserted.insertId, comment[0], comment[1]],
            );
          }
        }
      }
      await db.query('''
        UPDATE community_posts
        SET image_url = CASE
          WHEN place_id = 'restaurant:bun-cha-ha-noi'
            THEN 'https://langcomvong.com/uploads/images/bun-cha-hang-quat.jpg'
          ELSE 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600'
        END
        WHERE image_url LIKE '%photo-1594212699903-ec8a3eca50f6%'
      ''');
      await db.query('''
        INSERT INTO user_reviews
          (user_id, place_id, place_name, rating, comment, created_at)
        SELECT post.user_id, post.place_id, post.place_name, post.rating,
               post.content, post.created_at
        FROM community_posts post
        WHERE post.user_id IS NOT NULL
          AND NOT EXISTS (
            SELECT 1
            FROM community_posts newer
            WHERE newer.user_id = post.user_id
              AND newer.place_id = post.place_id
              AND (newer.created_at > post.created_at
                OR (newer.created_at = post.created_at AND newer.id > post.id))
          )
          AND NOT EXISTS (
            SELECT 1
            FROM user_reviews existing_review
            WHERE existing_review.user_id = post.user_id
              AND existing_review.place_id = post.place_id
          )
      ''');
      final adminRows = await db.query(
        'SELECT id FROM users WHERE username = ? LIMIT 1',
        ['admin'],
      );
      if (adminRows.isEmpty) {
        final passwordHash = BCrypt.hashpw(
          'admin',
          BCrypt.gensalt(logRounds: 10),
        );
        await db.query(
          '''INSERT INTO users (username, email, full_name, password_hash, role, is_active)
             VALUES (?, ?, ?, ?, 'admin', 1)''',
          [
            'admin',
            'admin@vnguide.local',
            'VN Guide Administrator',
            passwordHash,
          ],
        );
        print('VN Guide: created local admin account (username: admin).');
      }
    });
  }

  ConnectionSettings _loadSettings() {
    String setting(String key, [String? alternate, String fallback = '']) =>
        Platform.environment[key] ??
        (alternate == null ? null : Platform.environment[alternate]) ??
        _dotenv?[key] ??
        (alternate == null ? null : _dotenv?[alternate]) ??
        fallback;

    final password = setting('DB_PASSWORD', null, '');
    return ConnectionSettings(
      host: setting('DB_HOST', null, '127.0.0.1'),
      port: int.tryParse(setting('DB_PORT', null, '3306')) ?? 3306,
      user: setting('DB_USER', 'DB_USERNAME', 'root'),
      password: password.isEmpty ? null : password,
      db: setting('DB_NAME', 'DB_DATABASE', 'vietnam_travel'),
      timeout: const Duration(seconds: 10),
    );
  }

  /// Add the auth endpoints to the router already used by backend/bin/server.dart.
  void registerRoutes(Router router) {
    router.post('/api/auth/register', _register);
    router.post('/api/auth/login', _login);
    router.post('/api/auth/google', _googleLogin);
    router.post('/api/auth/forgot-password', _forgotPassword);
    router.post('/api/auth/reset-password', _resetPassword);
    router.get('/api/auth/me', _me);
    router.get('/api/auth/admin-check', _adminCheck);
    router.get('/api/admin/users', _adminUsers);
    router.get('/api/admin/moderation', _adminModeration);
    router.post(
      '/api/admin/moderation/<type>/<id>',
      (request, type, id) => _setModerationStatus(request, type, id),
    );
    router.put(
      '/api/admin/users/<id>/status',
      (request, id) => _setAdminUserStatus(request, id),
    );
    router.post('/api/auth/profile', _updateProfile);
    router.post('/api/auth/change-password', _changePassword);
    router.post('/api/auth/logout', _logout);
    router.get('/api/auth/favorites', _getFavorites);
    router.post('/api/auth/favorites', _saveFavorite);
    router.delete('/api/auth/favorites', _deleteFavorite);
    router.get('/api/auth/checkins', _getCheckins);
    router.post('/api/auth/checkins', _createCheckin);
    router.get('/api/auth/reviews', _getReviews);
    router.post('/api/auth/reviews', _saveReview);
    router.get('/api/community/posts', _getCommunityPosts);
    router.post('/api/community/posts', _createCommunityPost);
    router.get(
      '/api/community/posts/<id>',
      (request, id) => _getCommunityPost(request, id),
    );
    router.post(
      '/api/community/posts/<id>/comments',
      (request, id) => _createCommunityComment(request, id),
    );
  }

  Future<Response> _register(Request request) async {
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;

    final username = (json['username'] ?? '').toString().trim();
    final email = (json['email'] ?? '').toString().trim().toLowerCase();
    final password = (json['password'] ?? '').toString();
    final fullName = (json['fullName'] ?? json['full_name'] ?? '')
        .toString()
        .trim();

    if (!RegExp(r'^[a-zA-Z0-9_.-]{3,50}$').hasMatch(username)) {
      return _json(400, {
        'success': false,
        'message': 'Tên tài khoản phải dài 3–50 ký tự, chỉ gồm chữ, số, dấu chấm, gạch ngang hoặc gạch dưới.',
      });
    }
    if (!_isEmail(email)) {
      return _json(400, {'success': false, 'message': 'Email không hợp lệ.'});
    }
    if (password.length < 8) {
      return _json(400, {
        'success': false,
        'message': 'Mật khẩu phải có ít nhất 8 ký tự.',
      });
    }
    if (fullName.length > 120) {
      return _json(400, {
        'success': false,
        'message': 'Họ tên không được vượt quá 120 ký tự.',
      });
    }
    try {
      final result = await _withDb((db) async {
        final existing = await db.query(
          'SELECT id FROM users WHERE username = ? OR email = ? LIMIT 1',
          [username, email],
        );
        if (existing.isNotEmpty) return null;

        final hash = BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 10));
        final insert = await db.query(
          '''INSERT INTO users (username, email, full_name, password_hash, role, is_active)
             VALUES (?, ?, ?, ?, 'user', 1)''',
          [username, email, fullName.isEmpty ? null : fullName, hash],
        );
        return <String, dynamic>{
          'id': insert.insertId,
          'username': username,
          'email': email,
          'fullName': fullName,
          'avatarUrl': null,
          'nationality': null,
          'role': 'user',
          'sessionVersion': 0,
        };
      });

      if (result == null) {
        return _json(409, {
          'success': false,
          'message': 'Tên tài khoản hoặc email đã được sử dụng.',
        });
      }
      return _authSuccess(result, message: 'Đăng ký thành công.');
    } catch (error, stack) {
      print('Auth register error: $error\n$stack');
      final msg = error.toString().toLowerCase();
      if (msg.contains('duplicate') || msg.contains('unique')) {
        return _json(409, {
          'success': false,
          'message': 'Tên tài khoản hoặc email đã được sử dụng.',
        });
      }
      return _json(500, {
        'success': false,
        'message': 'Không thể đăng ký lúc này. Kiểm tra kết nối cơ sở dữ liệu.',
      });
    }
  }

  Future<Response> _login(Request request) async {
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;

    final identifier =
        (json['identifier'] ??
                json['usernameOrEmail'] ??
                json['username'] ??
                json['email'] ??
                '')
            .toString()
            .trim();
    final password = (json['password'] ?? '').toString();
    if (identifier.isEmpty || password.isEmpty) {
      return _json(400, {
        'success': false,
        'message': 'Vui lòng nhập tài khoản/email và mật khẩu.',
      });
    }

    try {
      final user = await _withDb((db) async {
        final rows = await db.query(
          '''SELECT id, username, email, full_name, avatar_url, nationality,
                    password_hash, role, is_active, session_version
             FROM users WHERE username = ? OR email = ? LIMIT 1''',
          [identifier, identifier.toLowerCase()],
        );
        if (rows.isEmpty) return null;
        final row = rows.first;
        if (_intValue(row['is_active']) != 1) return null;
        final hash = (row['password_hash'] ?? '').toString();
        if (!BCrypt.checkpw(password, hash)) return null;
        return <String, dynamic>{
          'id': row['id'],
          'username': row['username'],
          'email': row['email'],
          'fullName': row['full_name'] ?? '',
          'avatarUrl': row['avatar_url'],
          'nationality': row['nationality'] ?? '',
          'role': row['role'] ?? 'user',
          'sessionVersion': row['session_version'] ?? 0,
        };
      });

      if (user == null) {
        return _json(401, {
          'success': false,
          'message': 'Sai tài khoản/email hoặc mật khẩu.',
        });
      }
      return _authSuccess(user, message: 'Đăng nhập thành công.');
    } catch (error, stack) {
      print('Auth login error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể đăng nhập lúc này. Kiểm tra backend và MariaDB.',
      });
    }
  }

  Future<Response> _googleLogin(Request request) async {
    final body = await _readBody(request);
    if (body is Response) return body;
    final clientId = _googleClientId;
    if (clientId == null || clientId.isEmpty) {
      return _json(503, {
        'success': false,
        'message': 'Backend chưa cấu hình GOOGLE_CLIENT_ID.',
      });
    }

    final idToken = ((body as Map<String, dynamic>)['idToken'] ?? '')
        .toString()
        .trim();
    if (idToken.isEmpty) {
      return _json(400, {
        'success': false,
        'message': 'Thiếu Google ID token.',
      });
    }

    var stage = 'xác minh ID token Google';
    try {
      final claims = await _verifyGoogleIdToken(idToken, clientId);
      if (claims == null) {
        return _json(401, {
          'success': false,
          'message': 'Google ID token không hợp lệ hoặc đã hết hạn.',
        });
      }

      final subject = claims['sub'].toString();
      final email = claims['email'].toString().trim().toLowerCase();
      final fullName = (claims['name'] ?? '').toString().trim();
      stage = 'đọc/ghi MariaDB';
      final user = await _withDb((db) async {
        var rows = await db.query(
          '''SELECT id, username, email, full_name, avatar_url, nationality,
                    google_subject, role, is_active, session_version
             FROM users WHERE google_subject = ? LIMIT 1''',
          [subject],
        );
        if (rows.isEmpty) {
          rows = await db.query(
            '''SELECT id, username, email, full_name, avatar_url, nationality,
                      google_subject, role, is_active, session_version
               FROM users WHERE email = ? LIMIT 1''',
            [email],
          );
        }

        if (rows.isNotEmpty) {
          final row = rows.first;
          if (_intValue(row['is_active']) != 1 ||
              row['role']?.toString() == 'admin') {
            return null;
          }
          final savedSubject = (row['google_subject'] ?? '').toString();
          if (savedSubject.isNotEmpty && savedSubject != subject) return null;

          final userId = row['id'];
          final savedEmail = row['email'].toString().toLowerCase();
          if (savedEmail != email) {
            final emailConflict = await db.query(
              'SELECT id FROM users WHERE email = ? AND id <> ? LIMIT 1',
              [email, userId],
            );
            if (emailConflict.isNotEmpty) return null;
            await db.query(
              'UPDATE users SET email = ?, google_subject = ? WHERE id = ?',
              [email, subject, userId],
            );
          } else if (savedSubject.isEmpty) {
            await db.query('UPDATE users SET google_subject = ? WHERE id = ?', [
              subject,
              userId,
            ]);
          }

          return <String, dynamic>{
            'id': userId,
            'username': row['username'],
            'email': email,
            'fullName': row['full_name'] ?? '',
            'avatarUrl': row['avatar_url'],
            'nationality': row['nationality'] ?? '',
            'role': 'user',
            'sessionVersion': row['session_version'] ?? 0,
          };
        }

        var baseUsername = email
            .split('@')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_');
        if (baseUsername.length < 3) baseUsername = 'google_user';
        if (baseUsername.length > 40) {
          baseUsername = baseUsername.substring(0, 40);
        }

        var username = baseUsername;
        var suffix = 1;
        while ((await db.query(
          'SELECT id FROM users WHERE username = ? LIMIT 1',
          [username],
        )).isNotEmpty) {
          final suffixText = '_$suffix';
          final prefixLength = 50 - suffixText.length;
          final prefix = baseUsername.length > prefixLength
              ? baseUsername.substring(0, prefixLength)
              : baseUsername;
          username = prefix + suffixText;
          suffix++;
        }

        final random = Random.secure();
        final generatedPassword = base64Url
            .encode(List<int>.generate(48, (_) => random.nextInt(256)))
            .replaceAll('=', '');
        final passwordHash = BCrypt.hashpw(
          generatedPassword,
          BCrypt.gensalt(logRounds: 10),
        );
        final insert = await db.query(
          '''INSERT INTO users
             (username, email, full_name, google_subject, password_hash, role, is_active)
             VALUES (?, ?, ?, ?, ?, 'user', 1)''',
          [
            username,
            email,
            fullName.isEmpty
                ? null
                : (fullName.length > 120
                      ? fullName.substring(0, 120)
                      : fullName),
            subject,
            passwordHash,
          ],
        );
        return <String, dynamic>{
          'id': insert.insertId,
          'username': username,
          'email': email,
          'fullName': fullName,
          'avatarUrl': null,
          'nationality': '',
          'role': 'user',
          'sessionVersion': 0,
        };
      });

      if (user == null) {
        return _json(401, {
          'success': false,
          'message': 'Không thể dùng tài khoản Google này để đăng nhập.',
        });
      }
      return _authSuccess(user, message: 'Đăng nhập Google thành công.');
    } catch (error, stack) {
      print('Google auth error: $error\n$stack');
      final message = error.toString().toLowerCase();
      if (message.contains('duplicate') || message.contains('unique')) {
        return _json(409, {
          'success': false,
          'message': 'Tài khoản Google này đã được liên kết.',
        });
      }
      return _json(500, {
        'success': false,
        'message': 'Lỗi ở bước $stage (${error.runtimeType}). Xem log backend.',
      });
    }
  }

  Future<Map<String, dynamic>?> _verifyGoogleIdToken(
    String idToken,
    String clientId,
  ) async {
    JsonWebToken token;
    try {
      token = JsonWebToken.unverified(idToken);
    } catch (_) {
      return null;
    }

    final verified = await token
        .verify(
          JsonWebKeyStore()..addKeySetUrl(
            Uri.parse('https://www.googleapis.com/oauth2/v3/certs'),
          ),
          allowedArguments: const ['RS256'],
        )
        .timeout(const Duration(seconds: 10));
    if (!verified) return null;

    final claims = token.claims.toJson();
    final issuer = claims['iss']?.toString();
    if (issuer != 'https://accounts.google.com' &&
        issuer != 'accounts.google.com') {
      return null;
    }

    final audienceValue = claims['aud'];
    final audiences = audienceValue is List
        ? audienceValue.map((value) => value.toString()).toList()
        : <String>[audienceValue?.toString() ?? ''];
    if (!audiences.contains(clientId)) return null;
    if (audiences.length > 1 && claims['azp']?.toString() != clientId) {
      return null;
    }

    final expiryValue = claims['exp'];
    if (expiryValue is! num ||
        !DateTime.fromMillisecondsSinceEpoch(
          expiryValue.toInt() * 1000,
          isUtc: true,
        ).isAfter(DateTime.now().toUtc())) {
      return null;
    }
    final notBeforeValue = claims['nbf'];
    if (notBeforeValue is num &&
        DateTime.fromMillisecondsSinceEpoch(
          notBeforeValue.toInt() * 1000,
          isUtc: true,
        ).isAfter(DateTime.now().toUtc())) {
      return null;
    }

    final subject = claims['sub']?.toString() ?? '';
    final email = claims['email']?.toString() ?? '';
    final emailVerified =
        claims['email_verified'] == true ||
        claims['email_verified']?.toString().toLowerCase() == 'true';
    if (subject.isEmpty || !_isEmail(email) || !emailVerified) {
      return null;
    }
    return claims;
  }

  Future<Response> _forgotPassword(Request request) async {
    final body = await _readBody(request);
    if (body is Response) return body;
    final email = ((body as Map<String, dynamic>)['email'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    if (!_isEmail(email)) {
      return _json(400, {
        'success': false,
        'message': 'Vui lòng nhập email hợp lệ.',
      });
    }

    try {
      final user = await _withDb((db) async {
        final rows = await db.query(
          'SELECT id, email FROM users WHERE email = ? AND is_active = 1 LIMIT 1',
          [email],
        );
        if (rows.isEmpty) return null;
        return {
          'id': rows.first['id'],
          'email': rows.first['email'].toString(),
        };
      });

      // Do not reveal whether the email exists.
      if (user == null) {
        return _json(200, {
          'success': true,
          'message':
              'Nếu email đã đăng ký, hướng dẫn đặt lại mật khẩu sẽ được gửi.',
        });
      }

      final otp = (100000 + Random.secure().nextInt(900000)).toString();
      final otpHash = sha256.convert(utf8.encode(otp)).toString();
      final expires = DateTime.now().add(const Duration(minutes: 10));

      await _withDb((db) async {
        await db.query('DELETE FROM password_reset_otps WHERE user_id = ?', [
          user['id'],
        ]);
        await db.query(
          '''INSERT INTO password_reset_otps (user_id, otp_hash, expires_at, attempts)
             VALUES (?, ?, ?, 0)''',
          [user['id'], otpHash, _sqlDateTime(expires)],
        );
      });

      if (_smtpConfigured) {
        try {
          await _sendOtpEmail(user['email'].toString(), otp);
        } catch (error, stack) {
          print('OTP email error: $error\n$stack');
          return _json(503, {
            'success': false,
            'message': 'Chưa gửi được email OTP. Kiểm tra cấu hình SMTP của backend rồi thử lại.',
          });
        }
        return _json(200, {
          'success': true,
          'message':
              'Nếu email đã đăng ký, hướng dẫn đặt lại mật khẩu sẽ được gửi.',
        });
      }

      if (_showDevelopmentOtp) {
        print('[DEV ONLY] OTP for $email: $otp');
        return _json(200, {
          'success': true,
          'message': 'Mã OTP thử nghiệm. Chỉ dùng trong môi trường phát triển.',
          'developmentOtp': otp,
        });
      }

      return _json(503, {
        'success': false,
        'message': 'Backend chưa cấu hình SMTP để gửi mã OTP.',
      });
    } catch (error, stack) {
      print('Forgot password error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể tạo yêu cầu quên mật khẩu lúc này.',
      });
    }
  }

  Future<Response> _resetPassword(Request request) async {
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final email = (json['email'] ?? '').toString().trim().toLowerCase();
    final otp = (json['otp'] ?? json['code'] ?? '').toString().trim();
    final newPassword = (json['newPassword'] ?? json['new_password'] ?? '')
        .toString();

    if (!_isEmail(email) || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      return _json(400, {
        'success': false,
        'message': 'Email hoặc mã OTP không hợp lệ.',
      });
    }
    if (newPassword.length < 8) {
      return _json(400, {
        'success': false,
        'message': 'Mật khẩu mới phải có ít nhất 8 ký tự.',
      });
    }

    try {
      final status = await _withDb((db) async {
        final rows = await db.query(
          '''SELECT r.id AS reset_id, r.otp_hash, r.expires_at, r.attempts, u.id AS user_id
             FROM password_reset_otps r
             JOIN users u ON u.id = r.user_id
             WHERE u.email = ? AND u.is_active = 1 LIMIT 1''',
          [email],
        );
        if (rows.isEmpty) return 'missing';
        final row = rows.first;
        if (_intValue(row['attempts']) >= 5) {
          await db.query('DELETE FROM password_reset_otps WHERE id = ?', [
            row['reset_id'],
          ]);
          return 'locked';
        }
        final expiry = DateTime.parse(row['expires_at'].toString());
        if (DateTime.now().isAfter(expiry)) {
          await db.query('DELETE FROM password_reset_otps WHERE id = ?', [
            row['reset_id'],
          ]);
          return 'expired';
        }
        final candidateHash = sha256.convert(utf8.encode(otp)).toString();
        if (candidateHash != row['otp_hash'].toString()) {
          await db.query(
            'UPDATE password_reset_otps SET attempts = attempts + 1 WHERE id = ?',
            [row['reset_id']],
          );
          return 'wrong';
        }

        final newHash = BCrypt.hashpw(
          newPassword,
          BCrypt.gensalt(logRounds: 10),
        );
        await db.query(
          'UPDATE users SET password_hash = ?, session_version = session_version + 1 WHERE id = ?',
          [newHash, row['user_id']],
        );
        await db.query('DELETE FROM password_reset_otps WHERE id = ?', [
          row['reset_id'],
        ]);
        return 'ok';
      });

      switch (status) {
        case 'ok':
          return _json(200, {
            'success': true,
            'message': 'Đặt lại mật khẩu thành công. Hãy đăng nhập lại.',
          });
        case 'wrong':
          return _json(400, {
            'success': false,
            'message': 'Mã OTP không đúng.',
          });
        case 'expired':
          return _json(400, {
            'success': false,
            'message': 'Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.',
          });
        case 'locked':
          return _json(429, {
            'success': false,
            'message': 'Bạn đã nhập sai OTP quá nhiều lần. Hãy yêu cầu mã mới.',
          });
        default:
          return _json(400, {
            'success': false,
            'message': 'Không tìm thấy mã OTP hợp lệ. Hãy yêu cầu mã mới.',
          });
      }
    } catch (error, stack) {
      print('Reset password error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể đặt lại mật khẩu lúc này.',
      });
    }
  }

  Future<Response> _me(Request request) async {
    try {
      final user = await _authenticatedUser(request);
      if (user == null) {
        return _json(401, {
          'success': false,
          'message': 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn.',
        });
      }
      return _json(200, {'success': true, 'user': _publicUser(user)});
    } catch (error, stack) {
      print('Auth me error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể kiểm tra phiên đăng nhập.',
      });
    }
  }

  Future<Response> _adminCheck(Request request) async {
    try {
      final user = await _authenticatedUser(request);
      if (user == null) {
        return _json(401, {
          'success': false,
          'message': 'Vui lòng đăng nhập lại.',
        });
      }
      if (user['role']?.toString() != 'admin') {
        return _json(403, {
          'success': false,
          'message': 'Bạn không có quyền quản trị.',
        });
      }
      return _json(200, {
        'success': true,
        'message': 'Đã xác thực quyền admin.',
      });
    } catch (error, stack) {
      print('Admin check error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể kiểm tra quyền tài khoản lúc này.',
      });
    }
  }

  Future<Response> _adminUsers(Request request) async {
    try {
      final admin = await _authenticatedUser(request);
      if (admin == null) {
        return _json(401, {
          'success': false,
          'message': 'Please sign in again.',
        });
      }
      if (admin['role']?.toString() != 'admin') {
        return _json(403, {
          'success': false,
          'message': 'Administrator access is required.',
        });
      }

      final users = await _withDb((db) async {
        final rows = await db.query('''
          SELECT id, username, email, role, is_active, full_name, created_at
          FROM users
          ORDER BY id ASC
        ''');
        return rows.map((row) => <String, dynamic>{
          'id': _intValue(row['id']).toString(),
          'username': row['username']?.toString() ?? '',
          'email': row['email']?.toString() ?? '',
          'role': row['role']?.toString() ?? 'user',
          'is_active': _intValue(row['is_active']),
          'full_name': row['full_name']?.toString() ?? '',
          'created_at': row['created_at']?.toString(),
        }).toList();
      });
      return _json(200, {'success': true, 'users': users});
    } catch (error, stack) {
      print('Admin users error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Unable to load users.',
      });
    }
  }

  Future<Response> _adminModeration(Request request) async {
    try {
      final admin = await _authenticatedUser(request);
      if (admin == null) {
        return _json(401, {
          'success': false,
          'message': 'Vui lòng đăng nhập lại.',
        });
      }
      if (admin['role']?.toString() != 'admin') {
        return _json(403, {
          'success': false,
          'message': 'Bạn không có quyền quản trị.',
        });
      }

      final records = await _withDb((db) async {
        final rows = await db.query('''
          SELECT 'review' AS content_type, CAST(r.id AS CHAR) AS content_id,
                 r.place_name AS title, r.comment AS content, r.rating,
                 COALESCE(NULLIF(u.full_name, ''), u.username, 'Người dùng') AS author,
                 r.created_at, r.moderation_status
          FROM user_reviews r
          LEFT JOIN users u ON u.id = r.user_id
          WHERE r.moderation_status = 'pending'
            AND NOT EXISTS (
              SELECT 1 FROM community_posts p
              WHERE p.user_id = r.user_id AND p.place_id = r.place_id
                AND p.rating = r.rating AND p.content = r.comment
            )
          UNION ALL
          SELECT 'post' AS content_type, CAST(p.id AS CHAR) AS content_id,
                 p.place_name AS title, p.content, p.rating,
                 COALESCE(NULLIF(u.full_name, ''), u.username, p.author_name) AS author,
                 p.created_at, p.moderation_status
          FROM community_posts p
          LEFT JOIN users u ON u.id = p.user_id
          WHERE p.moderation_status = 'pending'
          UNION ALL
          SELECT 'comment' AS content_type, CAST(c.id AS CHAR) AS content_id,
                 p.place_name AS title, c.content, NULL AS rating,
                 COALESCE(NULLIF(u.full_name, ''), u.username, c.author_name) AS author,
                 c.created_at, c.moderation_status
          FROM community_comments c
          INNER JOIN community_posts p ON p.id = c.post_id
          LEFT JOIN users u ON u.id = c.user_id
          WHERE c.moderation_status = 'pending'
          ORDER BY created_at DESC
          LIMIT 300
        ''');
        return rows.map((row) => <String, dynamic>{
          'id': row['content_id']?.toString() ?? '',
          'type': row['content_type']?.toString() ?? '',
          'title': row['title']?.toString() ?? '',
          'content': row['content']?.toString() ?? '',
          'author': row['author']?.toString() ?? 'Người dùng',
          'rating': row['rating'] == null ? null : _intValue(row['rating']),
          'createdAt': row['created_at']?.toString(),
        }).toList();
      });
      return _json(200, {'success': true, 'records': records});
    } catch (error, stack) {
      print('Admin moderation load error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể tải nội dung kiểm duyệt lúc này.',
      });
    }
  }

  Future<Response> _setModerationStatus(
    Request request,
    String type,
    String id,
  ) async {
    try {
      final admin = await _authenticatedUser(request);
      if (admin == null) {
        return _json(401, {
          'success': false,
          'message': 'Vui lòng đăng nhập lại.',
        });
      }
      if (admin['role']?.toString() != 'admin') {
        return _json(403, {
          'success': false,
          'message': 'Bạn không có quyền quản trị.',
        });
      }
      final contentId = int.tryParse(id);
      if (contentId == null || !const {'review', 'post', 'comment'}.contains(type)) {
        return _json(400, {'success': false, 'message': 'Nội dung không hợp lệ.'});
      }
      final body = await _readBody(request);
      if (body is Response) return body;
      final action = (body as Map<String, dynamic>)['action']?.toString();
      if (action != 'keep' && action != 'hide') {
        return _json(400, {'success': false, 'message': 'Thao tác không hợp lệ.'});
      }
      final hidden = action == 'hide';
      final status = hidden ? 'hidden' : 'approved';

      final updated = await _withDb((db) async {
        if (type == 'review') {
          final rows = await db.query(
            'SELECT user_id, place_id, rating, comment FROM user_reviews WHERE id = ? LIMIT 1',
            [contentId],
          );
          if (rows.isEmpty) return false;
          final row = rows.first;
          await db.query(
            'UPDATE user_reviews SET is_hidden = ?, moderation_status = ? WHERE id = ?',
            [hidden ? 1 : 0, status, contentId],
          );
          await db.query(
            '''UPDATE community_posts SET is_hidden = ?, moderation_status = ?
               WHERE user_id = ? AND place_id = ? AND rating = ? AND content = ?''',
            [hidden ? 1 : 0, status, row['user_id'], row['place_id'], row['rating'], row['comment']],
          );
        } else if (type == 'post') {
          final rows = await db.query(
            'SELECT user_id, place_id, rating, content FROM community_posts WHERE id = ? LIMIT 1',
            [contentId],
          );
          if (rows.isEmpty) return false;
          final row = rows.first;
          await db.query(
            'UPDATE community_posts SET is_hidden = ?, moderation_status = ? WHERE id = ?',
            [hidden ? 1 : 0, status, contentId],
          );
          if (row['user_id'] != null) {
            await db.query(
              '''UPDATE user_reviews SET is_hidden = ?, moderation_status = ?
                 WHERE user_id = ? AND place_id = ? AND rating = ? AND comment = ?''',
              [hidden ? 1 : 0, status, row['user_id'], row['place_id'], row['rating'], row['content']],
            );
          }
        } else {
          final rows = await db.query(
            'SELECT id FROM community_comments WHERE id = ? LIMIT 1',
            [contentId],
          );
          if (rows.isEmpty) return false;
          await db.query(
            'UPDATE community_comments SET is_hidden = ?, moderation_status = ? WHERE id = ?',
            [hidden ? 1 : 0, status, contentId],
          );
        }
        return true;
      });
      if (!updated) {
        return _json(404, {'success': false, 'message': 'Không tìm thấy nội dung.'});
      }
      return _json(200, {
        'success': true,
        'message': hidden ? 'Đã tắt nội dung.' : 'Đã giữ lại nội dung.',
      });
    } catch (error, stack) {
      print('Admin moderation update error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể cập nhật trạng thái nội dung lúc này.',
      });
    }
  }

  Future<Response> _setAdminUserStatus(Request request, String id) async {
    try {
      final admin = await _authenticatedUser(request);
      if (admin == null) {
        return _json(401, {
          'success': false,
          'message': 'Please sign in again.',
        });
      }
      if (admin['role']?.toString() != 'admin') {
        return _json(403, {
          'success': false,
          'message': 'Administrator access is required.',
        });
      }

      final userId = int.tryParse(id);
      if (userId == null) {
        return _json(400, {'success': false, 'message': 'Invalid user ID.'});
      }
      if (_intValue(admin['id']) == userId) {
        return _json(400, {
          'success': false,
          'message': 'You cannot lock the currently signed-in admin account.',
        });
      }

      final body = await _readBody(request);
      if (body is Response) return body;
      final isActive = (body as Map<String, dynamic>)['isActive'];
      if (isActive is! bool) {
        return _json(400, {
          'success': false,
          'message': 'Invalid account status.',
        });
      }

      return await _withDb((db) async {
        final target = await db.query(
          'SELECT id FROM users WHERE id = ? LIMIT 1',
          [userId],
        );
        if (target.isEmpty) {
          return _json(404, {
            'success': false,
            'message': 'User not found.',
          });
        }

        final activeValue = isActive ? 1 : 0;
        await db.query(
          '''UPDATE users
             SET is_active = ?, session_version = session_version + 1
             WHERE id = ? AND is_active <> ?''',
          [activeValue, userId, activeValue],
        );
        return _json(200, {
          'success': true,
          'isActive': isActive,
        });
      });
    } catch (error, stack) {
      print('Admin user status error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Unable to update account status.',
      });
    }
  }

  Future<Response> _updateProfile(Request request) async {
    final currentUser = await _authenticatedUser(request);
    if (currentUser == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final username = (json['username'] ?? currentUser['username'])
        .toString()
        .trim();
    final email = (json['email'] ?? currentUser['email'])
        .toString()
        .trim()
        .toLowerCase();
    final fullName = (json['fullName'] ?? json['full_name'] ?? '')
        .toString()
        .trim();
    final avatarUrl = (json['avatarUrl'] ?? json['avatar_url'] ?? '')
        .toString()
        .trim();
    final nationality = (json['nationality'] ?? '').toString().trim();

    if (!RegExp(r'^[a-zA-Z0-9_.-]{3,50}$').hasMatch(username)) {
      return _json(400, {
        'success': false,
        'message':
            'Tên tài khoản phải dài 3–50 ký tự và không có khoảng trắng.',
      });
    }
    if (!_isEmail(email)) {
      return _json(400, {'success': false, 'message': 'Email không hợp lệ.'});
    }
    if (fullName.length > 120) {
      return _json(400, {
        'success': false,
        'message': 'Họ tên không được vượt quá 120 ký tự.',
      });
    }
    if (avatarUrl.length > 1024 || nationality.length > 80) {
      return _json(400, {
        'success': false,
        'message': 'Ảnh đại diện hoặc quốc tịch vượt quá giới hạn cho phép.',
      });
    }

    try {
      final user = await _withDb((db) async {
        final conflicts = await db.query(
          'SELECT id FROM users WHERE (username = ? OR email = ?) AND id <> ? LIMIT 1',
          [username, email, currentUser['id']],
        );
        if (conflicts.isNotEmpty) return null;
        await db.query(
          'UPDATE users SET username = ?, email = ?, full_name = ?, avatar_url = ?, nationality = ? WHERE id = ?',
          [
            username,
            email,
            fullName.isEmpty ? null : fullName,
            avatarUrl.isEmpty ? null : avatarUrl,
            nationality.isEmpty ? null : nationality,
            currentUser['id'],
          ],
        );
        return <String, dynamic>{
          'id': currentUser['id'],
          'username': username,
          'email': email,
          'fullName': fullName,
          'avatarUrl': avatarUrl,
          'nationality': nationality,
          'role': currentUser['role'],
        };
      });
      if (user == null) {
        return _json(409, {
          'success': false,
          'message': 'Tên tài khoản hoặc email đã được sử dụng.',
        });
      }
      return _json(200, {
        'success': true,
        'message': 'Đã cập nhật hồ sơ.',
        'user': user,
      });
    } catch (error, stack) {
      print('Update profile error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể cập nhật hồ sơ lúc này.',
      });
    }
  }

  Future<Response> _changePassword(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final currentPassword = (json['currentPassword'] ?? '').toString();
    final newPassword = (json['newPassword'] ?? '').toString();
    if (currentPassword.isEmpty) {
      return _json(400, {
        'success': false,
        'message': 'Vui lòng nhập mật khẩu hiện tại.',
      });
    }
    if (newPassword.length < 8) {
      return _json(400, {
        'success': false,
        'message': 'Mật khẩu mới phải có ít nhất 8 ký tự.',
      });
    }

    try {
      final changed = await _withDb((db) async {
        final rows = await db.query(
          'SELECT password_hash FROM users WHERE id = ? AND is_active = 1 LIMIT 1',
          [user['id']],
        );
        if (rows.isEmpty ||
            !BCrypt.checkpw(
              currentPassword,
              (rows.first['password_hash'] ?? '').toString(),
            )) {
          return false;
        }
        final hash = BCrypt.hashpw(newPassword, BCrypt.gensalt(logRounds: 10));
        await db.query(
          'UPDATE users SET password_hash = ?, session_version = session_version + 1 WHERE id = ?',
          [hash, user['id']],
        );
        await db.query('DELETE FROM password_reset_otps WHERE user_id = ?', [
          user['id'],
        ]);
        return true;
      });
      if (!changed) {
        return _json(401, {
          'success': false,
          'message': 'Mật khẩu hiện tại không đúng.',
        });
      }
      return _json(200, {
        'success': true,
        'message': 'Đổi mật khẩu thành công. Hãy đăng nhập lại.',
      });
    } catch (error, stack) {
      print('Change password error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể đổi mật khẩu lúc này.',
      });
    }
  }

  Future<Response> _logout(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Phiên đăng nhập đã hết hạn.',
      });
    }
    try {
      await _withDb((db) async {
        await db.query(
          'UPDATE users SET session_version = session_version + 1 WHERE id = ?',
          [user['id']],
        );
      });
      return _json(200, {'success': true, 'message': 'Đã đăng xuất.'});
    } catch (error, stack) {
      print('Logout error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể kết thúc phiên trên máy chủ lúc này.',
      });
    }
  }

  Map<String, dynamic>? _favoriteMetadata(dynamic value) {
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Response> _getFavorites(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    try {
      final favorites = await _withDb((db) async {
        final rows = await db.query(
          '''SELECT item_type, item_id, title, subtitle, image_url, metadata_json, created_at
             FROM user_favorites WHERE user_id = ? ORDER BY created_at DESC''',
          [user['id']],
        );
        return rows
            .map(
              (row) => <String, dynamic>{
                'kind': row['item_type']?.toString() ?? '',
                'id': row['item_id']?.toString() ?? '',
                'title': row['title']?.toString() ?? '',
                'subtitle': row['subtitle']?.toString() ?? '',
                'imageUrl': row['image_url']?.toString() ?? '',
                if (_favoriteMetadata(row['metadata_json']) != null)
                  'metadata': _favoriteMetadata(row['metadata_json']),
              },
            )
            .toList();
      });
      return _json(200, {'success': true, 'favorites': favorites});
    } catch (error, stack) {
      print('Load favorites error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể tải danh sách yêu thích lúc này.',
      });
    }
  }

  Future<Response> _saveFavorite(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final kind = (json['kind'] ?? json['itemType'] ?? '').toString();
    final id = (json['id'] ?? json['itemId'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final subtitle = (json['subtitle'] ?? '').toString().trim();
    final imageUrl = (json['imageUrl'] ?? json['image_url'] ?? '').toString();
    final metadataValue = json['metadata'];
    final metadataJson = metadataValue is Map || metadataValue is List
        ? jsonEncode(metadataValue)
        : null;
    if (!const {'place', 'food', 'restaurant', 'itinerary'}.contains(kind) ||
        id.isEmpty ||
        id.length > 191 ||
        title.isEmpty ||
        title.length > 255) {
      return _json(400, {
        'success': false,
        'message': 'Thông tin mục yêu thích không hợp lệ.',
      });
    }

    try {
      await _withDb((db) async {
        final userId = user['id'];
        final existing = await db.query(
          '''SELECT 1 FROM user_favorites
             WHERE user_id = ? AND item_type = ? AND item_id = ? LIMIT 1''',
          [userId, kind, id],
        );
        if (existing.isEmpty) {
          await db.query(
            '''INSERT INTO user_favorites
               (user_id, item_type, item_id, title, subtitle, image_url, metadata_json)
               VALUES (?, ?, ?, ?, ?, ?, ?)''',
            [userId, kind, id, title, subtitle, imageUrl, metadataJson],
          );
        } else {
          await db.query(
            '''UPDATE user_favorites
               SET title = ?, subtitle = ?, image_url = ?,
                   metadata_json = COALESCE(?, metadata_json)
               WHERE user_id = ? AND item_type = ? AND item_id = ?''',
            [title, subtitle, imageUrl, metadataJson, userId, kind, id],
          );
        }
      });
      return _json(200, {'success': true, 'message': 'Đã lưu yêu thích.'});
    } catch (error, stack) {
      print('Save favorite error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể lưu yêu thích lúc này.',
      });
    }
  }

  Future<Response> _deleteFavorite(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final kind = (json['kind'] ?? json['itemType'] ?? '').toString();
    final id = (json['id'] ?? json['itemId'] ?? '').toString().trim();
    if (!const {'place', 'food', 'restaurant', 'itinerary'}.contains(kind) ||
        id.isEmpty) {
      return _json(400, {
        'success': false,
        'message': 'Thông tin mục yêu thích không hợp lệ.',
      });
    }
    try {
      await _withDb((db) async {
        await db.query(
          'DELETE FROM user_favorites WHERE user_id = ? AND item_type = ? AND item_id = ?',
          [user['id'], kind, id],
        );
      });
      return _json(200, {'success': true, 'message': 'Đã bỏ yêu thích.'});
    } catch (error, stack) {
      print('Delete favorite error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể bỏ yêu thích lúc này.',
      });
    }
  }

  Future<Response> _getCheckins(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    try {
      final checkins = await _withDb((db) async {
        final rows = await db.query(
          '''SELECT id, place_id, place_name, visited_on, checked_in_at,
                    image_url, feeling
             FROM user_checkins WHERE user_id = ?
             ORDER BY COALESCE(visited_on, DATE(checked_in_at)) DESC,
                      checked_in_at DESC''',
          [user['id']],
        );
        return rows
            .map(
              (row) => <String, dynamic>{
                'id': row['id'],
                'placeId': row['place_id'],
                'placeName': row['place_name'],
                'checkedInAt': (row['visited_on'] ?? row['checked_in_at'])?.toString(),
                'visitedAt': (row['visited_on'] ?? row['checked_in_at'])?.toString(),
                'imageUrl': row['image_url']?.toString() ?? '',
                'feeling': row['feeling']?.toString() ?? '',
              },
            )
            .toList();
      });
      return _json(200, {'success': true, 'checkins': checkins});
    } catch (error, stack) {
      print('Load checkins error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể tải lịch sử check-in lúc này.',
      });
    }
  }

  Future<Response> _createCheckin(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final placeId = (json['placeId'] ?? '').toString().trim();
    final placeName = (json['placeName'] ?? '').toString().trim();
    final visitedAtText = (json['visitedAt'] ?? '').toString().trim();
    final visitedAt = DateTime.tryParse(visitedAtText) ?? DateTime.now();
    final imageUrl = (json['imageUrl'] ?? '').toString().trim();
    final feeling = (json['feeling'] ?? '').toString().trim();
    if (placeId.isEmpty ||
        placeId.length > 191 ||
        placeName.isEmpty ||
        placeName.length > 255 ||
        imageUrl.length > 2048 ||
        feeling.length > 4000) {
      return _json(400, {
        'success': false,
        'message': 'Thông tin check-in không hợp lệ.',
      });
    }
    try {
      final insertId = await _withDb((db) async {
        final result = await db.query(
          '''INSERT INTO user_checkins
             (user_id, place_id, place_name, visited_on, image_url, feeling)
             VALUES (?, ?, ?, ?, ?, ?)''',
          [
            user['id'],
            placeId,
            placeName,
            _sqlDate(visitedAt),
            imageUrl.isEmpty ? null : imageUrl,
            feeling,
          ],
        );
        return result.insertId;
      });
      return _json(201, {
        'success': true,
        'checkin': {
          'id': insertId,
          'placeId': placeId,
          'placeName': placeName,
          'checkedInAt': visitedAt.toIso8601String(),
          'visitedAt': visitedAt.toIso8601String(),
          'imageUrl': imageUrl,
          'feeling': feeling,
        },
      });
    } catch (error, stack) {
      print('Create checkin error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể lưu check-in lúc này.',
      });
    }
  }

  Future<Response> _getReviews(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final placeId = request.url.queryParameters['placeId']?.trim();
    try {
      final reviews = await _withDb((db) async {
        final rows = placeId == null || placeId.isEmpty
            ? await db.query(
                '''SELECT id, place_id, place_name, rating, comment, created_at,
                          is_hidden, moderation_status
                   FROM user_reviews WHERE user_id = ? ORDER BY updated_at DESC''',
                [user['id']],
              )
            : await db.query(
                '''SELECT id, place_id, place_name, rating, comment, created_at,
                          is_hidden, moderation_status
                   FROM user_reviews WHERE user_id = ? AND place_id = ?
                   ORDER BY updated_at DESC''',
                [user['id'], placeId],
              );
        return rows
            .map(
              (row) => <String, dynamic>{
                'id': _intValue(row['id']).toString(),
                'placeId': row['place_id']?.toString() ?? '',
                'placeName': row['place_name']?.toString() ?? '',
                'rating': _intValue(row['rating']),
                'comment': row['comment']?.toString() ?? '',
                'createdAt': row['created_at']?.toString(),
                'isHidden': _intValue(row['is_hidden']) == 1,
                'moderationStatus': row['moderation_status']?.toString() ?? 'approved',
              },
            )
            .toList();
      });
      return _json(200, {'success': true, 'reviews': reviews});
    } catch (error, stack) {
      print('Load reviews error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể tải đánh giá lúc này.',
      });
    }
  }

  Future<Response> _saveReview(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final placeId = (json['placeId'] ?? '').toString().trim();
    final placeName = (json['placeName'] ?? '').toString().trim();
    final rating = int.tryParse((json['rating'] ?? '').toString());
    final comment = (json['comment'] ?? '').toString().trim();
    if (placeId.isEmpty ||
        placeId.length > 191 ||
        placeName.isEmpty ||
        placeName.length > 255 ||
        rating == null ||
        rating < 1 ||
        rating > 5 ||
        comment.length > 2000) {
      return _json(400, {
        'success': false,
        'message': 'Đánh giá cần có địa điểm, số sao từ 1 đến 5 và nhận xét tối đa 2000 ký tự.',
      });
    }
    try {
      await _withDb((db) async {
        await db.query(
          '''INSERT INTO user_reviews (user_id, place_id, place_name, rating, comment)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE place_name = VALUES(place_name),
               rating = VALUES(rating), comment = VALUES(comment),
               is_hidden = 0, moderation_status = 'pending' ''',
          [user['id'], placeId, placeName, rating, comment],
        );
      });
      return _json(200, {'success': true, 'message': 'Đã lưu đánh giá.'});
    } catch (error, stack) {
      print('Save review error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể lưu đánh giá lúc này.',
      });
    }
  }

  Future<Response> _getCommunityPosts(Request request) async {
    final popular = request.url.queryParameters['sort'] == 'popular';
    final orderBy = popular
        ? 'p.likes_count DESC, comment_count DESC, p.created_at DESC, p.id DESC'
        : 'p.created_at DESC, p.id DESC';
    try {
      final posts = await _withDb((db) async {
        final rows = await db.query(
          '''SELECT p.id, p.author_name, p.place_id, p.place_name, p.rating,
                    p.content, p.image_url, p.likes_count, p.created_at, p.is_hidden,
                    (SELECT COUNT(*) FROM community_comments c WHERE c.post_id = p.id) AS comment_count
             FROM community_posts p
             ORDER BY $orderBy
             LIMIT 100''',
        );
        return rows.map(_communityPostJson).toList();
      });
      return _json(200, {'success': true, 'posts': posts});
    } catch (error, stack) {
      print('Load community posts error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể tải bài chia sẻ lúc này.',
      });
    }
  }

  Future<Response> _getCommunityPost(Request request, String id) async {
    final postId = int.tryParse(id);
    if (postId == null) {
      return _json(400, {
        'success': false,
        'message': 'Bài viết không hợp lệ.',
      });
    }
    try {
      final result = await _withDb((db) async {
        final rows = await db.query(
          '''SELECT p.id, p.author_name, p.place_id, p.place_name, p.rating,
                    p.content, p.image_url, p.likes_count, p.created_at, p.is_hidden,
                    (SELECT COUNT(*) FROM community_comments c WHERE c.post_id = p.id) AS comment_count
             FROM community_posts p WHERE p.id = ? LIMIT 1''',
          [postId],
        );
        if (rows.isEmpty) return null;
        final comments = await db.query(
          '''SELECT id, parent_comment_id, author_name, content, created_at, is_hidden
             FROM community_comments WHERE post_id = ?
             ORDER BY created_at ASC, id ASC''',
          [postId],
        );
        return <String, dynamic>{
          'post': _communityPostJson(rows.first),
          'comments': comments.map(_communityCommentJson).toList(),
        };
      });
      if (result == null) {
        return _json(404, {
          'success': false,
          'message': 'Không tìm thấy bài viết.',
        });
      }
      return _json(200, {'success': true, ...result});
    } catch (error, stack) {
      print('Load community post error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể tải bài chia sẻ lúc này.',
      });
    }
  }

  Future<Response> _createCommunityPost(Request request) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final placeId = (json['placeId'] ?? '').toString().trim();
    final placeName = (json['placeName'] ?? '').toString().trim();
    final rating = int.tryParse((json['rating'] ?? '').toString());
    final content = (json['content'] ?? '').toString().trim();
    final imageUrl = (json['imageUrl'] ?? '').toString().trim();
    if (placeId.isEmpty ||
        placeId.length > 191 ||
        placeName.isEmpty ||
        placeName.length > 255 ||
        rating == null ||
        rating < 1 ||
        rating > 5 ||
        content.isEmpty ||
        content.length > 2000 ||
        imageUrl.length > 2048) {
      return _json(400, {
        'success': false,
        'message': 'Bài đánh giá cần có quán hoặc địa điểm, số sao từ 1 đến 5 và nội dung tối đa 2000 ký tự.',
      });
    }
    final authorName = (user['fullName'] ?? '').toString().trim().isNotEmpty
        ? (user['fullName'] ?? '').toString().trim()
        : (user['username'] ?? 'Thành viên').toString();
    try {
      final postId = await _withDb((db) async {
        final inserted = await db.query(
          '''INSERT INTO community_posts
             (user_id, author_name, place_id, place_name, rating, content, image_url)
             VALUES (?, ?, ?, ?, ?, ?, ?)''',
          [
            user['id'],
            authorName,
            placeId,
            placeName,
            rating,
            content,
            imageUrl.isEmpty ? null : imageUrl,
          ],
        );
        await db.query(
          '''INSERT INTO user_reviews (user_id, place_id, place_name, rating, comment)
             VALUES (?, ?, ?, ?, ?)
             ON DUPLICATE KEY UPDATE place_name = VALUES(place_name),
               rating = VALUES(rating), comment = VALUES(comment),
               is_hidden = 0, moderation_status = 'pending' ''',
          [user['id'], placeId, placeName, rating, content],
        );
        return inserted.insertId;
      });
      return _json(201, {
        'success': true,
        'postId': postId.toString(),
        'message': 'Đã đăng bài đánh giá.',
      });
    } catch (error, stack) {
      print('Create community post error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể đăng bài đánh giá lúc này.',
      });
    }
  }

  Future<Response> _createCommunityComment(Request request, String id) async {
    final user = await _authenticatedUser(request);
    if (user == null) {
      return _json(401, {
        'success': false,
        'message': 'Vui lòng đăng nhập lại để bình luận.',
      });
    }
    final postId = int.tryParse(id);
    if (postId == null) {
      return _json(400, {
        'success': false,
        'message': 'Bài viết không hợp lệ.',
      });
    }
    final body = await _readBody(request);
    if (body is Response) return body;
    final json = body as Map<String, dynamic>;
    final content = (json['content'] ?? '').toString().trim();
    final parentCommentId = json['parentCommentId'] == null
        ? null
        : int.tryParse(json['parentCommentId'].toString());
    if (content.isEmpty ||
        content.length > 2000 ||
        (json['parentCommentId'] != null && parentCommentId == null)) {
      return _json(400, {
        'success': false,
        'message': 'Bình luận cần có nội dung tối đa 2000 ký tự.',
      });
    }
    final authorName = (user['fullName'] ?? '').toString().trim().isNotEmpty
        ? (user['fullName'] ?? '').toString().trim()
        : (user['username'] ?? 'Thành viên').toString();
    try {
      final comment = await _withDb((db) async {
        final posts = await db.query(
          'SELECT id FROM community_posts WHERE id = ? AND is_hidden = 0 LIMIT 1',
          [postId],
        );
        if (posts.isEmpty) return null;
        if (parentCommentId != null) {
          final parents = await db.query(
            'SELECT id FROM community_comments WHERE id = ? AND post_id = ? AND is_hidden = 0 LIMIT 1',
            [parentCommentId, postId],
          );
          if (parents.isEmpty) return false;
        }
        final inserted = await db.query(
          '''INSERT INTO community_comments
             (post_id, user_id, parent_comment_id, author_name, content)
             VALUES (?, ?, ?, ?, ?)''',
          [postId, user['id'], parentCommentId, authorName, content],
        );
        return <String, dynamic>{
          'id': inserted.insertId.toString(),
          'parentCommentId': parentCommentId?.toString(),
          'authorName': authorName,
          'content': content,
          'isHidden': false,
          'createdAt': DateTime.now().toIso8601String(),
        };
      });
      if (comment == null) {
        return _json(404, {
          'success': false,
          'message': 'Không tìm thấy bài viết.',
        });
      }
      if (comment == false) {
        return _json(400, {
          'success': false,
          'message': 'Không tìm thấy bình luận cần trả lời.',
        });
      }
      return _json(201, {'success': true, 'comment': comment});
    } catch (error, stack) {
      print('Create community comment error: $error\n$stack');
      return _json(500, {
        'success': false,
        'message': 'Không thể gửi bình luận lúc này.',
      });
    }
  }

  Map<String, dynamic> _communityPostJson(ResultRow row) => {
    'id': _intValue(row['id']).toString(),
    'authorName': row['author_name']?.toString() ?? '',
    'placeId': row['place_id']?.toString() ?? '',
    'placeName': row['place_name']?.toString() ?? '',
    'rating': _intValue(row['rating']),
    'content': row['content']?.toString() ?? '',
    'imageUrl': row['image_url']?.toString() ?? '',
    'likesCount': _intValue(row['likes_count']),
    'commentCount': _intValue(row['comment_count']),
    'createdAt': row['created_at']?.toString(),
    'isHidden': _intValue(row['is_hidden']) == 1,
  };

  Map<String, dynamic> _communityCommentJson(ResultRow row) => {
    'id': _intValue(row['id']).toString(),
    'parentCommentId': row['parent_comment_id']?.toString(),
    'authorName': row['author_name']?.toString() ?? '',
    'content': row['content']?.toString() ?? '',
    'createdAt': row['created_at']?.toString(),
    'isHidden': _intValue(row['is_hidden']) == 1,
  };

  Future<Map<String, dynamic>?> _authenticatedUser(Request request) async {
    final claims = _verifyBearer(request);
    if (claims == null) return null;
    final id = int.tryParse((claims['sub'] ?? '').toString());
    if (id == null) return null;
    return _withDb((db) async {
      final rows = await db.query(
        '''SELECT id, username, email, full_name, avatar_url, nationality,
                  role, is_active, session_version
           FROM users WHERE id = ? LIMIT 1''',
        [id],
      );
      if (rows.isEmpty) return null;
      final row = rows.first;
      final version = _intValue(row['session_version']);
      if (_intValue(row['is_active']) != 1 ||
          _intValue(claims['sv'] ?? 0) != version) {
        return null;
      }
      return <String, dynamic>{
        'id': row['id'],
        'username': row['username'],
        'email': row['email'],
        'fullName': row['full_name'] ?? '',
        'avatarUrl': row['avatar_url'],
        'nationality': row['nationality'] ?? '',
        'role': row['role'] ?? 'user',
        'sessionVersion': version,
      };
    });
  }

  Map<String, dynamic> _publicUser(Map<String, dynamic> user) => {
    'id': user['id'],
    'username': user['username'],
    'email': user['email'],
    'fullName': user['fullName'] ?? '',
    'avatarUrl': user['avatarUrl'],
    'nationality': user['nationality'] ?? '',
    'role': user['role'] ?? 'user',
  };

  Future<void> _sendOtpEmail(String recipient, String otp) async {
    final username = _setting('SMTP_GMAIL_ADDRESS').trim();
    final password = _setting('SMTP_GMAIL_APP_PASSWORD').trim();
    final message = Message()
      ..from = Address(username, 'VN Guide')
      ..recipients.add(recipient)
      ..subject = 'Mã xác nhận đặt lại mật khẩu VN Guide'
      ..text =
          'Mã OTP của bạn là: $otp\nMã có hiệu lực trong 10 phút. Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này.';
    await send(
      message,
      gmail(username, password),
    ).timeout(const Duration(seconds: 20));
  }

  Response _authSuccess(Map<String, dynamic> user, {required String message}) {
    final token = JWT(
      {
        'sub': user['id'].toString(),
        'username': user['username'],
        'role': user['role'],
        'sv': _intValue(user['sessionVersion'] ?? 0),
      },
      issuer: 'vn-guide',
    ).sign(SecretKey(_jwtSecret), expiresIn: const Duration(hours: 12));

    return _json(200, {
      'success': true,
      'message': message,
      'token': token,
      'user': user,
    });
  }

  Map<String, dynamic>? _verifyBearer(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.toLowerCase().startsWith('bearer ')) {
      return null;
    }
    final token = header.substring(7).trim();
    if (token.isEmpty) return null;
    try {
      final jwt = JWT.verify(token, SecretKey(_jwtSecret));
      final payload = jwt.payload;
      if (payload is Map<String, dynamic>) return payload;
      if (payload is Map) return Map<String, dynamic>.from(payload);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _readBody(Request request) async {
    try {
      final raw = await request.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return _json(400, {
          'success': false,
          'message': 'Nội dung yêu cầu phải là JSON object.',
        });
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return _json(400, {'success': false, 'message': 'JSON không hợp lệ.'});
    } catch (_) {
      return _json(400, {
        'success': false,
        'message': 'Không đọc được dữ liệu gửi lên.',
      });
    }
  }

  bool _isEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _sqlDate(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  String _sqlDateTime(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  Response _json(int status, Map<String, dynamic> body) => Response(
    status,
    body: jsonEncode(body),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

/// Optional CORS middleware for Flutter Web/browser builds.
/// Add it to the existing Shelf Pipeline if the frontend runs in a browser.
Middleware authCorsMiddleware() {
  const headers = <String, String>{
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
    'access-control-allow-headers':
        'Origin, Content-Type, Accept, Authorization',
    'access-control-max-age': '86400',
  };
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response(204, headers: headers);
      }
      final response = await innerHandler(request);
      return response.change(headers: {...response.headers, ...headers});
    };
  };
}
