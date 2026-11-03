import '../../data/outfit.dart';
import '../../data/trip_outfit.dart';
import '../services/api_exception.dart';
import '../services/auth_handler.dart';
import '../services/outfit_service.dart';
import '../services/pending_try_on_store.dart';
import 'debug_log.dart';
import 'image_cache_bust.dart';
import 'try_on_request.dart';
import 'try_on_status.dart';

/// What [recoverPendingTryOns] found, for the caller to refresh.
class TryOnRecovery {
  /// Create Outfit renders and regenerates that landed (Outfits changed).
  final int outfitsLanded;

  /// Trips whose outfit got its try-on, with their current outfits.
  final Map<int, TripOutfitCollection> trips;

  const TryOnRecovery({this.outfitsLanded = 0, this.trips = const {}});

  static const none = TryOnRecovery();
}

/// Settles try-ons the app lost track of (killed or restarted mid-render).
/// Only reads — it never sends another render, and it only deletes a draft
/// group once its try-on is known to have produced nothing and the group is
/// confirmed empty.
Future<TryOnRecovery> recoverPendingTryOns({DateTime? now}) async {
  // Every await below may outlast a sign-out; past that point nothing may be
  // removed, deleted or reported for the account that was signed in.
  final session = PendingTryOnStore.session;
  bool signedOut() => PendingTryOnStore.session != session;
  final pending = await PendingTryOnStore.load();
  if (pending.isEmpty || signedOut()) return TryOnRecovery.none;
  final clock = now ?? DateTime.now();
  var landed = 0;
  final trips = <int, TripOutfitCollection>{};

  for (final p in pending) {
    if (PendingTryOnStore.isInFlight(p.key)) continue;
    final age = clock.difference(p.startedAt);
    if (age > PendingTryOnStore.maxAge) {
      // Settled long ago either way; a landed result is already in place.
      await PendingTryOnStore.remove(p.key, forSession: session);
      continue;
    }
    try {
      switch (p.kind) {
        case PendingTryOnKind.keyed:
          if (await _settleKeyed(p, age, session)) landed++;
        case PendingTryOnKind.trip:
          final collection = await _settleTrip(p, session);
          if (collection != null) trips[p.tripId!] = collection;
      }
    } on AuthExpiredException {
      break;
    }
    if (signedOut()) return TryOnRecovery.none;
  }
  if (signedOut()) return TryOnRecovery.none;
  return TryOnRecovery(outfitsLanded: landed, trips: trips);
}

/// True when it landed.
Future<bool> _settleKeyed(PendingTryOn p, Duration age, int session) async {
  final check = await checkTryOnStatus(p.key);
  if (PendingTryOnStore.session != session) return false;
  debugLog('recoverPendingTryOns: ${check.kind.name}');
  switch (check.kind) {
    case TryOnCheck.succeeded:
      _bumpRegenerated(p);
      await PendingTryOnStore.remove(p.key, forSession: session);
      return true;
    case TryOnCheck.failed:
      await PendingTryOnStore.remove(p.key, forSession: session);
      await _deleteDraftIfEmpty(p.draftGroupId, session);
      return false;
    case TryOnCheck.notReceived:
      // A request sent just before the app died may still be arriving.
      if (age < const Duration(minutes: 2)) return false;
      await PendingTryOnStore.remove(p.key, forSession: session);
      await _deleteDraftIfEmpty(p.draftGroupId, session);
      return false;
    case TryOnCheck.unavailable:
      // Without a status endpoint only a new outfit's draft can be checked.
      final draft = p.draftGroupId;
      if (draft == null) return false;
      try {
        final found = await landedInDraft(draft) != null;
        if (!found || PendingTryOnStore.session != session) return false;
        await PendingTryOnStore.remove(p.key, forSession: session);
        return true;
      } on AuthExpiredException {
        rethrow;
      } catch (e) {
        debugLog('recoverPendingTryOns: draft check failed: $e');
        return false;
      }
    case TryOnCheck.running:
    case TryOnCheck.unreachable:
      return false;
  }
}

/// A regenerate overwrites the image at the same URL.
void _bumpRegenerated(PendingTryOn p) {
  final id = p.regeneratedOutfitId;
  if (id != null) ImageCacheBust.bump(outfitImageCacheKey(id));
}

/// The trip's outfits when its try-on landed; null otherwise (kept until it
/// does or ages out, unless the trip is gone).
Future<TripOutfitCollection?> _settleTrip(PendingTryOn p, int session) async {
  final tripId = p.tripId;
  final tripOutfitId = p.tripOutfitId;
  final marker = p.imageMarker;
  if (tripId == null || tripOutfitId == null || marker == null) {
    await PendingTryOnStore.remove(p.key, forSession: session);
    return null;
  }
  try {
    final landed = await landedTripTryOn(
      tripId: tripId,
      tripOutfitId: tripOutfitId,
      beforeMarker: marker,
      rethrowNotFound: true,
    );
    if (landed == null || PendingTryOnStore.session != session) return null;
    final outfitId = landed.outfits
        .where((o) => o.id == tripOutfitId)
        .firstOrNull
        ?.outfitId;
    if (outfitId != null) ImageCacheBust.bump(outfitImageCacheKey(outfitId));
    await PendingTryOnStore.remove(p.key, forSession: session);
    return landed;
  } on ApiException catch (e) {
    // The trip was deleted: nothing left to update.
    if (e.statusCode == 404) {
      await PendingTryOnStore.remove(p.key, forSession: session);
    }
    return null;
  }
}

Future<void> _deleteDraftIfEmpty(int? groupId, int session) async {
  if (groupId == null) return;
  try {
    if (await landedInDraft(groupId) != null) return;
    if (PendingTryOnStore.session != session) return;
    await OutfitService().deleteGroup(groupId);
  } catch (e) {
    // Left in place: an empty group is invisible in Outfits.
    debugLog('recoverPendingTryOns: draft cleanup skipped: $e');
  }
}
