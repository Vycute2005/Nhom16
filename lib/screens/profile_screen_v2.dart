import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:hcm_explorer/widgets/app_ui.dart';
import 'package:hcm_explorer/services/app_locale.dart';

import '../config/api_config.dart';
import '../services/auth_api_service.dart';
import '../services/favorites_store.dart';
import '../services/app_theme.dart';
import '../widgets/app_image.dart';
import '../services/upload_service.dart';
import 'account_access_screen.dart';
import 'favorites_screen.dart';
import 'app_info_screens.dart';

const _green = Color(0xFF0F5B49);
const _border = Color(0xFFE8DED0);

class ProfileScreenV2 extends StatelessWidget {
  const ProfileScreenV2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Cá nhân',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: userSession,
          builder: (context, _) => AnimatedBuilder(
            animation: favoritesStore,
            builder: (context, _) {
              final signedIn = userSession.isSignedIn;
              final title = userSession.fullName?.isNotEmpty == true
                  ? userSession.fullName!
                  : userSession.username ?? 'Tài khoản của bạn';
              return ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
                children: [
                  _profileHeader(signedIn: signedIn, title: title),
                  const SizedBox(height: 18),
                  if (!signedIn)
                    _MenuTile(
                      icon: Icons.login_rounded,
                      title: 'Đăng nhập / Đăng ký',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const AccountAccessScreen(),
                        ),
                      ),
                    )
                  else ...[
                    _MenuTile(
                      icon: Icons.settings_outlined,
                      title: 'Cài đặt ứng dụng',
                      onTap: () => _openPage(context, const AppSettingsScreen()),
                    ),
                    _MenuTile(
                      icon: Icons.edit_outlined,
                      title: 'Chỉnh sửa thông tin',
                      subtitle: 'Ảnh, họ tên, quốc tịch',
                      onTap: () => _openPage(context, const EditProfileScreen()),
                    ),
                    _MenuTile(
                      icon: Icons.favorite_outline_rounded,
                      title: 'Danh sách yêu thích',
                      subtitle: '${favoritesStore.entries.length} mục đã lưu',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const FavoritesScreen(),
                        ),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.location_on_outlined,
                      title: 'Lịch sử check-in',
                      onTap: () => _openPage(
                        context,
                        const AccountActivityScreen(isReview: false),
                      ),
                    ),
                    _MenuTile(
                      icon: Icons.star_border_rounded,
                      title: 'Đánh giá của tôi',
                      onTap: () => _openPage(
                        context,
                        const AccountActivityScreen(isReview: true),
                      ),
                    ),

                    _MenuTile(
                      icon: Icons.lock_outline_rounded,
                      title: 'Đổi mật khẩu',
                      onTap: () => _openPage(context, const ChangePasswordScreen()),
                    ),
                    const SizedBox(height: 8),
                    _MenuTile(
                      icon: Icons.logout_rounded,
                      title: 'Đăng xuất',
                      danger: true,
                      onTap: () => _logout(context),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _profileHeader({required bool signedIn, required String title}) {
    final photo = _profilePhotoUrl(userSession.avatarUrl);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 43,
            backgroundColor: const Color(0xFFE4F0E9),
            backgroundImage: photo == null ? null : NetworkImage(photo),
            child: photo == null
                ? const Icon(Icons.person_outline, size: 46, color: _green)
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            signedIn ? title : 'Khách',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (signedIn && userSession.email != null) ...[
            const SizedBox(height: 4),
            Text(userSession.email!, style: const TextStyle(color: Colors.black54)),
          ],
          if (signedIn && userSession.nationality?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(userSession.nationality!, style: const TextStyle(color: Colors.black54)),
          ],
        ],
      ),
    );
  }

  Future<void> _openPage(BuildContext context, Widget page) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => page),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật thành công.')),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có muốn đăng xuất khỏi tài khoản này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    var revokedOnServer = false;
    final token = userSession.token;
    if (token != null) {
      final api = AuthApiService();
      try {
        await api.logout(token: token);
        revokedOnServer = true;
      } catch (_) {
        // Always clear local credentials so the user can leave the account.
      } finally {
        api.close();
      }
    }
    userSession.signOut();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(revokedOnServer
              ? 'Đã đăng xuất.'
              : 'Đã đăng xuất trên ứng dụng; chưa xác nhận được máy chủ.'),
        ),
      );
    }
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFB83B26) : _green;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: danger ? const Color(0xFFFFF0EA) : const Color(0xFFEAF3EF),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: danger ? color : Colors.black87)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right, color: Colors.black45),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with AppLocaleAwareState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _nationalityController;
  String _avatarUrl = '';
  bool _saving = false;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: userSession.fullName ?? '');
    _usernameController = TextEditingController(text: userSession.username ?? '');
    _emailController = TextEditingController(text: userSession.email ?? '');
    _nationalityController = TextEditingController(text: userSession.nationality ?? '');
    _avatarUrl = userSession.avatarUrl ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.image);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _uploading = true;
        _error = null;
      });
      _avatarUrl = await UploadService().uploadImage(
        bytes: bytes,
        fileName: file.name,
        folder: 'avatars',
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving || _uploading) return;
    final token = userSession.token;
    if (token == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = AuthApiService();
    try {
      final result = await api.updateProfile(
        token: token,
        username: _usernameController.text,
        email: _emailController.text,
        fullName: _nameController.text,
        nationality: _nationalityController.text,
        avatarUrl: _avatarUrl,
      );
      final rawUser = result['user'];
      final user = rawUser is Map ? rawUser : const <String, dynamic>{};
      userSession.updateProfile(
        email: (user['email'] ?? _emailController.text).toString(),
        username: (user['username'] ?? _usernameController.text).toString(),
        fullName: (user['fullName'] ?? _nameController.text).toString(),
        nationality: (user['nationality'] ?? _nationalityController.text).toString(),
        avatarUrl: (user['avatarUrl'] ?? _avatarUrl).toString(),
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể kết nối máy chủ.');
    } finally {
      api.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _profilePhotoUrl(_avatarUrl);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Chỉnh sửa thông tin'), backgroundColor: Theme.of(context).scaffoldBackgroundColor),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: const Color(0xFFE4F0E9),
                    backgroundImage: photo == null ? null : NetworkImage(photo),
                    child: photo == null ? const Icon(Icons.person, size: 54, color: _green) : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: IconButton.filled(
                      onPressed: _uploading ? null : _choosePhoto,
                      icon: _uploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _input(_nameController, 'Họ và tên', Icons.badge_outlined, validator: (value) => value == null || value.trim().isEmpty ? AppTranslations.translate('Nhập họ tên.') : null),
            _input(_usernameController, 'Tên tài khoản', Icons.person_outline, validator: (value) => value == null || !RegExp(r'^[a-zA-Z0-9_.-]{3,50}$').hasMatch(value.trim()) ? AppTranslations.translate('Tên tài khoản cần từ 3 đến 50 ký tự.') : null),
            _input(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (value) => value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim()) ? AppTranslations.translate('Email chưa hợp lệ.') : null),
            _input(_nationalityController, 'Quốc tịch', Icons.public_outlined),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving || _uploading ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _green),
                child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Lưu thay đổi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _input(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: (value) => AppTranslations.translateValidation(validator?.call(value)),
          decoration: InputDecoration(
            labelText: AppTranslations.translate(label),
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> with AppLocaleAwareState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    final token = userSession.token;
    if (token == null) return;
    setState(() { _saving = true; _error = null; });
    final api = AuthApiService();
    try {
      await api.changePassword(
        token: token,
        currentPassword: _current.text,
        newPassword: _next.text,
      );
      userSession.signOut();
      if (mounted) Navigator.pop(context, true);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể kết nối máy chủ.');
    } finally {
      api.close();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Đổi mật khẩu'), backgroundColor: Theme.of(context).scaffoldBackgroundColor),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _passwordInput(_current, 'Mật khẩu hiện tại'),
              _passwordInput(
                _next,
                'Mật khẩu mới',
                validator: (value) => value == null || value.length < 8 ? AppTranslations.translate('Mật khẩu mới cần ít nhất 8 ký tự.') : null,
              ),
              _passwordInput(
                _confirm,
                'Nhập lại mật khẩu mới',
                validator: (value) => value != _next.text ? AppTranslations.translate('Mật khẩu nhập lại chưa khớp.') : null,
              ),
              if (_error != null) Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _change,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Cập nhật mật khẩu'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _passwordInput(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
  }) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: controller,
          obscureText: true,
          validator: (value) => AppTranslations.translateValidation(validator?.call(value) ?? (value == null || value.isEmpty ? 'Nhập ' + label + '.' : null)),
          decoration: InputDecoration(
            labelText: AppTranslations.translate(label),
            prefixIcon: const Icon(Icons.lock_outline),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
}

class AccountActivityScreen extends StatefulWidget {
  const AccountActivityScreen({super.key, required this.isReview});
  final bool isReview;

  @override
  State<AccountActivityScreen> createState() => _AccountActivityScreenState();
}

class _AccountActivityScreenState extends State<AccountActivityScreen> with AppLocaleAwareState<AccountActivityScreen> {
  late Future<List<Map<String, dynamic>>> _checkins;
  late Future<List<Map<String, dynamic>>> _reviews;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  void _loadActivities() {
    final token = userSession.token;
    if (token == null) {
      _checkins = Future.value(const []);
      _reviews = Future.value(const []);
      return;
    }

    final api = AuthApiService();
    _checkins = api.getCheckins(token: token);
    _reviews = api.getReviews(token: token);
    unawaited(
      Future.wait<void>([
        _checkins.then<void>((_) {}),
        _reviews.then<void>((_) {}),
      ]).then<void>(
        (_) => api.close(),
        onError: (Object _, StackTrace __) => api.close(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(widget.isReview
              ? '\u0110\u00e1nh gi\u00e1 c\u1ee7a t\u00f4i'
              : 'L\u1ecbch s\u1eed check-in'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: _activityList(
          widget.isReview ? _reviews : _checkins,
          isReview: widget.isReview,
        ),
      );

  Widget _activityList(Future<List<Map<String, dynamic>>> future, {required bool isReview}) => FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final message = snapshot.error is AuthApiException
                ? (snapshot.error as AuthApiException).message
                : 'Không tải được dữ liệu. Kiểm tra kết nối backend rồi thử lại.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(_loadActivities),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Text(isReview ? 'Bạn chưa gửi đánh giá nào.' : 'Bạn chưa check-in địa điểm nào.'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final date = DateTime.tryParse((item[isReview ? 'createdAt' : 'checkedInAt'] ?? '').toString());
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((item[isReview ? 'placeName' : 'placeName'] ?? 'Địa điểm').toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (!isReview &&
                        (item['imageUrl'] ?? '').toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AppImage(
                          source: item['imageUrl'].toString(),
                          width: double.infinity,
                          height: 180,
                          fallbackIcon: Icons.location_city_outlined,
                        ),
                      ),
                    ],
                    if (!isReview &&
                        (item['feeling'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(item['feeling'].toString()),
                    ],
                    if (isReview) ...[
                      const SizedBox(height: 5),
                      Text('★ ${item['rating']}/5', style: const TextStyle(color: Color(0xFFB83B26))),
                      if ((item['comment'] ?? '').toString().isNotEmpty) Text(item['comment'].toString()),
                    ],
                    if (date != null) ...[
                      const SizedBox(height: 6),
                      Text('${date.day}/${date.month}/${date.year}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ],
                ),
              );
            },
          );
        },
      );
}

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> with AppLocaleAwareState<AppSettingsScreen> {
  static bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: const Text('Cài đặt ứng dụng')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _settingCard(
              SwitchListTile(
                value: _notificationsEnabled,
                onChanged: (value) => setState(() => _notificationsEnabled = value),
                secondary: const Icon(Icons.notifications_outlined, color: _green),
                title: const Text('Thông báo'),
                subtitle: const Text('Bật hoặc tắt thông báo ứng dụng'),
              ),
              context,
            ),
            _settingCard(
              SwitchListTile(
                value: AppThemeController.isDark,
                onChanged: (value) {
                  setState(() => AppThemeController.setDarkMode(value));
                },
                secondary: const Icon(Icons.dark_mode_outlined, color: _green),
                title: const Text('Giao diện tối'),
                subtitle: const Text('Chuyển nền ứng dụng sang tông màu tối'),
              ),
              context,
            ),
            _settingCard(
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined, color: _green),
                title: const Text('Xóa bộ nhớ đệm'),
                subtitle: const Text('Dọn hình ảnh tạm đang lưu trên thiết bị'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _clearImageCache,
              ),
              context,
            ),
            _settingCard(
              ListTile(
                leading: const Icon(Icons.language, color: _green),
                title: const Text('Ngôn ngữ'),
                trailing: DropdownButton<String>(
                  value: AppLocaleController.isEnglish ? 'English' : 'Tiếng Việt',
                  items: const [
                    DropdownMenuItem(value: 'Tiếng Việt', child: Text('Tiếng Việt')),
                    DropdownMenuItem(value: 'English', child: Text('English')),
                  ],
                  onChanged: (value) {
                    if (value != null) AppLocaleController.setLanguage(value == 'English' ? 'en' : 'vi');
                  },
                ),
              ),
              context,
            ),
            _settingCard(
              ListTile(
                leading: const Icon(Icons.info_outline, color: _green),
                title: const Text('Giới thiệu VN Guide'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const AboutVNGuideScreen(),
                  ),
                ),
              ),
              context,
            ),
            _settingCard(
              ListTile(
                leading: const Icon(Icons.mail_outline, color: _green),
                title: const Text('Liên hệ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ContactVNGuideScreen(),
                  ),
                ),
              ),
              context,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 18),
              child: Center(
                child: Text(
                  'VN Guide • Phiên bản 1.0.0',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      );

  void _clearImageCache() {
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache
      ..clear()
      ..clearLiveImages();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã xóa bộ nhớ đệm hình ảnh.')),
    );
  }

  Widget _settingCard(Widget child, BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: child,
      );
}
String? _profilePhotoUrl(String? value) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http://') || value.startsWith('https://')) return value;
  return '${ApiConfig.baseUrl}/api/images/$value';
}
