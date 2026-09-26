import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/tryon_profile_page.dart';
import 'package:uwearis/features/widgets/common/images/app_image.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/widget_harness.dart';

final _l10n = AppLocalizationsEn();

/// A fully set-up profile (both reference photos + height/weight present)
/// by default — mirrors home_page_test.dart's `_FakeProfileNotifier`.
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier({ProfileData? data}) : data = data ?? _complete;

  static final _complete = ProfileData(
    profile: const UserProfile(
      name: 'Test User',
      height: 178,
      weight: 70,
      unitSystem: 'metric',
    ),
    bodyRefUrl: 'https://example.com/body.jpg',
    faceRefUrl: 'https://example.com/face.jpg',
  );

  final ProfileData data;

  @override
  Future<ProfileData> build() async => data;
}

/// Simulates `GET /users/me` itself failing (not an image load failure) —
/// the whole-page error path.
class _FailingProfileNotifier extends ProfileNotifier {
  @override
  Future<ProfileData> build() async => throw Exception('boom');
}

Future<void> _pumpTryonProfilePage(
  WidgetTester tester, {
  ProfileNotifier? notifier,
  Duration? Function(int retryCount, Object error)? retry,
}) {
  return pumpApp(
    tester,
    const TryonProfilePage(),
    overrides: [
      profileProvider.overrideWith(() => notifier ?? _FakeProfileNotifier()),
    ],
    retry: retry,
  );
}

AppImage _appImageFor(WidgetTester tester, String urlSubstring) {
  return tester
      .widgetList<AppImage>(find.byType(AppImage))
      .firstWhere((w) => (w.url ?? '').contains(urlSubstring));
}

void main() {
  testWidgets(
    'a body reference image load failure switches only the body card into '
    'its re-upload state — face card, height/weight and the page-level '
    'error banner are all untouched',
    (tester) async {
      await _pumpTryonProfilePage(tester);
      await tester.pump();

      // Sanity: everything starts normal.
      expect(find.text(_l10n.bodyReferenceLabel), findsOneWidget);
      expect(find.text(_l10n.faceReferenceLabel), findsOneWidget);
      expect(find.text('178'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);
      expect(find.byType(AppImage), findsNWidgets(2));

      _appImageFor(tester, 'body').onLoadError!();
      await tester.pump();

      // Body card flipped into its actionable re-upload state.
      expect(find.text(_l10n.bodyReferenceLoadFailedTitle), findsOneWidget);
      expect(find.text(_l10n.referenceLoadFailedSubtitle), findsOneWidget);
      expect(find.text(_l10n.reuploadPhotoAction), findsOneWidget);
      expect(find.text(_l10n.bodyReferenceLabel), findsNothing);

      // Face card is completely unaffected — still its normal state.
      expect(find.text(_l10n.faceReferenceLabel), findsOneWidget);
      expect(find.text(_l10n.faceAppearanceSubtitle), findsOneWidget);
      expect(find.byType(AppImage), findsOneWidget);

      // Profile fields (height/weight) are untouched.
      expect(find.text('178'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);

      // No page-level error banner — this never became an API/provider error.
      expect(find.text(_l10n.failedToLoad), findsNothing);
    },
  );

  testWidgets(
    'a face reference image load failure switches only the face card into '
    'its re-upload state — body card, height/weight and the page-level '
    'error banner are all untouched',
    (tester) async {
      await _pumpTryonProfilePage(tester);
      await tester.pump();

      _appImageFor(tester, 'face').onLoadError!();
      await tester.pump();

      expect(find.text(_l10n.faceReferenceLoadFailedTitle), findsOneWidget);
      expect(find.text(_l10n.referenceLoadFailedSubtitle), findsOneWidget);
      expect(find.text(_l10n.reuploadPhotoAction), findsOneWidget);
      expect(find.text(_l10n.faceReferenceLabel), findsNothing);

      expect(find.text(_l10n.bodyReferenceLabel), findsOneWidget);
      expect(find.text(_l10n.bodyProportionsSubtitle), findsOneWidget);
      expect(find.byType(AppImage), findsOneWidget);

      expect(find.text('178'), findsOneWidget);
      expect(find.text('70'), findsOneWidget);

      expect(find.text(_l10n.failedToLoad), findsNothing);
    },
  );

  testWidgets(
    'GET /users/me itself failing still shows the page-level error state '
    '(unchanged behaviour) — distinct from a per-image load failure',
    (tester) async {
      await _pumpTryonProfilePage(
        tester,
        notifier: _FailingProfileNotifier(),
        // The failure must be terminal for this test — Riverpod's default
        // AsyncNotifier retry-with-backoff would otherwise keep `.future`
        // pending instead of rejecting.
        retry: (_, _) => null,
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.failedToLoad), findsOneWidget);
      // Neither card's actionable re-upload copy applies here — this is the
      // whole-page fallback, not a per-photo state.
      expect(find.text(_l10n.faceReferenceLoadFailedTitle), findsNothing);
      expect(find.text(_l10n.bodyReferenceLoadFailedTitle), findsNothing);
    },
  );
}
