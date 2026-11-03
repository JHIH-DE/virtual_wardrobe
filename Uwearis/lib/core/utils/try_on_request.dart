import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/outfit.dart';
import '../../data/trip_outfit.dart';
import '../services/api_exception.dart';
import '../services/auth_handler.dart';
import '../services/pending_try_on_store.dart';
import '../services/trip_service.dart';
import 'debug_log.dart';
import 'idempotency_key.dart';
import 'try_on_status.dart';

/// A try-on whose outcome isn't known: it may still finish (it then shows up
/// where its result belongs). Never a failure — don't show it as one, delete
/// anything, or send the same request again without the user's go-ahead.
class TryOnStillRunning implements Exception {
  /// The backend can't report this request's status, so asking again may
  /// render (and charge) again.
  final bool statusUnavailable;

  const TryOnStillRunning({required this.statusUnavailable});
}

/// No reply (timeout, dropped connection, gateway 5xx) or the backend says
/// the request is still running: the render may yet finish.
bool mayStillBeRunning(Object e) {
  if (e is TimeoutException ||
      e is http.ClientException ||
      e is SocketException) {
    return true;
  }
  if (e is ApiException) {
    if (e.errorCode == 'TRY_ON_GENERATION_IN_PROGRESS') return true;
    return e.errorCode == null && const {502, 503, 504}.contains(e.statusCode);
  }
  return false;
}

const _pollInterval = Duration(seconds: 3);
// ~5 minutes: longer than the backend's lease (240s), after which a keyed
// render has either finished or been declared failed.
const _maxStatusChecks = 100;
// Re-reading a whole trip collection is heavier than a status read: ~4
// minutes at 5s.
const _tripPollInterval = Duration(seconds: 5);
const _maxTripChecks = 48;

/// Sends a render that carries [key] (generate or regenerate). A lost reply
/// is recovered by asking for that key's status — never by sending again.
/// The key is kept in [PendingTryOnStore] until the outcome is known, so a
/// relaunch can still find out. Throws [TryOnStillRunning] when it can't be
/// known; anything else is a definitive failure (its quota was released).
Future<Outfit> sendKeyedTryOn({
  required String key,
  required int session,
  required Future<Outfit> Function() send,
  int? draftGroupId,
  int? regeneratedOutfitId,
}) async {
  PendingTryOnStore.markInFlight(key);
  try {
    await PendingTryOnStore.add(
      PendingTryOn(
        key: key,
        draftGroupId: draftGroupId,
        regeneratedOutfitId: regeneratedOutfitId,
        startedAt: DateTime.now(),
      ),
      forSession: session,
    );
    try {
      final outfit = await _sendOrRecover(key, session, send);
      await PendingTryOnStore.remove(key, forSession: session);
      return outfit;
    } on TryOnStillRunning {
      rethrow;
    } on AuthExpiredException {
      rethrow;
    } catch (_) {
      await PendingTryOnStore.remove(key, forSession: session);
      rethrow;
    }
  } finally {
    PendingTryOnStore.unmarkInFlight(key);
  }
}

Future<Outfit> _sendOrRecover(
  String key,
  int session,
  Future<Outfit> Function() send,
) async {
  try {
    return await send();
  } catch (e) {
    if (!mayStillBeRunning(e)) rethrow;
    debugLog('try-on: outcome unknown ($e), checking its status');
  }
  for (var check = 1; ; check++) {
    // Signed out meanwhile: the next account's token can't see this key.
    if (PendingTryOnStore.session != session) {
      throw const TryOnStillRunning(statusUnavailable: false);
    }
    final result = await checkTryOnStatus(key);
    switch (result.kind) {
      case TryOnCheck.succeeded:
        return result.outfit!;
      case TryOnCheck.failed:
        throw ApiException(
          statusCode: 500,
          errorCode: result.errorCode,
          message: 'Try-on generation failed',
        );
      case TryOnCheck.notReceived:
        // Nothing was charged; safe to treat as a plain failure.
        throw const ApiException(
          statusCode: 404,
          errorCode: 'TRY_ON_GENERATION_NOT_FOUND',
          message: 'Try-on request not received',
        );
      case TryOnCheck.unavailable:
        throw const TryOnStillRunning(statusUnavailable: true);
      case TryOnCheck.running:
      case TryOnCheck.unreachable:
        break;
    }
    if (check >= _maxStatusChecks) {
      throw const TryOnStillRunning(statusUnavailable: false);
    }
    await Future<void>.delayed(_pollInterval);
  }
}

/// What a trip outfit's image is right now: which outfit holds it and which
/// stored object it points at (a re-render writes a new object, so the
/// signed URL's path changes even though the outfit id doesn't).
String tripOutfitImageMarker(TripOutfit outfit) {
  final url = outfit.resultImageUrl;
  final path = url == null || url.isEmpty ? '' : Uri.parse(url).path;
  return '${outfit.outfitId}|$path';
}

/// The trip's outfits if [tripOutfitId]'s image has changed from
/// [beforeMarker] — i.e. a try-on landed. Null when unchanged, gone, or the
/// read failed (all "unknown"); with [rethrowNotFound], a 404 (the trip was
/// deleted) is thrown instead.
Future<TripOutfitCollection?> landedTripTryOn({
  required int tripId,
  required int tripOutfitId,
  required String beforeMarker,
  bool rethrowNotFound = false,
}) async {
  try {
    final collection = await TripService().getTripOutfits(tripId);
    final outfit = collection.outfits
        .where((o) => o.id == tripOutfitId)
        .firstOrNull;
    if (outfit == null || !outfit.hasImage) return null;
    return tripOutfitImageMarker(outfit) == beforeMarker ? null : collection;
  } on AuthExpiredException {
    rethrow;
  } on ApiException catch (e) {
    if (rethrowNotFound && e.statusCode == 404) rethrow;
    debugLog('try-on: trip check failed: $e');
    return null;
  } catch (e) {
    debugLog('try-on: trip check failed: $e');
    return null;
  }
}

/// A trip outfit's try-on. Its endpoint takes no Idempotency-Key and has no
/// status, so a lost reply is recovered only by re-reading the trip and
/// seeing [before]'s image change; if it hasn't by the end, the outcome is
/// unknown ([TryOnStillRunning] with `statusUnavailable`) and asking again
/// may render again.
Future<TripOutfitCollection> sendTripTryOn({
  required int tripId,
  required TripOutfit before,
  required int session,
  required Future<TripOutfitCollection> Function() send,
}) async {
  final key = 'trip-${newIdempotencyKey()}';
  final marker = tripOutfitImageMarker(before);
  PendingTryOnStore.markInFlight(key);
  try {
    await PendingTryOnStore.add(
      PendingTryOn(
        key: key,
        kind: PendingTryOnKind.trip,
        tripId: tripId,
        tripOutfitId: before.id,
        imageMarker: marker,
        startedAt: DateTime.now(),
      ),
      forSession: session,
    );
    try {
      final collection = await send();
      await PendingTryOnStore.remove(key, forSession: session);
      return collection;
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
      if (!mayStillBeRunning(e)) {
        await PendingTryOnStore.remove(key, forSession: session);
        rethrow;
      }
      debugLog('trip try-on: outcome unknown ($e), re-reading the trip');
    }
    for (var check = 1; ; check++) {
      if (PendingTryOnStore.session != session) {
        throw const TryOnStillRunning(statusUnavailable: true);
      }
      final landed = await landedTripTryOn(
        tripId: tripId,
        tripOutfitId: before.id,
        beforeMarker: marker,
      );
      if (landed != null) {
        await PendingTryOnStore.remove(key, forSession: session);
        return landed;
      }
      if (check >= _maxTripChecks) {
        throw const TryOnStillRunning(statusUnavailable: true);
      }
      await Future<void>.delayed(_tripPollInterval);
    }
  } finally {
    PendingTryOnStore.unmarkInFlight(key);
  }
}
