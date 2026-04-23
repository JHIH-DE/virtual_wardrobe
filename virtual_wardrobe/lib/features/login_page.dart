import 'dart:io';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app/theme/app_colors.dart';
import '../core/services/login_service.dart';
import '../data/token_storage.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '223311252510-haiarn37l0h64lo3ju07j05kjdv7lssj.apps.googleusercontent.com',
    scopes: const ['email', 'profile', 'openid'],
  );

  bool _isLoading = false;

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
      if (account == null) return;

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google login failed: missing idToken');
      }
      final token = await LoginService().loginWithGoogleIdToken(idToken);
      await TokenStorage.saveAccessToken(token);

      Fluttertoast.showToast(msg: 'Google login success');
      await _goHome();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    setState(() => _isLoading = true);
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final idToken = credential.identityToken;
      if (idToken == null) throw Exception('Apple login failed: missing idToken');

      final token = await LoginService().loginWithAppleIdToken(idToken);
      await TokenStorage.saveAccessToken(token);

      Fluttertoast.showToast(msg: 'Apple login success');
      await _goHome();
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithFacebook() async {
    setState(() => _isLoading = true);
    try {
      debugPrint('--- _loginWithFacebook - Start ---');
      final LoginResult result = await FacebookAuth.instance.login();
      debugPrint('--- _loginWithFacebook - Status: ${result.status} ---');

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final token = await LoginService().loginWithFaceBookIdToken(accessToken.tokenString);
        await TokenStorage.saveAccessToken(token);

        Fluttertoast.showToast(msg: 'Facebook login success');
        await _goHome();
      } else if (result.status == LoginStatus.cancelled) {
        return;
      } else {
        throw Exception('Facebook login failed: ${result.message}');
      }
    } catch (e) {
      debugPrint('--- _loginWithFacebook - Error: $e ---');
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 68,
                    ),
                    const SizedBox(height: 50),
                    Image.asset(
                      'assets/images/main-character.png',
                      height: 422,
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -30), // 這裡控制覆蓋的高度
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, -10), // 向上位移的陰影
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Log-In / Sign-in to get dressed!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 22 / 16,
                          letterSpacing: 16 * 0.02,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (Platform.isIOS) ...[
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
                        const SizedBox(height: 15),
                      ],
                      if (Platform.isAndroid) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            onPressed: _isLoading ? null : _loginWithGoogle,
                            icon: Image.network(
                              'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
                              height: 24,
                            ),
                            label: Text(
                              'Sign in with Google',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                height: 22 / 16,
                                letterSpacing: 16 * 0.02,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                      ],
                      // Facebook login
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.facebook,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          onPressed: _isLoading ? null : _loginWithFacebook,
                          icon: const Icon(Icons.facebook, size: 28, color: AppColors.textPrimaryInv),
                          label: Text(
                            'Sign in with Facebook',
                            style: GoogleFonts.roboto(
                              fontSize: 18,
                              color: AppColors.textPrimaryInv,
                              fontWeight: FontWeight.w700,
                              height: 22 / 16,
                              letterSpacing: 16 * 0.02,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'copyright reserved to LUMI inc.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          height: 22 / 16,
                          letterSpacing: 16 * 0.02,
                        ),
                      ),
                    ],
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
