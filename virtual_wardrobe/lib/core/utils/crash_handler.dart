import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
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

  // Clean error screen shown in release mode instead of red screen
  static Widget _buildErrorWidget(FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.icon),
              const SizedBox(height: 16),
              const Text(
                '發生了一點問題',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('請重新啟動 App，若問題持續請聯繫客服。', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
