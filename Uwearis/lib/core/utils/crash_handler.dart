import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/generated/app_localizations_zh.dart';
import 'debug_log.dart';

class GlobalErrorHandler {
  static void initialize() {
    FlutterError.onError = _onFlutterError;
    PlatformDispatcher.instance.onError = _onPlatformError;

    if (!kDebugMode) {
      ErrorWidget.builder = _buildErrorWidget;
    }
  }

  // Flutter framework errors (widget build, layout, etc.)
  static void _onFlutterError(FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    } else {
      _log('Flutter', details.exception, details.stack);
    }
  }

  // Uncaught async / platform errors
  static bool _onPlatformError(Object error, StackTrace stack) {
    _log('Platform', error, stack);
    return true;
  }

  // Zone-level catch-all (called from runZonedGuarded in main.dart)
  static void onZoneError(Object error, StackTrace stack) {
    _log('Zone', error, stack);
  }

  static void _log(String source, Object error, StackTrace? stack) {
    debugLog('[$source] $error', error: error, stackTrace: stack);
    // TODO: replace with Crashlytics.recordError(error, stack) before launch
  }

  // ErrorWidget.builder gives no BuildContext, so this can't use
  // AppLocalizations.of(context) — look the strings up directly from the
  // device locale instead, falling back to the hardcoded Chinese default if
  // that locale isn't one gen-l10n knows about (this screen must never
  // throw itself).
  static AppLocalizations _errorScreenL10n() {
    try {
      return lookupAppLocalizations(PlatformDispatcher.instance.locale);
    } catch (_) {
      return AppLocalizationsZh();
    }
  }

  // Clean error screen shown in release mode instead of red screen
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
