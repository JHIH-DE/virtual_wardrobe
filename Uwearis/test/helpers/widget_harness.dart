import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

/// Pumps [child] as the app's `home`, wrapped in a ProviderScope and a
/// MaterialApp carrying the real l10n delegates — enough for any widget that
/// calls `AppLocalizations.of(context)` or Material localizations.
///
/// Pass a `Scaffold` as [child] when the widget under test needs one
/// (an `appBar:` slot, a `RefreshIndicator`, `ScaffoldMessenger`, …).
Future<void> pumpApp(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}
