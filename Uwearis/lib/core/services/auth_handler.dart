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
import '../providers/trip_detail_provider.dart';
import '../providers/trip_suggestion_provider.dart';
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

/// Call wherever a session ends. Does not touch Riverpod providers — see
/// [invalidateSignedInProviders].
Future<void> clearSignedInSession() async {
  await AuthStorage.clear();
  await GarmentService().clearClosetAnalysisCache();
  GarmentService().clearGarmentCache();
  OutfitService().clearGroupCache();
}

/// Providers outlive the Navigator, so without this a new sign-in would see
/// the previous account's data. Call on successful login, NOT at logout:
/// the old MainShell's tabs still watch these providers until its route is
/// disposed (~300ms after `pushAndRemoveUntil`), and invalidating then makes
/// them refetch with no token and raise a spurious "Session Expired" dialog.
void invalidateSignedInProviders(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  container.invalidate(profileProvider);
  container.invalidate(garmentsProvider);
  container.invalidate(outfitsProvider);
  container.invalidate(tripsProvider);
  container.invalidate(tripDetailProvider);
  container.invalidate(tripSuggestionProvider);
  container.invalidate(dailyOutfitProvider);
  container.invalidate(styleProfileProvider);
  container.invalidate(styleTasteProfileProvider);
}

class AuthExpiredHandler {
  // Several mounted tabs can each report the same expired session.
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

      // Providers are invalidated on the next login, not here.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } finally {
      _isHandling = false;
    }
  }
}
