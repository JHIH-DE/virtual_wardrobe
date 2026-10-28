import 'dart:convert';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import 'debug_log.dart';

class GlobalErrorHandler {
  // True only once Crashlytics is up in a non-debug build; every reporting
  // call is a no-op otherwise (debug runs, tests, missing Firebase config).
  static bool _reporting = false;

  static Future<void> initialize() async {
    FlutterError.onError = _onFlutterError;
    PlatformDispatcher.instance.onError = _onPlatformError;

    if (!kDebugMode) {
      ErrorWidget.builder = _buildErrorWidget;
    }

    try {
      await Firebase.initializeApp();
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      _reporting = !kDebugMode;
    } catch (e) {
      // A build without GoogleService-Info.plist / google-services.json
      // must still launch.
      debugLog('Crash reporting unavailable: $e');
    }
  }

  /// Tags later reports with the backend user id (the access token's `sub`);
  /// pass null at sign-out. Never an email or name.
  static Future<void> setReportingUser(String? accessToken) async {
    if (!_reporting) return;
    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(
        userIdFromToken(accessToken) ?? '',
      );
    } catch (e) {
      debugLog('setReportingUser failed: $e');
    }
  }

  @visibleForTesting
  static String? userIdFromToken(String? token) {
    final parts = token?.split('.');
    if (parts == null || parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final sub = payload is Map ? payload['sub'] : null;
      return sub?.toString();
    } catch (_) {
      return null;
    }
  }

  static void _onFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
      return;
    }
    _log('Flutter', details.exception, details.stack);
    if (_reporting) FirebaseCrashlytics.instance.recordFlutterError(details);
  }

  static bool _onPlatformError(Object error, StackTrace stack) {
    _log('Platform', error, stack);
    _recordFatal(error, stack);
    return true;
  }

  // Called from runZonedGuarded in main.dart.
  static void onZoneError(Object error, StackTrace stack) {
    _log('Zone', error, stack);
    _recordFatal(error, stack);
  }

  static void _recordFatal(Object error, StackTrace stack) {
    if (!_reporting) return;
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }

  static void _log(String source, Object error, StackTrace? stack) {
    debugLog('[$source] $error', error: error, stackTrace: stack);
  }

  // ErrorWidget.builder has no BuildContext; look up by device locale and
  // fall back to zh for an unsupported one (this screen must never throw).
  static AppLocalizations _errorScreenL10n() {
    try {
      return lookupAppLocalizations(PlatformDispatcher.instance.locale);
    } catch (_) {
      return AppLocalizationsZh();
    }
  }

  // Release-mode replacement for the red error screen.
  static Widget _buildErrorWidget(FlutterErrorDetails details) {
    final l10n = _errorScreenL10n();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.icon),
              const SizedBox(height: 16),
              Text(l10n.crashScreenTitle, style: AppTextStyle.bold18),
              const SizedBox(height: 8),
              Text(l10n.crashScreenMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
