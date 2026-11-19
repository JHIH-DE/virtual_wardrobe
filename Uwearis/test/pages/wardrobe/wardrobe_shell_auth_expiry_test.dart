import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/wardrobe_shell.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/points_provider.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/core/providers/weather_provider.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/points.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';

import '../../helpers/points_fixture.dart';
import '../../helpers/widget_harness.dart';

/// What every signed-in fetch answers for the account currently signed in —
/// a dead session fails them all at once, as the backend does.
enum _Answer { ok, authExpired, serverError }

var _answer = _Answer.ok;

/// Non-zero: every fetch takes this long, so a sign-in can be interrupted
/// mid-fetch.
var _fetchDelay = Duration.zero;

Future<T> _fetch<T>(T value) async {
  if (_fetchDelay > Duration.zero) await Future<void>.delayed(_fetchDelay);
  switch (_answer) {
    case _Answer.ok:
      return value;
    case _Answer.authExpired:
      throw AuthExpiredException();
    case _Answer.serverError:
      throw const ApiException(statusCode: 500, message: 'server error');
  }
}

class _Garments extends GarmentsNotifier {
  @override
  Future<List<Garment>> build() => _fetch(const <Garment>[]);
}

class _Outfits extends OutfitsNotifier {
  @override
  Future<List<Outfit>> build() => _fetch(const <Outfit>[]);
}

class _Trips extends TripsNotifier {
  @override
  Future<List<Trip>> build() => _fetch(const <Trip>[]);
}

class _Profile extends ProfileNotifier {
  @override
  Future<ProfileData> build() => _fetch(
    ProfileData(
      profile: UserProfile(name: 'Test User', birthDate: DateTime(1995)),
    ),
  );
}

class _DailyOutfit extends DailyOutfitNotifier {
  @override
  Future<List<Outfit>> build() => _fetch(const <Outfit>[]);

  @override
  Future<void> refreshIfNeeded() async {}
}

class _Points extends PointsNotifier {
  @override
  Future<PointsSummary> build() =>
      _fetch(PointsSummary.fromJson(pointsSummaryJson()));
}

class _Weather extends WeatherNotifier {
  @override
  Future<WeatherData> build() async => WeatherData(
    location: 'Test City',
    temp: 20,
    high: 22,
    low: 18,
    condition: 'Clear',
    weeklyCodes: const [],
    weeklyHighs: const [],
    weeklyLows: const [],
    timestamp: DateTime.now().millisecondsSinceEpoch,
  );

  @override
  Future<void> refreshIfStale() async {}
}

final List<Override> _overrides = [
  garmentsProvider.overrideWith(_Garments.new),
  outfitsProvider.overrideWith(_Outfits.new),
  tripsProvider.overrideWith(_Trips.new),
  profileProvider.overrideWith(_Profile.new),
  dailyOutfitProvider.overrideWith(_DailyOutfit.new),
  pointsProvider.overrideWith(_Points.new),
  weatherProvider.overrideWith(_Weather.new),
];

void _signInAs(String account) {
  FlutterSecureStorage.setMockInitialValues({
    'access_token': 'access-$account',
    'refresh_token': 'refresh-$account',
  });
}

/// Lets frames, post-frame callbacks and a route transition run out. The
/// shell keeps a periodic timer, so pumpAndSettle never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump(const Duration(seconds: 1));
}

/// What `LoginPage._goHome` does after the provider sign-in succeeded.
Future<void> _completeLogin(WidgetTester tester) async {
  final login = tester.element(find.byType(LoginPage));
  invalidateSignedInProviders(login);
  Navigator.of(login).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const WardrobeShell()),
  );
  await _settle(tester);
}

/// What the user ended up with. Reading it also closes every Session
/// Expired dialog — [AuthExpiredHandler]'s dedupe flag is static and stays
/// set while a dialog is open, which would leak into the next test.
class _Outcome {
  _Outcome(this.sessionExpiredDialogs, this.onLogin, this.accessToken);
  final int sessionExpiredDialogs;
  final bool onLogin;
  final String? accessToken;
}

Future<_Outcome> _observe(WidgetTester tester) async {
  var dialogs = 0;
  while (find.text('Session Expired').evaluate().isNotEmpty) {
    dialogs++;
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await _settle(tester);
  }
  return _Outcome(
    dialogs,
    find.byType(LoginPage).evaluate().isNotEmpty,
    await AuthStorage.getAccessToken(),
  );
}

/// Session A's token dies while the shell is up: every tab's fetch fails
/// with [AuthExpiredException], the real [AuthExpiredHandler] runs, and the
/// user taps OK through to [LoginPage].
Future<_Outcome> _expireSessionA(WidgetTester tester) async {
  _signInAs('A');
  _answer = _Answer.authExpired;
  await pumpApp(
    tester,
    const WardrobeShell(),
    overrides: _overrides,
    retry: (_, _) => null,
  );
  await _settle(tester);
  return _observe(tester);
}

void main() {
  setUp(() {
    _answer = _Answer.ok;
    _fetchDelay = Duration.zero;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('receive_sharing_intent/messages'),
      (_) async => null,
    );
    messenger.setMockStreamHandler(
      const EventChannel('receive_sharing_intent/events-media'),
      MockStreamHandler.inline(onListen: (_, _) {}),
    );
  });

  testWidgets('every tab failing with AuthExpiredException at once shows one '
      'Session Expired dialog and lands on Login', (tester) async {
    final a = await _expireSessionA(tester);

    expect(a.sessionExpiredDialogs, 1);
    expect(a.onLogin, isTrue);
    expect(a.accessToken, isNull);
    expect(find.byType(WardrobeShell), findsNothing);
  });

  testWidgets('R1: signing in as B after A expired keeps B signed in — the '
      "providers' leftover AuthExpiredException from A is not B's", (
    tester,
  ) async {
    expect((await _expireSessionA(tester)).onLogin, isTrue);

    _signInAs('B');
    _answer = _Answer.ok;
    await _completeLogin(tester);
    final b = await _observe(tester);

    expect(b.sessionExpiredDialogs, 0);
    expect(b.onLogin, isFalse);
    expect(b.accessToken, 'access-B');
    expect(find.byType(WardrobeShell), findsOneWidget);
  });

  testWidgets('R1: A → B → C in quick succession — C is not signed out by '
      "a leftover error while B's fetches were still in flight", (
    tester,
  ) async {
    expect((await _expireSessionA(tester)).onLogin, isTrue);

    _signInAs('B');
    _answer = _Answer.ok;
    _fetchDelay = const Duration(milliseconds: 500);
    final login = tester.element(find.byType(LoginPage));
    invalidateSignedInProviders(login);
    Navigator.of(login).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const WardrobeShell()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final midB = await _observe(tester);

    // B logs out before its fetches land (Settings' logout path).
    if (!midB.onLogin) {
      await clearSignedInSession();
      Navigator.of(
        tester.element(find.byType(WardrobeShell)),
      ).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginPage()),
        (_) => false,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    _signInAs('C');
    _fetchDelay = Duration.zero;
    await _completeLogin(tester);
    final c = await _observe(tester);

    expect(midB.sessionExpiredDialogs, 0);
    expect(c.sessionExpiredDialogs, 0);
    expect(c.onLogin, isFalse);
    expect(c.accessToken, 'access-C');
  });

  testWidgets("B's own unrecoverable 401 after the sign-in still leads back "
      'to Login, once', (tester) async {
    expect((await _expireSessionA(tester)).onLogin, isTrue);

    _signInAs('B');
    _answer = _Answer.authExpired;
    await _completeLogin(tester);
    final b = await _observe(tester);

    expect(b.sessionExpiredDialogs, 1);
    expect(b.onLogin, isTrue);
    expect(b.accessToken, isNull);
  });

  testWidgets('a non-auth error does not sign the user out', (tester) async {
    _signInAs('A');
    _answer = _Answer.serverError;
    await pumpApp(
      tester,
      const WardrobeShell(),
      overrides: _overrides,
      retry: (_, _) => null,
    );
    await _settle(tester);
    final a = await _observe(tester);

    expect(a.sessionExpiredDialogs, 0);
    expect(a.onLogin, isFalse);
    expect(a.accessToken, 'access-A');
  });
}
