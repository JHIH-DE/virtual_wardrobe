import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/pages/login_page.dart';
import '../../features/widgets/common/overlays/app_dialog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../providers/daily_outfit_provider.dart';
import '../providers/garments_provider.dart';
import '../providers/outfits_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/style_profile_provider.dart';
import '../providers/style_taste_provider.dart';
import '../providers/trips_provider.dart';
import 'auth_storage.dart';
import 'garment_service.dart';
import 'outfit_service.dart';

class AuthExpiredException implements Exception {
  final String _message;
  AuthExpiredException([this._message = 'Authentication expired']);
  @override
  String toString() => _message;
}

/// Clears the parts of session-scoped state that are always safe to drop
/// immediately — call this at every point a signed-in session ends
/// ([AuthExpiredHandler.handle], `settings_page._logout`), before showing
/// any "you're signed out" UI. Deliberately does **not** touch Riverpod
/// providers; see [invalidateSignedInProviders] for why that part has to
/// wait.
Future<void> clearSignedInSession() async {
  await AuthStorage.clear();
  await GarmentService().clearClosetAnalysisCache();
  GarmentService().clearGarmentCache();
  OutfitService().clearGroupCache();
}

/// Invalidates every per-user provider so the next time each is read it
/// re-fetches instead of returning the previous account's already-resolved
/// data. Call this from [LoginPage]'s own successful-login handler
/// (`_goHome`), right before navigating to a fresh [MainShell] — **not**
/// at logout/session-expiry time.
///
/// That ordering is load-bearing, not a style choice: `MainShell` keeps
/// all 4 main tabs alive underneath whatever's pushed on top of it (a
/// settings screen, a "Session Expired" dialog, …), and several of those
/// tabs actively `ref.watch` these exact providers. Invalidating one while
/// it's still watched forces Riverpod to rebuild it *immediately* — and a
/// route pushed via `pushAndRemoveUntil` does **not** dispose the routes
/// it's removing until its own push-transition animation finishes
/// (Flutter's `Navigator` internals gate old-route disposal on the new
/// route reaching `_RouteLifecycle.idle`), which for a plain
/// `MaterialPageRoute` is ~300ms later — far longer than a single
/// `addPostFrameCallback` waits. Invalidating at logout time, however
/// "deferred", still lands while those tabs are demonstrably still
/// mounted and watching, so the eager rebuild still fails against the
/// access token [clearSignedInSession] just cleared, and that tab's own
/// `main_tab_async` error listener routes the resulting
/// [AuthExpiredException] straight back into [AuthExpiredHandler.handle]
/// — a spurious "Session Expired" dialog on what was actually a normal,
/// intentional logout (this was tried and confirmed to still reproduce).
///
/// Invalidating at a *successful login* instead sidesteps the timing
/// question entirely: by the time a login round-trip (a real OAuth
/// provider flow) completes, the old `MainShell` from the earlier logout
/// is certainly long disposed, so nothing is watching these providers yet
/// — and [AuthStorage] already holds the *new* account's fresh tokens by
/// this point, so even in-flight readers succeed instead of throwing.
///
/// Neither Riverpod's `ProviderScope` nor [GarmentService]/[OutfitService]'s
/// singleton in-memory caches are torn down just because the app's
/// `Navigator` route stack gets reset to `LoginPage` — they live for the
/// whole process, one level above the `Navigator`. Left alone, every
/// already-resolved provider (profile, closet, outfits, trips, daily
/// outfit, style profile/taste) would keep showing the previous account's
/// data after a fresh sign-in. This app has no stable local user id to
/// scope a per-user cache key by instead (see [AuthStorage]'s own doc
/// comment) — invalidating everything on sign-in is what actually
/// prevents that leak.
///
/// The avatar/face-reference/body-reference photos don't need an explicit
/// bump here the way the providers above do: `AppImage`'s cache for those
/// three is keyed by the signed URL itself (no separate stable cache key —
/// see `AccountPage`/`TryonProfilePage`), and a freshly signed-in account's
/// `/users/me` naturally returns a different URL than the previous
/// account's, so there's no shared cache key for a stale entry to hide
/// behind.
void invalidateSignedInProviders(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.invalidate(profileProvider);
  container.invalidate(garmentsProvider);
  container.invalidate(outfitsProvider);
  container.invalidate(tripsProvider);
  container.invalidate(dailyOutfitProvider);
  container.invalidate(styleProfileProvider);
  container.invalidate(styleTasteProfileProvider);
}

class AuthExpiredHandler {
  // Several tabs can be mounted at once (e.g. under a persistent shell),
  // each independently watching for a 401. Without this guard, a single
  // expired token would trigger this dialog+redirect once per tab.
  static bool _isHandling = false;

  static Future<void> handle(BuildContext context) async {
    if (_isHandling) return;
    _isHandling = true;
    try {
      await clearSignedInSession();

      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AppDialog(
          title: l10n.sessionExpiredTitle,
          body: l10n.sessionExpiredMessage,
          primaryLabel: l10n.ok,
          onPrimary: () => Navigator.of(ctx).pop(),
        ),
      );

      if (!context.mounted) return;

      // Navigate after the dialog closes. Provider invalidation happens on
      // the next successful login instead — see
      // invalidateSignedInProviders's own doc comment for why.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } finally {
      _isHandling = false;
    }
  }
}
