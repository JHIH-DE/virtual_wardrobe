import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/trip_detail_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/trip_outfit.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/trip_outfit_error_text.dart';
import '../common/overlays/error_dialog.dart';

/// Shared by Trip Details and Trip Outfit Details: one collection change at
/// a time (each response replaces the whole collection, so two in flight
/// could land out of order), applied to [tripDetailProvider].
mixin TripCollectionActions<W extends ConsumerStatefulWidget>
    on ConsumerState<W> {
  int get tripId;

  bool _collectionActionInFlight = false;

  bool get isCollectionActionInFlight => _collectionActionInFlight;

  /// [request] returns null to cancel (e.g. a declined confirm) or after
  /// applying a non-collection result itself. Returns whether a collection
  /// was applied. The notifier is read before the await, so the result lands
  /// even if the page has gone.
  Future<bool> runCollectionAction({
    required Future<TripOutfitCollection?> Function() request,
    required String fallback,
  }) async {
    if (_collectionActionInFlight) return false;
    setState(() => _collectionActionInFlight = true);
    final detailNotifier = ref.read(tripDetailProvider(tripId).notifier);
    try {
      final collection = await request();
      if (collection == null) return false;
      detailNotifier.setCollection(collection);
      return true;
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return false;
    } catch (e) {
      debugLog('Trip outfit action failed: $e');
      if (mounted) {
        showErrorDialog(
          context,
          message: tripOutfitErrorMessage(
            AppLocalizations.of(context),
            e,
            fallback: fallback,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _collectionActionInFlight = false);
    }
  }
}
