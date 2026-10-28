import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../app/main_shell.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/config/env.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/auth_storage.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/crash_handler.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/external_links.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/overlays/error_dialog.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _googleSignInInitialized = false;
  bool _isLoading = false;

  /// `GoogleSignIn.instance.initialize()` must be awaited exactly once,
  /// before any other GoogleSignIn call (process-wide singleton).
  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: Platform.isIOS && Env.googleIosClientId.isNotEmpty
          ? Env.googleIosClientId
          : null,
      serverClientId: Env.googleClientId,
    );
    _googleSignInInitialized = true;
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _goHome() async {
    await GlobalErrorHandler.setReportingUser(
      await AuthStorage.getAccessToken(),
    );
    if (!mounted) return;
    // Here, not at logout — see invalidateSignedInProviders.
    invalidateSignedInProviders(context);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _showErrorDialog(String msg) =>
      showErrorDialog(context, message: msg);

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    if (Platform.isIOS && Env.googleIosClientId.isEmpty) {
      _showErrorDialog(_l10n.googleLoginNotConfiguredIOS);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _ensureGoogleSignInInitialized();
      await GoogleSignIn.instance.signOut();
      final account = await GoogleSignIn.instance.authenticate();

      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        _showErrorDialog(_l10n.googleLoginMissingToken);
        return;
      }
      final tokens = await AuthService().loginWithGoogleIdToken(idToken);
      await AuthStorage.saveAccessToken(tokens.accessToken);
      await AuthStorage.saveRefreshToken(tokens.refreshToken);

      Fluttertoast.showToast(msg: _l10n.googleLoginSuccess);
      await _goHome();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      debugLog('Google sign-in failed: ${e.code} ${e.description}');
      _showErrorDialog(_l10n.loginFailed);
    } catch (e) {
      debugLog('Google login failed: $e');
      _showErrorDialog(apiErrorMessage(_l10n, e, fallback: _l10n.loginFailed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithApple() async {
    if (_isLoading) return;
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
        _showErrorDialog(_l10n.appleLoginMissingToken);
        return;
      }

      // Apple sends the name only on the first authorization.
      final name = [
        credential.givenName,
        credential.familyName,
      ].nonNulls.where((s) => s.isNotEmpty).join(' ');

      final tokens = await AuthService().loginWithAppleIdToken(
        idToken,
        name: name.isNotEmpty ? name : null,
      );
      await AuthStorage.saveAccessToken(tokens.accessToken);
      await AuthStorage.saveRefreshToken(tokens.refreshToken);

      Fluttertoast.showToast(msg: _l10n.appleLoginSuccess);
      await _goHome();
    } catch (e) {
      if (e is SignInWithAppleAuthorizationException &&
          e.code == AuthorizationErrorCode.canceled) {
        return;
      }
      debugLog('Apple login failed: $e');
      _showErrorDialog(apiErrorMessage(_l10n, e, fallback: _l10n.loginFailed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithFacebook() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      debugLog('--- _loginWithFacebook - Start ---');
      final LoginResult result = await FacebookAuth.instance.login();
      debugLog('--- _loginWithFacebook - Status: ${result.status} ---');

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final tokens = await AuthService().loginWithFacebookAccessToken(
          accessToken.tokenString,
        );
        await AuthStorage.saveAccessToken(tokens.accessToken);
        await AuthStorage.saveRefreshToken(tokens.refreshToken);

        Fluttertoast.showToast(msg: _l10n.facebookLoginSuccess);
        await _goHome();
      } else if (result.status == LoginStatus.cancelled) {
        return;
      } else {
        debugLog(
          '--- _loginWithFacebook - Failed: ${result.status} ${result.message} ---',
        );
        _showErrorDialog(_l10n.loginFailed);
      }
    } catch (e) {
      debugLog('--- _loginWithFacebook - Error: $e ---');
      _showErrorDialog(apiErrorMessage(_l10n, e, fallback: _l10n.loginFailed));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.paddingOf(context).top + 16),
                  const Spacer(),
                  _buildBrandHeader(),
                  const Spacer(),
                  _buildHeaderImage(),
                  const Spacer(),
                  _buildLoginCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            _l10n.appTitle,
            style: AppTextStyle.brandTitle.copyWith(
              fontSize: 44,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _l10n.loginTagline,
            textAlign: TextAlign.center,
            style: AppTextStyle.medium16.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderImage() {
    return AspectRatio(
      aspectRatio: 1 / 0.62,
      child: Image.asset('assets/images/login_image.png', fit: BoxFit.cover),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        math.max(MediaQuery.paddingOf(context).bottom - 8, 12),
      ),
      decoration: BoxDecoration(
        color: AppColors.pageBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, -10), // Shadow shifted upward
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
          const SizedBox(height: 20),
          const _TermsNotice(),
          const SizedBox(height: 12),
          _buildCopyrightText(),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return Text(
      _l10n.loginHeading,
      textAlign: TextAlign.center,
      style: AppTextStyle.bold18,
    );
  }

  Widget _buildAppleButton() {
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
        onPressed: _isLoading ? null : _loginWithApple,
        icon: const Icon(Icons.apple, size: 28, color: AppColors.textPrimary),
        label: Text(_l10n.continueWithApple, style: AppTextStyle.bold18),
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
        icon: Image.asset('assets/images/google_g.png', height: 24),
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
      style: AppTextStyle.regular12.copyWith(color: AppColors.hintText),
    );
  }
}

/// The sign-in consent line, with Terms / Privacy as in-app links.
class _TermsNotice extends StatefulWidget {
  const _TermsNotice();

  @override
  State<_TermsNotice> createState() => _TermsNoticeState();
}

class _TermsNoticeState extends State<_TermsNotice> {
  late final _termsTap = TapGestureRecognizer()
    ..onTap = () => openTermsOfService(context);
  late final _privacyTap = TapGestureRecognizer()
    ..onTap = () => openPrivacyPolicy(context);

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Sentinels stand in for the links so each locale keeps its own order.
    const termsMark = '\u0001';
    const privacyMark = '\u0002';
    final template = l10n.loginTermsNotice(termsMark, privacyMark);
    final base = AppTextStyle.regular12.copyWith(
      color: AppColors.textSecondary,
    );
    final link = base.copyWith(
      color: AppColors.textPrimary,
      decoration: TextDecoration.underline,
    );

    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp('[$termsMark$privacyMark]').allMatches(template)) {
      if (m.start > last) {
        spans.add(TextSpan(text: template.substring(last, m.start)));
      }
      final isTerms = m.group(0) == termsMark;
      spans.add(
        TextSpan(
          text: isTerms ? l10n.termsOfService : l10n.privacyPolicy,
          style: link,
          recognizer: isTerms ? _termsTap : _privacyTap,
        ),
      );
      last = m.end;
    }
    if (last < template.length) {
      spans.add(TextSpan(text: template.substring(last)));
    }
    return Text.rich(
      TextSpan(children: spans),
      style: base,
      textAlign: TextAlign.center,
    );
  }
}
