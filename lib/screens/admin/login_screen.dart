import 'package:hcm_explorer/widgets/app_ui.dart';

import '../../services/auth_api_service.dart';
import 'admin_dashboard_screen.dart';

const Color _adminGreen = Color(0xFF176B5B);
const Color _adminGreenDark = Color(0xFF104E43);
const Color _adminRed = Color(0xFFC6422D);
const Color _adminCream = Color(0xFFFAF7F2);

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with AppLocaleAwareState<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = AuthApiService();
    try {
      final result = await auth.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;

      final dynamic rawUser = result['user'];
      final Map<String, dynamic> user = rawUser is Map
          ? Map<String, dynamic>.from(rawUser)
          : <String, dynamic>{};
      final role = (user['role'] ?? result['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      final token = (result['token'] ?? '').toString();

      if (role != 'admin') {
        setState(() {
          _errorMessage = 'Tài khoản này không có quyền quản trị viên.';
          _isLoading = false;
        });
        return;
      }
      if (token.isEmpty) {
        setState(() {
          _errorMessage = 'Máy chủ chưa trả về token đăng nhập. Vui lòng kiểm tra API.';
          _isLoading = false;
        });
        return;
      }
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => AdminDashboardScreen(
            token: token,
            adminName: (user['fullName'] ?? user['username'] ?? 'Quản trị viên').toString(),
          ),
        ),
        (_) => false,
      );
    } on AuthApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không kết nối được máy chủ. Hãy kiểm tra backend và API_BASE_URL.';
        _isLoading = false;
      });
      debugPrint('Admin login error: $error');
    } finally {
      auth.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _adminCream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return Row(
                children: [
                  Expanded(child: _buildBrandPanel(isCompact: false)),
                  Expanded(
                    child: Container(
                      color: _adminCream,
                      child: _buildLoginForm(),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: _buildBrandPanel(isCompact: true),
                ),
                Expanded(
                  child: Container(
                    color: _adminCream,
                    child: _buildLoginForm(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandPanel({required bool isCompact}) {
    return Container(
      color: _adminGreenDark,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 28 : 72, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'VN Guide Admin',
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 34 : 54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Hệ thống quản trị nội dung cẩm nang du lịch và văn hóa Việt Nam.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: isCompact ? 16 : 21,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Đăng nhập quản trị',
                  style: TextStyle(
                    color: Color(0xFF202622),
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _identifierController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration('Tên đăng nhập', Icons.person_outline),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? AppTranslations.translate('Vui lòng nhập tài khoản.')
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  decoration: _inputDecoration('Mật khẩu', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      tooltip: AppTranslations.translate(_obscurePassword ? 'Hiện mật khẩu' : 'Ẩn mật khẩu'),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    ),
                  ),
                  validator: (value) => (value == null || value.isEmpty)
                      ? AppTranslations.translate('Vui lòng nhập mật khẩu.')
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF3C7BC)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: _adminRed, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: _adminRed))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: _adminRed,
                      disabledBackgroundColor: _adminRed.withValues(alpha: 0.55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Đăng nhập', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Quay lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: AppTranslations.translate(label),
      prefixIcon: Icon(icon, color: _adminGreen),
      filled: true,
      fillColor: const Color(0xFFFCFAF7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4DED5))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE4DED5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _adminGreen, width: 1.5)),
    );
  }
}
