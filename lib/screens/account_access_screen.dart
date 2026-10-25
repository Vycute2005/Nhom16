import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hcm_explorer/widgets/app_ui.dart';

import '../config/api_config.dart';
import '../services/auth_api_service.dart';
import '../services/favorites_store.dart';
import '../services/google_sign_in_service.dart';
import '../widgets/google_sign_in_auth_button.dart';
import 'admin/admin_dashboard_screen.dart';
import 'forgot_password_screen.dart';

enum LoginPromptChoice { login, register }

Future<bool> requestAccountAccess(BuildContext context) async {
  final token = userSession.token;
  if (userSession.isSignedIn && token != null && token.isNotEmpty) return true;

  final choice = await showDialog<LoginPromptChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(Icons.favorite_rounded,
          color: Color(0xFFB83B26), size: 34),
      title: const Text('Đăng nhập để yêu thích'),
      content: const Text(
        'Đăng nhập để lưu món ăn, danh lam và lịch trình vào mục Đã lưu.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Để sau'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.pop(dialogContext, LoginPromptChoice.register),
          child: const Text('Đăng ký'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFF0F5B49)),
          onPressed: () =>
              Navigator.pop(dialogContext, LoginPromptChoice.login),
          child: const Text('Đăng nhập'),
        ),
      ],
    ),
  );

  if (choice == null || !context.mounted) return false;
  final signedIn = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => AccountAccessScreen(
        openRegistration: choice == LoginPromptChoice.register,
      ),
    ),
  );
  return signedIn == true;
}

class AccountAccessScreen extends StatefulWidget {
  final bool openRegistration;

  const AccountAccessScreen({super.key, this.openRegistration = false});

  @override
  State<AccountAccessScreen> createState() => _AccountAccessScreenState();
}

class _AccountAccessScreenState extends State<AccountAccessScreen> with AppLocaleAwareState<AccountAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isRegistering;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _errorMessage;

  bool get _supportsGoogle =>
      kIsWeb ||
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    _isRegistering = widget.openRegistration;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _saveSession(Map<String, dynamic> result) {
    if (!mounted) return;

    final rawUser = result['user'];
    final user = rawUser is Map ? rawUser : const <String, dynamic>{};
    final token = result['token']?.toString();

    final role = (user['role'] ?? result['role'] ?? 'user')
        .toString()
        .trim()
        .toLowerCase();
    if (role == 'admin') {
      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Máy chủ chưa trả về token đăng nhập quản trị.';
        });
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => AdminDashboardScreen(
            token: token,
            adminName: (user['fullName'] ?? user['username'] ?? 'Quản trị viên')
                .toString(),
          ),
        ),
        (_) => false,
      );
      return;
    }

    userSession.signIn(
      (user['email'] ?? _emailController.text.trim()).toString(),
      username: user['username']?.toString(),
      fullName: user['fullName']?.toString(),
      nationality: user['nationality']?.toString(),
      avatarUrl: user['avatarUrl']?.toString(),
      token: token,
    );
    if (token != null && token.isNotEmpty) {
      unawaited(
        favoritesStore
            .syncFromServer(token)
            .catchError((Object _) {}),
      );
    }
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = AuthApiService();
    try {
      final result = _isRegistering
          ? await api.register(
              username: _usernameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await api.login(
              identifier: _emailController.text.trim(),
              password: _passwordController.text,
            );
      _saveSession(result);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Không thể kết nối máy chủ (${ApiConfig.baseUrl}). '
              'Hãy chạy backend: cd backend; dart run bin/server.dart.',
        );
      }
    } finally {
      api.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final idToken = await GoogleSignInService.authenticate();
      if (idToken != null) {
        await _authenticateGoogleToken(idToken);
      }
    } on StateError catch (error) {
      if (mounted) setState(() => _errorMessage = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Kh\u{00f4}ng th\u{1ec3} \u{0111}\u{0103}ng nh\u{1ead}p b\u{1eb1}ng Google l\u{00fac} n\u{00e0}y.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogleToken(String idToken) async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _authenticateGoogleToken(idToken);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _authenticateGoogleToken(String idToken) async {
    final api = AuthApiService();
    try {
      final result = await api.googleLogin(idToken: idToken);
      _saveSession(result);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Kh\u{00f4}ng th\u{1ec3} \u{0111}\u{0103}ng nh\u{1ead}p b\u{1eb1}ng Google l\u{00fac} n\u{00e0}y.',
        );
      }
    } finally {
      api.close();
    }
  }

  void _showGoogleError(String message) {
    if (mounted) setState(() => _errorMessage = message);
  }

  Future<void> _openForgotPassword() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ForgotPasswordScreen(
          initialEmail: _emailController.text.trim(),
        ),
      ),
    );
    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đổi mật khẩu. Hãy đăng nhập lại.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegistering ? 'Tạo tài khoản' : 'Chào mừng trở lại';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(_isRegistering ? 'Đăng ký' : 'Đăng nhập'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.favorite_rounded,
                      color: Color(0xFFB83B26), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Đăng nhập để lưu các mục yêu thích của bạn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  if (_isRegistering) ...[
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Tên tài khoản'),
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (!_isRegistering) return null;
                        final username = value?.trim() ?? '';
                        return RegExp(r'^[a-zA-Z0-9_.-]{3,50}$')
                                .hasMatch(username)
                            ? null
                            : AppTranslations.translate('Tên tài khoản cần 3–50 ký tự (chữ, số, . _ -)');
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: _isRegistering
                        ? TextInputType.emailAddress
                        : TextInputType.text,
                    decoration: InputDecoration(
                      labelText:
                          _isRegistering ? 'Email' : 'Tài khoản hoặc email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final identifier = value?.trim() ?? '';
                      if (!_isRegistering) {
                        return identifier.isEmpty
                            ? AppTranslations.translate('Nhập tài khoản hoặc email')
                            : null;
                      }
                      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(identifier)
                          ? null
                          : AppTranslations.translate('Nhập email hợp lệ');
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Mật khẩu'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip:
                            AppTranslations.translate(_obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return AppTranslations.translate('Nhập mật khẩu');
                      if (_isRegistering && value!.length < 8) {
                        return AppTranslations.translate('Mật khẩu cần ít nhất 8 ký tự');
                      }
                      return null;
                    },
                  ),
                  if (!_isRegistering)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : _openForgotPassword,
                        child: const Text('Quên mật khẩu?'),
                      ),
                    ),
                  if (_isRegistering) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirmation,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Nhập lại mật khẩu'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: AppTranslations.translate(_obscureConfirmation
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu'),
                          onPressed: () => setState(() =>
                              _obscureConfirmation = !_obscureConfirmation),
                          icon: Icon(_obscureConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? AppTranslations.translate('Mật khẩu nhập lại chưa khớp')
                          : null,
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5B49),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isLoading ? null : _continue,
                      child: Text(_isLoading
                          ? 'Đang xử lý...'
                          : (_isRegistering ? 'Tạo tài khoản' : 'Đăng nhập')),
                    ),
                  ),
                  if (_supportsGoogle) ...[
                    const SizedBox(height: 10),
                    GoogleSignInAuthButton(
                      isRegistering: _isRegistering,
                      enabled: !_isLoading,
                      onPressed: _continueWithGoogle,
                      onIdToken: _submitGoogleToken,
                      onError: _showGoogleError,
                    ),
                  ],
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                              _isRegistering = !_isRegistering;
                              _errorMessage = null;
                            }),
                    child: Text(
                      _isRegistering
                          ? 'Đã có tài khoản? Đăng nhập'
                          : 'Chưa có tài khoản? Đăng ký',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
