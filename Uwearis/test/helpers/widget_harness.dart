import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/utils/route_observer.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

/// Pumps [child] as the app's `home`, wrapped in a ProviderScope and a
/// MaterialApp carrying the real l10n delegates — enough for any widget that
/// calls `AppLocalizations.of(context)` or Material localizations.
///
/// Pass a `Scaffold` as [child] when the widget under test needs one
/// (an `appBar:` slot, a `RefreshIndicator`, `ScaffoldMessenger`, …).
///
/// [retry] is a plain pass-through to [ProviderScope.retry] — typed as the
/// raw function shape rather than Riverpod's own `Retry` typedef, which
/// isn't part of its public export surface. Riverpod's `AsyncNotifier`s
/// retry a failed `build()` with backoff by default, which means a test
/// simulating a provider-level failure can otherwise hang waiting for
/// `.future` to settle — pass `(_, _) => null` to make the first failure
/// terminal.
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  Duration? Function(int retryCount, Object error)? retry,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: retry,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // Mirrors app.dart's MaterialApp — needed for any RouteAware page
        // under test (e.g. TripDetailsPage's didPopNext) to actually
        // receive push/pop notifications.
        navigatorObservers: [routeObserver],
        home: child,
      ),
    ),
  );
}
