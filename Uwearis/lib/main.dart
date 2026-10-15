import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/utils/crash_handler.dart';

void main() {
  // runZonedGuarded catches anything GlobalErrorHandler's hooks don't.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GlobalErrorHandler.initialize();
    runApp(const ProviderScope(child: App()));
  }, GlobalErrorHandler.onZoneError);
}
