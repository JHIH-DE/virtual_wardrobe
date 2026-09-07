import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/utils/crash_handler.dart';

void main() {
  // GlobalErrorHandler installs FlutterError.onError / PlatformDispatcher.onError
  // / a release-mode error screen; runZonedGuarded catches anything that escapes
  // the zone. See crash_handler.dart.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GlobalErrorHandler.initialize();
    runApp(const ProviderScope(child: App()));
  }, GlobalErrorHandler.onZoneError);
}
