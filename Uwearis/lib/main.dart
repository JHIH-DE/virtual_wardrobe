import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app/app.dart';
import 'core/config/env.dart';
import 'core/utils/crash_handler.dart';

Future<void> main() async {
  // SentryFlutter.init wraps everything as a safety net (native crashes,
  // anything outside our own zone), but GlobalErrorHandler.initialize()
  // still runs its own FlutterError.onError/ErrorWidget.builder afterward
  // for the app's clean error screen — actual reporting to Sentry happens
  // from there (see GlobalErrorHandler._log), not from Sentry's own default
  // integrations, so the two don't fight over the same hooks.
  await SentryFlutter.init((options) {
    options.dsn = Env.sentryDsn;
    options.environment = kDebugMode ? 'debug' : 'production';
  }, appRunner: () => _runApp());
}

void _runApp() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GlobalErrorHandler.initialize();
    runApp(const ProviderScope(child: App()));
  }, GlobalErrorHandler.onZoneError);
}
