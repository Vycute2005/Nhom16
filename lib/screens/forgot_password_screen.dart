import 'package:hcm_explorer/widgets/app_ui.dart';

import '../services/auth_api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> with AppLocaleAwareState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _otpSent = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _errorMessage;
  String? _statusMessage;
  String? _developmentOtp;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMessage = AppTranslations.translate('Nhập email hợp lệ'));
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final api = AuthApiService();
    try {
      final result = await api.forgotPassword(email: email);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _statusMessage = result['message']?.toString();
        _developmentOtp = result['developmentOtp']?.toString();
      });
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể kết nối máy chủ.');
      }
    } finally {
      api.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final api = AuthApiService();
    try {
      await api.resetPassword(
        email: _emailController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } on AuthApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Không thể kết nối máy chủ.');
      }
    } finally {
      api.close();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Quên mật khẩu'),
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
                  const Icon(Icons.lock_reset_rounded,
                      color: Color(0xFF0F5B49), size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Đặt lại mật khẩu',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Nhập email tài khoản để nhận mã xác nhận.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailController,
                    enabled: !_otpSent,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Email'),
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(email)
                          ? null
                          : AppTranslations.translate('Nhập email hợp lệ');
                    },
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Mã OTP'),
                        prefixIcon: Icon(Icons.pin_outlined),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                              ? null
                              : AppTranslations.translate('Nhập mã OTP gồm 6 chữ số'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Mật khẩu mới'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: AppTranslations.translate(_obscurePassword
                              ? 'Hiện mật khẩu'
                              : 'Ẩn mật khẩu'),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => (value ?? '').length >= 8
                          ? null
                          : AppTranslations.translate('Mật khẩu cần ít nhất 8 ký tự'),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscureConfirmation,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Nhập lại mật khẩu mới'),
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
                      validator: (value) => value == _passwordController.text
                          ? null
                          : AppTranslations.translate('Mật khẩu nhập lại chưa khớp'),
                    ),
                  ],
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(_statusMessage!,
                        style: const TextStyle(color: Color(0xFF0F5B49))),
                  ],
                  if (_developmentOtp != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Mã OTP thử nghiệm: $_developmentOtp',
                      style: const TextStyle(color: Colors.deepOrange),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(_errorMessage!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0F5B49),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isLoading
                          ? null
                          : (_otpSent ? _resetPassword : _requestOtp),
                      child: Text(
                        _isLoading
                            ? 'Đang xử lý...'
                            : (_otpSent ? 'Đặt lại mật khẩu' : 'Gửi mã OTP'),
                      ),
                    ),
                  ),
                  if (_otpSent)
                    TextButton(
                      onPressed: _isLoading ? null : _requestOtp,
                      child: const Text('Gửi mã mới'),
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
