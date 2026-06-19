import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'core/services/crash_handler.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    GlobalErrorHandler.initialize();
    runApp(const ProviderScope(child: App()));
  }, GlobalErrorHandler.onZoneError);
}