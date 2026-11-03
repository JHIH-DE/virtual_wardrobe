import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/outfit.dart';
import '../../data/try_on_generation.dart';
import '../services/api_exception.dart';
import '../services/auth_handler.dart';
import '../services/outfit_service.dart';

/// What one status check says about a try-on sent with an Idempotency-Key.
enum TryOnCheck {
  /// Finished; [TryOnCheckResult.outfit] is the result.
  succeeded,

  /// Finished without a result; its quota was released.
  failed,

  /// Still running on the backend.
  running,

  /// The backend has no record of the key: the request never arrived.
  notReceived,

  /// This backend can't report status (no such endpoint — e.g. one that
  /// predates it). Says nothing about the try-on itself.
  unavailable,

  /// The check itself didn't get through (offline, timeout, 5xx).
  unreachable,
}

class TryOnCheckResult {
  final TryOnCheck kind;
  final Outfit? outfit;
  final String? errorCode;

  const TryOnCheckResult(this.kind, {this.outfit, this.errorCode});
}

/// Never throws except [AuthExpiredException]. Only [TryOnCheck.succeeded],
/// [TryOnCheck.failed] and [TryOnCheck.notReceived] are known outcomes;
/// everything else must be treated as "may still land".
Future<TryOnCheckResult> checkTryOnStatus(String key) async {
  try {
    final generation = await OutfitService().getGeneration(key);
    return switch (generation.status) {
      TryOnGenerationStatus.succeeded when generation.outfit != null =>
        TryOnCheckResult(TryOnCheck.succeeded, outfit: generation.outfit),
      // Succeeded, but the result was deleted since: nothing to show.
      TryOnGenerationStatus.succeeded => const TryOnCheckResult(
        TryOnCheck.failed,
        errorCode: 'TRY_ON_GENERATION_RESULT_GONE',
      ),
      TryOnGenerationStatus.failed => TryOnCheckResult(
        TryOnCheck.failed,
        errorCode: generation.errorCode,
      ),
      TryOnGenerationStatus.processing => const TryOnCheckResult(
        TryOnCheck.running,
      ),
    };
  } on AuthExpiredException {
    rethrow;
  } on ApiException catch (e) {
    if (e.errorCode == 'TRY_ON_GENERATION_NOT_FOUND') {
      return const TryOnCheckResult(TryOnCheck.notReceived);
    }
    if (e.statusCode >= 400 && e.statusCode < 500) {
      return const TryOnCheckResult(TryOnCheck.unavailable);
    }
    return const TryOnCheckResult(TryOnCheck.unreachable);
  } on TimeoutException {
    return const TryOnCheckResult(TryOnCheck.unreachable);
  } on http.ClientException {
    return const TryOnCheckResult(TryOnCheck.unreachable);
  } on SocketException {
    return const TryOnCheckResult(TryOnCheck.unreachable);
  } catch (_) {
    // A malformed reply: unknown, not a failure.
    return const TryOnCheckResult(TryOnCheck.unreachable);
  }
}

/// The render a new-outfit draft group already holds, if any — how a backend
/// without the status endpoint can still answer "did it land?".
Future<Outfit?> landedInDraft(int draftGroupId) async {
  final outfits = await OutfitService().getGroupOutfits(
    draftGroupId,
    forceRefresh: true,
  );
  return outfits.isEmpty ? null : outfits.last;
}
