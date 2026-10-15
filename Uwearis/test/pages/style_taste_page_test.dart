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

/// Throws after a short delay: the page's AuthExpired listeners attach
/// post-frame, and an immediate throw would race ahead of them.
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
    // clearSignedInSession() touches SharedPreferences, which never
    // resolves in a test binding without this.
    SharedPreferences.setMockInitialValues({});
  });

  // ErrorStateWidget renders nothing for AuthExpiredException, so the page
  // needs its own listener to prompt re-login.
  testWidgets('an AuthExpiredException on styleTasteProfileProvider shows the '
      'session-expired dialog instead of going blank', (tester) async {
    await pumpApp(
      tester,
      const StyleTastePage(),
      overrides: [
        styleTasteProfileProvider.overrideWith(_FailingStyleTasteNotifier.new),
        styleProfileProvider.overrideWith(_EmptyStyleProfileNotifier.new),
        outfitsProvider.overrideWith(_EmptyOutfitsNotifier.new),
      ],
    );
    await tester.pump();
    // Past the override's delay plus AuthExpiredHandler's async chain.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text(_l10n.sessionExpiredTitle), findsOneWidget);
  });
}
