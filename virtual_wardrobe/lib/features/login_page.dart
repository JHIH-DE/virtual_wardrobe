import 'package:flutter/material.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../app/theme/app_colors.dart';
import '../core/services/login_service.dart';
import '../data/token_storage.dart';
import '../l10n/app_strings.dart';
import 'home_page.dart';

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

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await _googleSignIn.signOut();

      final account = await _googleSignIn.signIn();
      if (account == null) {
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google login failed: missing idToken');
      }
      final token = await LoginService().loginWithGoogleIdToken(idToken);
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

  Future<void> _loginWithApple() async {
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

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  onPressed: _isLoading ? null : _loginWithApple,
                  icon: const Icon(Icons.apple, size: 28),
                  label: const Text(
                    'Continue with Apple',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 10),
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
            ],
          ),
        ),
      ),
    );
  }
}
