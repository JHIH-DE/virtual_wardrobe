import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/config/env.dart';
import '../core/services/auth_service.dart';
import '../core/services/auth_storage.dart';
import '../app/main_shell.dart';
import '../core/utils/debug_log.dart';
import '../l10n/generated/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: Platform.isIOS && Env.googleIosClientId.isNotEmpty
        ? Env.googleIosClientId
        : null,
    serverClientId: Env.googleClientId,
    scopes: const ['email', 'profile', 'openid'],
  );

  bool _isLoading = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _goHome() async {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loginWithGoogle() async {
    if (Platform.isIOS && Env.googleIosClientId.isEmpty) {
      _showSnack(_l10n.googleLoginNotConfiguredIOS);
      return;
    }
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
      final tokens = await AuthService().loginWithGoogleIdToken(idToken);
      await AuthStorage.saveAccessToken(tokens.accessToken);
      await AuthStorage.saveRefreshToken(tokens.refreshToken);

      Fluttertoast.showToast(msg: _l10n.googleLoginSuccess);
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
      if (idToken == null) {
        throw Exception('Apple login failed: missing idToken');
      }

      final tokens = await AuthService().loginWithAppleIdToken(idToken);
      await AuthStorage.saveAccessToken(tokens.accessToken);
      await AuthStorage.saveRefreshToken(tokens.refreshToken);

      Fluttertoast.showToast(msg: _l10n.appleLoginSuccess);
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
      debugLog('--- _loginWithFacebook - Start ---');
      final LoginResult result = await FacebookAuth.instance.login();
      debugLog('--- _loginWithFacebook - Status: ${result.status} ---');

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final tokens = await AuthService().loginWithFaceBookIdToken(
          accessToken.tokenString,
        );
        await AuthStorage.saveAccessToken(tokens.accessToken);
        await AuthStorage.saveRefreshToken(tokens.refreshToken);

        Fluttertoast.showToast(msg: _l10n.facebookLoginSuccess);
        await _goHome();
      } else if (result.status == LoginStatus.cancelled) {
        return;
      } else {
        throw Exception('Facebook login failed: ${result.message}');
      }
    } catch (e) {
      debugLog('--- _loginWithFacebook - Error: $e ---');
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              _buildHeaderImages(),
              _buildLoginCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderImages() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Image.asset('assets/images/logo.png', height: 68),
          const SizedBox(height: 50),
          Image.asset('assets/images/main-character.png', height: 422),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Transform.translate(
      offset: const Offset(0, -30), // 這裡控制覆蓋的高度
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.pageBackground,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, -10), // 向上位移的陰影
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeading(),
            const SizedBox(height: 20),
            if (Platform.isIOS) ...[
              _buildAppleButton(),
              const SizedBox(height: 15),
            ],
            _buildGoogleButton(),
            const SizedBox(height: 15),
            _buildFacebookButton(),
            const SizedBox(height: 24),
            _buildCopyrightText(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return Text(
      _l10n.loginHeading,
      textAlign: TextAlign.center,
      style: GoogleFonts.roboto(
        fontSize: 18,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        height: 22 / 16,
        letterSpacing: 16 * 0.02,
      ),
    );
  }

  Widget _buildAppleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        onPressed: _isLoading ? null : _loginWithApple,
        icon: const Icon(Icons.apple, size: 28),
        label: Text(_l10n.continueWithApple, style: AppTextStyle.semibold16),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        onPressed: _isLoading ? null : _loginWithGoogle,
        icon: Image.network(
          'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
          height: 24,
        ),
        label: Text(
          _l10n.signInWithGoogle,
          style: GoogleFonts.roboto(
            fontSize: 18,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            height: 22 / 16,
            letterSpacing: 16 * 0.02,
          ),
        ),
      ),
    );
  }

  Widget _buildFacebookButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.facebook,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(27),
          ),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        onPressed: _isLoading ? null : _loginWithFacebook,
        icon: const Icon(
          Icons.facebook,
          size: 28,
          color: AppColors.textOnPrimary,
        ),
        label: Text(
          _l10n.signInWithFacebook,
          style: GoogleFonts.roboto(
            fontSize: 18,
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w700,
            height: 22 / 16,
            letterSpacing: 16 * 0.02,
          ),
        ),
      ),
    );
  }

  Widget _buildCopyrightText() {
    return Text(
      _l10n.copyrightText,
      textAlign: TextAlign.center,
      style: GoogleFonts.roboto(
        fontSize: 16,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
        height: 22 / 16,
        letterSpacing: 16 * 0.02,
      ),
    );
  }
}
