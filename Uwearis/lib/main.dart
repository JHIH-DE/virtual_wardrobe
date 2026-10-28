import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/app.dart';
import 'core/utils/crash_handler.dart';

void main() {
  // runZonedGuarded catches anything GlobalErrorHandler's hooks don't.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await GlobalErrorHandler.initialize();
    // Fonts ship in assets/google_fonts/; a style needing an unbundled weight
    // should fail in development, not silently hit fonts.gstatic.com.
    GoogleFonts.config.allowRuntimeFetching = false;
    runApp(const ProviderScope(child: App()));
  }, GlobalErrorHandler.onZoneError);
}
