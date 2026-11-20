import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/features/pages/settings/my_outfit_profile_page.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';

// S2: My Outfit Profile's temperature offset must be the signed-in
// account's own. It used to come from one device-wide SharedPreferences
// key, so the next account to sign in saw — and stepped from — the
// previous one's value.

/// The backend: each account's `temperature_offset_c`, keyed by the
/// account in its bearer token (`access-A` → A).
class _Backend {
  _Backend(this.offsets);
  final Map<String, num?> offsets;
  final patches = <(String, Map<String, dynamic>)>[];

  /// When set, the next PATCH waits for it (applied on the server first).
  Completer<void>? holdNextPatch;

  /// When set, profile reads wait for it.
  Completer<void>? holdGets;

  /// While true, profile reads answer 500.
  bool failGets = false;

  static String _account(http.Request r) =>
      (r.headers['Authorization'] ?? '').replaceFirst('Bearer access-', '');

  Map<String, dynamic> _profile(String account) => {
    'name': 'User $account',
    'temperature_offset_c': offsets[account],
  };

  MockClient client() => MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (path.endsWith('/users/me')) {
      final account = _account(req);
      if (req.method == 'GET') await holdGets?.future;
      if (req.method == 'GET' && failGets) {
        return jsonResponse(envelope(null), status: 500);
      }
      if (req.method == 'PATCH') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        if (body.containsKey('temperature_offset_c')) {
          offsets[account] = body['temperature_offset_c'] as num;
          patches.add((account, body));
          final hold = holdNextPatch;
          holdNextPatch = null;
          if (hold != null) await hold.future;
        }
      }
      return jsonResponse(envelope(_profile(account)));
    }
    return jsonResponse(envelope({'items': <Object>[]}));
  });
}

final _plus = find.byIcon(Icons.add_circle_outline);

void main() {
  late ScriptedPrefsStore prefs;
  late BuildContext root;
  late ProviderContainer container;

  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    prefs = installPrefs();
    simulateRestart();
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> pumpRoot(WidgetTester tester) async {
    useTallSurface(tester);
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          root = context;
          return const Scaffold(body: Text('Root'));
        },
      ),
      retry: (_, _) => null,
    );
    container = ProviderScope.containerOf(root);
  }

  Future<void> openPage(WidgetTester tester) async {
    unawaited(
      Navigator.of(
        root,
      ).push(MaterialPageRoute(builder: (_) => const MyOutfitProfilePage())),
    );
    await settle(tester);
  }

  /// Back to Root with no route left over, as a sign-out's navigation does.
  Future<void> closePages(WidgetTester tester) async {
    Navigator.of(root).popUntil((r) => r.isFirst);
    await settle(tester);
  }

  /// Sign-out, then [account]'s sign-in, as the app does it: the session
  /// ends, the next one starts, signed-in providers are invalidated.
  Future<void> switchTo(WidgetTester tester, String account) async {
    await closePages(tester);
    await clearSignedInSession();
    await AuthStorage.startSession(
      accessToken: 'access-$account',
      refreshToken: 'refresh-$account',
    );
    container.invalidate(profileProvider);
    await tester.pump();
  }

  Future<void> step(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await settle(tester);
  }

  testWidgets("A sets +2 and signs out; B sees and steps from B's own value, "
      "and A signs back in to A's", (tester) async {
    final backend = _Backend({'A': 0, 'B': -1});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      expect(find.text('0°C'), findsOneWidget);
      await step(tester, _plus);
      await step(tester, _plus);
      expect(find.text('+2°C'), findsOneWidget);

      await switchTo(tester, 'B');
      await openPage(tester);
      expect(find.text('-1°C'), findsOneWidget, reason: "B's own value");
      expect(find.text('+2°C'), findsNothing, reason: "not A's");

      await step(tester, _plus);
      expect(backend.patches.last.$1, 'B');
      expect(backend.patches.last.$2, {'temperature_offset_c': 0});

      await switchTo(tester, 'A');
      await openPage(tester);
      expect(find.text('+2°C'), findsOneWidget, reason: "A's own value");
    }, backend.client);
    expect(backend.offsets, {'A': 2, 'B': 0});
  });

  testWidgets('A → B → C in quick succession: each sees only its own', (
    tester,
  ) async {
    final backend = _Backend({'A': 3, 'B': -2, 'C': null});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      expect(find.text('+3°C'), findsOneWidget);
      await switchTo(tester, 'B');
      await openPage(tester);
      expect(find.text('-2°C'), findsOneWidget);
      await switchTo(tester, 'C');
      await openPage(tester);
      expect(find.text('0°C'), findsOneWidget, reason: 'C never set one');
    }, backend.client);
  });

  testWidgets("A's save still in flight when B signs in: B's page shows B's "
      'value', (tester) async {
    final backend = _Backend({'A': 0, 'B': -3});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      final held = backend.holdNextPatch = Completer<void>();
      await tester.tap(_plus);
      await tester.pump();

      await switchTo(tester, 'B');
      held.complete();
      await settle(tester);
      await openPage(tester);

      expect(find.text('-3°C'), findsOneWidget);
      expect(find.text('+1°C'), findsNothing);
    }, backend.client);
  });

  testWidgets('after a session expiry the same account signs back in to its '
      'own value', (tester) async {
    final backend = _Backend({'A': -4});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      expect(find.text('-4°C'), findsOneWidget);

      unawaited(AuthExpiredHandler.handle(root));
      await settle(tester);
      expect(find.text('Session Expired'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await settle(tester);
      while (tester.takeException() != null) {}

      await AuthStorage.startSession(
        accessToken: 'access-A',
        refreshToken: 'refresh-A',
      );
      container.invalidate(profileProvider);
      unawaited(
        Navigator.of(
          tester.element(find.byType(Navigator).first),
        ).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MyOutfitProfilePage()),
          (_) => false,
        ),
      );
      await settle(tester);
      expect(find.text('-4°C'), findsOneWidget);
    }, backend.client);
  });

  testWidgets("a relaunch shows the account's value from the backend, not "
      'what this device cached for another account', (tester) async {
    final backend = _Backend({'A': 0, 'B': 2});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      await step(tester, _plus); // A: +1, cached on the device

      // B signs in on this device after a relaunch.
      await closePages(tester);
      simulateRestart();
      await AuthStorage.startSession(
        accessToken: 'access-B',
        refreshToken: 'refresh-B',
      );
      container.invalidate(profileProvider);
      await openPage(tester);

      expect(find.text('+2°C'), findsOneWidget);
    }, backend.client);
  });

  testWidgets('the legacy device-wide key is never taken as the account\'s '
      'value, and is removed', (tester) async {
    await prefs.setValue('Int', 'flutter.temperature_offset', 4);
    SharedPreferences.resetStatic();
    final backend = _Backend({'A': null});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      expect(find.text('0°C'), findsOneWidget);
      expect(find.text('+4°C'), findsNothing);
    }, backend.client);
    expect((await prefs.stored()).containsKey('temperature_offset'), isFalse);
  });

  testWidgets('one account: stepping saves it and reopening shows it', (
    tester,
  ) async {
    final backend = _Backend({'A': 1});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      expect(find.text('+1°C'), findsOneWidget);
      await step(tester, _plus);
      expect(find.text('+2°C'), findsOneWidget);

      await closePages(tester);
      await openPage(tester);
      expect(find.text('+2°C'), findsOneWidget);
    }, backend.client);
    expect(backend.patches.single.$1, 'A');
    expect(backend.patches.single.$2, {'temperature_offset_c': 2});
  });

  testWidgets('before the profile has loaded, + or − saves nothing; once it '
      "has, the account's value shows and steps from there", (tester) async {
    final backend = _Backend({'A': -3})..holdGets = Completer<void>();
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);

      await tester.tap(_plus, warnIfMissed: false);
      await tester.tap(
        find.byIcon(Icons.remove_circle_outline),
        warnIfMissed: false,
      );
      await settle(tester);
      expect(backend.patches, isEmpty, reason: 'nothing saved from a guess');

      backend.holdGets!.complete();
      await settle(tester);
      expect(find.text('-3°C'), findsOneWidget);

      await step(tester, _plus);
      expect(find.text('-2°C'), findsOneWidget);
    }, backend.client);
    expect(backend.patches.single.$2, {'temperature_offset_c': -2});
    expect(backend.offsets, {'A': -2});
  });

  testWidgets("a failed profile load saves nothing from + or −; once a retry "
      "loads it, the account's value shows and steps from there", (
    tester,
  ) async {
    final backend = _Backend({'A': -3})..failGets = true;
    await http.runWithClient(() async {
      await pumpRoot(tester);
      // Kept listened, as Settings keeps it, so appRetryPolicy's retries
      // run out before the failure settles.
      final sub = container.listen(profileProvider, (_, _) {});
      addTearDown(sub.close);
      await openPage(tester);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(container.read(profileProvider).hasError, isTrue);
      expect(find.text('0°C'), findsOneWidget, reason: 'nothing known yet');

      await tester.tap(_plus, warnIfMissed: false);
      await tester.tap(
        find.byIcon(Icons.remove_circle_outline),
        warnIfMissed: false,
      );
      await settle(tester);
      expect(backend.patches, isEmpty, reason: 'nothing saved from a guess');

      backend.failGets = false;
      await tester.tap(find.text('Retry'));
      await settle(tester);
      expect(find.text('-3°C'), findsOneWidget);

      await step(tester, _plus);
      expect(find.text('-2°C'), findsOneWidget);
    }, backend.client);
    expect(backend.patches.single.$2, {'temperature_offset_c': -2});
  });

  for (final saved in <num?>[0, null]) {
    testWidgets('a loaded profile whose offset is ${saved ?? 'unset'} steps '
        'from 0', (tester) async {
      final backend = _Backend({'A': saved});
      await http.runWithClient(() async {
        await pumpRoot(tester);
        await openPage(tester);
        expect(find.text('0°C'), findsOneWidget);
        await step(tester, _plus);
        expect(find.text('+1°C'), findsOneWidget);
      }, backend.client);
      expect(backend.patches.single.$2, {'temperature_offset_c': 1});
    });
  }

  testWidgets("a background refresh doesn't reset the shown value or the "
      'base a step starts from', (tester) async {
    final backend = _Backend({'A': -3});
    await http.runWithClient(() async {
      await pumpRoot(tester);
      await openPage(tester);
      expect(find.text('-3°C'), findsOneWidget);

      backend.holdGets = Completer<void>();
      unawaited(container.read(profileProvider.notifier).refresh());
      await settle(tester);
      expect(container.read(profileProvider).isLoading, isTrue);
      expect(find.text('-3°C'), findsOneWidget);

      await step(tester, _plus);
      expect(find.text('-2°C'), findsOneWidget);
      backend.holdGets!.complete();
      await settle(tester);
      expect(find.text('-2°C'), findsOneWidget);
    }, backend.client);
    expect(backend.patches.single.$2, {'temperature_offset_c': -2});
  });
}
