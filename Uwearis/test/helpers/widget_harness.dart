import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/utils/route_observer.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

/// Pumps [child] as `home` in a ProviderScope + MaterialApp with the real
/// l10n delegates.
///
/// [retry] passes through to [ProviderScope.retry] (raw function type:
/// Riverpod doesn't export its `Retry` typedef). Pass `(_, _) => null` so a
/// simulated provider failure is terminal instead of retrying.
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
        // As in app.dart — RouteAware widgets (e.g. RemovableCard) need it.
        navigatorObservers: [routeObserver],
        home: child,
      ),
    ),
  );
}
