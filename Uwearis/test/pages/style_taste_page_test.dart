import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/style_profile_provider.dart';
import 'package:uwearis/core/providers/style_taste_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/style_profile.dart';
import 'package:uwearis/data/style_taste.dart';
import 'package:uwearis/features/pages/style_taste_page.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/fake_auth.dart';
import '../helpers/widget_harness.dart';

final _l10n = AppLocalizationsEn();

/// Throws after a short real delay, not immediately — the page's
/// AuthExpired listeners only attach inside initState's
/// addPostFrameCallback (after the first frame); a real network failure
/// always arrives well after that point, but a provider override that
/// throws on the very first microtask can race ahead of it.
class _FailingStyleTasteNotifier extends StyleTasteProfileNotifier {
  @override
  Future<StyleTasteProfile> build() async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    throw AuthExpiredException();
  }
}

class _EmptyStyleProfileNotifier extends StyleProfileNotifier {
  @override
  Future<List<StyleProfileItem>> build() async => const [];
}

class _EmptyOutfitsNotifier extends OutfitsNotifier {
  @override
  Future<List<Outfit>> build() async => const [];
}

void main() {
  setUp(() {
    setUpFakeAuth();
    // AuthExpiredHandler.handle's clearSignedInSession() touches
    // SharedPreferences (GarmentService's closet-analysis cache) — without
    // this it never resolves in a test binding with no platform channel to
    // answer it.
    SharedPreferences.setMockInitialValues({});
  });

  // Regression: styleTasteProfileProvider/styleProfileProvider were only
  // ever read here via `.watch(...).when(...)`, with no AuthExpired
  // listener of their own. ErrorStateWidget deliberately renders nothing
  // for an AuthExpiredException (it expects a listener elsewhere to own the
  // redirect), so a session expiring while on this page used to just go
  // blank instead of prompting to log back in.
  testWidgets(
    'an AuthExpiredException on styleTasteProfileProvider shows the '
    'session-expired dialog instead of going blank',
    (tester) async {
      await pumpApp(
        tester,
        const StyleTastePage(),
        overrides: [
          styleTasteProfileProvider.overrideWith(
            _FailingStyleTasteNotifier.new,
          ),
          styleProfileProvider.overrideWith(_EmptyStyleProfileNotifier.new),
          outfitsProvider.overrideWith(_EmptyOutfitsNotifier.new),
        ],
      );
      await tester.pump();
      // Real time past the override's 50ms delay, plus
      // AuthExpiredHandler's own async chain (clearSignedInSession) before
      // it calls showDialog.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.sessionExpiredTitle), findsOneWidget);
    },
  );
}
