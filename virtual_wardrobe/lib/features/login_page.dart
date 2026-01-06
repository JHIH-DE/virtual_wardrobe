import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'home_page.dart';
import '../app/theme/app_colors.dart';
import '../l10n/app_strings.dart';
import '../core/services/auth_api.dart';
import '../core/services/token_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '223311252510-haiarn37l0h64lo3ju07j05kjdv7lssj.apps.googleusercontent.com',
    scopes: const ['email', 'profile', 'openid'],
  );

  bool _isLoading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loginWithEmail() async {
    final email = _accountController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please enter your account and password to continue.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final token = await AuthApi.loginWithEmail(email, password);
      await TokenStorage.saveAccessToken(token);

      Fluttertoast.showToast(
        msg: 'Login success',
        gravity: ToastGravity.CENTER,
        toastLength: Toast.LENGTH_SHORT,
      );

      await _goHome();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // 避免 iOS 有時會拿到舊帳號狀態
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        // 使用者取消
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google login failed: missing idToken');
      }
      final token = await AuthApi.loginWithGoogleIdToken(idToken);
      await TokenStorage.saveAccessToken(token);

      Fluttertoast.showToast(
        msg: 'Google login success',
        gravity: ToastGravity.CENTER,
        toastLength: Toast.LENGTH_SHORT,
      );

      await _goHome();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 50),
              const Text(
                'Welcome back — let’s get you dressed',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),

              TextField(
                controller: _accountController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  hintText: 'Email',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _loginWithEmail(),
                decoration: InputDecoration(
                  hintText: 'Password',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
                  ),
                ),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _isLoading ? null : _loginWithEmail,
                  child: _isLoading
                      ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text(
                    'Sign in',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Google Sign-in Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 10),
              TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                  _showSnack('TODO: Navigate to Register / Forgot Password');
                },
                child: const Text('Create account / Forgot password?'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}