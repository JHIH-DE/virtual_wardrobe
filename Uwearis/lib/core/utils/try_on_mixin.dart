import 'package:flutter/material.dart';

import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../services/auth_handler.dart';
import '../services/outfit_service.dart';
import '../services/pending_try_on_store.dart';
import 'api_error_text.dart';
import 'debug_log.dart';
import 'idempotency_key.dart';
import 'try_on_request.dart';
import 'try_on_status.dart';

/// The render finishes before `generate` returns — a single `await`, no
/// polling — unless that reply is lost. Every attempt carries an
/// Idempotency-Key, so a backend that honours it runs (and charges) one
/// render per key: a lost reply is recovered by asking for that key's status,
/// never by rendering again, and a finished render is never deleted for the
/// user having stopped waiting. A backend without the status endpoint can
/// only be asked "did the draft get a render?", so there a second request
/// needs the user's go-ahead.
mixin TryOnMixin<T extends StatefulWidget> on State<T> {
  bool isOutfitLoading = false;
  String? tryOnErrorMessage;
  String? tryOnResultUrl;
  int tryOnGroupId = 0;
  int tryOnOutfitId = 0;

  // The group created for a new outfit. Retries reuse it, so a failed
  // generate doesn't leave another empty group behind each time.
  int? _draftGroupId;
  // The sign-in session the draft was created in (see PendingTryOnStore).
  int? _draftSession;

  // The current key's render may still finish (no reply, or the backend says
  // it's running). Its draft group may then hold the result, so it's kept.
  bool _outcomeUnknown = false;

  // The backend couldn't report status for that key.
  bool _statusUnavailable = false;

  // One key per outfit the user asked for, shared by its retries until the
  // backend reports that attempt definitively failed.
  String? _attemptKey;
  String? _attemptInputs;

  @override
  void dispose() {
    if (!isOutfitLoading && !_outcomeUnknown) _discardDraft();
    super.dispose();
  }

  /// Pass [groupId] to add another version to an existing group instead of
  /// starting a new one. Returns the rendered outfit, or null on failure, on
  /// a declined retry, or when the page was left before it landed — that
  /// render is kept (it shows up in Outfits) and handed to
  /// [onLandedAfterLeave].
  ///
  /// [confirmRetryWhileUnknown] is asked before sending another request for
  /// the same outfit while the previous one's outcome can't be checked; null
  /// or false means nothing is sent.
  Future<Outfit?> performTryOn(
    List<int> garmentIds, {
    int? groupId,
    String type = 'general',
    int? backgroundId,
    void Function(Outfit outfit)? onLandedAfterLeave,
    Future<bool> Function()? confirmRetryWhileUnknown,
  }) async {
    if (garmentIds.isEmpty) return null;
    debugLog('--- performTryOn: groupId=$groupId ---');

    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
    });

    final inputs =
        '${groupId ?? type}|${([...garmentIds]..sort()).join(',')}'
        '|$backgroundId';
    final retryingUnknown = inputs == _attemptInputs && _outcomeUnknown;
    // A reply that lands after a sign-out belongs to the previous account:
    // none of its local side effects may run.
    final session = PendingTryOnStore.session;
    bool sameSession() => PendingTryOnStore.session == session;
    if (inputs != _attemptInputs) _startNewIntent(inputs, groupId: groupId);

    String key;
    try {
      // A backend that reports status replays the same key by itself; one
      // that can't is asked "did the draft get a render?" first.
      if (retryingUnknown && _statusUnavailable) {
        final landed = await _landedInCurrentDraft(groupId);
        if (landed != null) {
          await PendingTryOnStore.remove(_attemptKey!, forSession: session);
          return _succeed(landed, sameSession() ? onLandedAfterLeave : null);
        }
        if (mounted) setState(() => isOutfitLoading = false);
        final go =
            await (confirmRetryWhileUnknown?.call() ?? Future.value(false));
        if (!go || !mounted) return null;
        setState(() => isOutfitLoading = true);
        // A separate intent: the earlier render may still land in its own
        // draft, which stays where it is.
        _startNewIntent(inputs, groupId: groupId);
      }

      key = _attemptKey!;
      if (groupId == null && _draftGroupId == null) {
        _draftGroupId = await OutfitService().createGroup(type: type);
        _draftSession = session;
      }
      final target = groupId ?? _draftGroupId!;
      final attemptKey = key;
      final outfit = await sendKeyedTryOn(
        key: attemptKey,
        session: session,
        draftGroupId: groupId == null ? target : null,
        send: () => OutfitService().generateOutfit(
          garmentIds: garmentIds,
          groupId: target,
          type: type,
          backgroundId: backgroundId,
          idempotencyKey: attemptKey,
        ),
      );
      return _succeed(outfit, sameSession() ? onLandedAfterLeave : null);
    } on AuthExpiredException {
      isOutfitLoading = false;
      if (mounted) await AuthExpiredHandler.handle(context);
      return null;
    } catch (e) {
      debugLog('performTryOn failed: $e');
      final stillRunning = e is TryOnStillRunning;
      _outcomeUnknown = stillRunning;
      if (e is TryOnStillRunning) {
        _statusUnavailable = e.statusUnavailable;
      } else {
        // A definitive failure is final for its key (the backend replays
        // it), so a retry needs a new one. Its quota was released.
        _attemptKey = newIdempotencyKey();
        _statusUnavailable = false;
      }
      if (!mounted) {
        isOutfitLoading = false;
        if (!stillRunning) _discardDraft();
        return null;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        isOutfitLoading = false;
        tryOnErrorMessage = !stillRunning
            ? apiErrorMessage(l10n, e, fallback: l10n.failedToGenerateOutfit)
            : _statusUnavailable
            ? l10n.tryOnOutcomeUnknown
            : l10n.tryOnStillRendering(l10n.createOutfit);
      });
      return null;
    }
  }

  /// The render the current draft already holds; null when there's no
  /// draft, it's empty, or it couldn't be checked (still unknown either way).
  Future<Outfit?> _landedInCurrentDraft(int? groupId) async {
    final draft = groupId == null ? _draftGroupId : null;
    if (draft == null) return null;
    try {
      return await landedInDraft(draft);
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
      debugLog('performTryOn: draft check failed: $e');
      return null;
    }
  }

  void _startNewIntent(String inputs, {required int? groupId}) {
    // A draft that may still receive the old render is left alone rather
    // than reused or deleted.
    if (groupId == null && _outcomeUnknown) _draftGroupId = null;
    _attemptInputs = inputs;
    _attemptKey = newIdempotencyKey();
    _outcomeUnknown = false;
    _statusUnavailable = false;
  }

  Outfit? _succeed(Outfit outfit, void Function(Outfit)? onLandedAfterLeave) {
    _draftGroupId = null;
    _attemptInputs = null;
    _attemptKey = null;
    _outcomeUnknown = false;
    _statusUnavailable = false;
    if (!mounted) {
      onLandedAfterLeave?.call(outfit);
      return null;
    }
    setState(() {
      isOutfitLoading = false;
      tryOnGroupId = outfit.groupId;
      tryOnOutfitId = outfit.id;
      tryOnResultUrl = outfit.imageUrl;
    });
    return outfit;
  }

  void _discardDraft() {
    final id = _draftGroupId;
    _draftGroupId = null;
    if (id == null || _draftSession != PendingTryOnStore.session) return;
    OutfitService()
        .deleteGroup(id)
        .catchError((Object e) => debugLog('discard draft $id failed: $e'));
  }

  void resetTryOnState() {
    setState(() {
      isOutfitLoading = false;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnGroupId = 0;
      tryOnOutfitId = 0;
    });
  }

  Future<void> deleteOutfitJob(int groupId, int outfitId) async {
    try {
      await OutfitService().deleteOutfit(groupId, outfitId);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Delete outfit error: $e');
    }
  }
}
