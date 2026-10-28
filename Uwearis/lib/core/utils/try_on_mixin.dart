import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../services/auth_handler.dart';
import '../services/outfit_service.dart';
import 'api_error_text.dart';
import 'debug_log.dart';
import 'idempotency_key.dart';

/// The render finishes before `generate` returns — a single `await`, no
/// polling.
mixin TryOnMixin<T extends StatefulWidget> on State<T> {
  bool isOutfitLoading = false;
  String? tryOnErrorMessage;
  String? tryOnResultUrl;
  int tryOnGroupId = 0;
  int tryOnOutfitId = 0;

  // The group created for a new outfit. Retries reuse it, so a failed
  // generate doesn't leave another empty group behind each time; whatever
  // is still in it when the page goes away is discarded.
  int? _draftGroupId;

  // A request failed in transit (timeout, dropped connection): the backend
  // may have finished and saved that render anyway.
  bool _mayHaveRendered = false;

  // One key per outfit the user asked for, shared by its retries.
  String? _attemptKey;
  String? _attemptInputs;

  @override
  void dispose() {
    // A render still in flight discards itself when it lands, so it counts
    // toward the daily quota like any finished render.
    if (!isOutfitLoading) _discardDraft();
    super.dispose();
  }

  /// Pass [groupId] to add another version to an existing group instead of
  /// starting a new one. Returns the rendered outfit, or null on failure or
  /// when the page was left mid-render (that result is discarded).
  Future<Outfit?> performTryOn(
    List<int> garmentIds, {
    int? groupId,
    String type = 'general',
    int? backgroundId,
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
    if (inputs != _attemptInputs) {
      // A different outfit: a late render in the old draft no longer fits.
      if (groupId == null && _mayHaveRendered) _discardDraft();
      _attemptInputs = inputs;
      _attemptKey = newIdempotencyKey();
      _mayHaveRendered = false;
    }

    try {
      final target =
          groupId ??
          (_draftGroupId ??= await OutfitService().createGroup(type: type));
      final outfit =
          await _landedRender(groupId == null ? target : null) ??
          await OutfitService().generateOutfit(
            garmentIds: garmentIds,
            groupId: target,
            type: type,
            backgroundId: backgroundId,
            idempotencyKey: _attemptKey,
          );
      _draftGroupId = null;
      _attemptInputs = null;
      _attemptKey = null;
      _mayHaveRendered = false;
      if (!mounted) {
        // Left mid-render: discarded, like an unsaved outfit on the details
        // page. It still counted toward today's quota.
        _discardRender(outfit, versionOf: groupId);
        return null;
      }
      setState(() {
        isOutfitLoading = false;
        tryOnGroupId = outfit.groupId;
        tryOnOutfitId = outfit.id;
        tryOnResultUrl = outfit.imageUrl;
      });
      return outfit;
    } on AuthExpiredException {
      isOutfitLoading = false;
      if (mounted) await AuthExpiredHandler.handle(context);
      return null;
    } catch (e) {
      debugLog('performTryOn failed: $e');
      final inTransit =
          e is TimeoutException ||
          e is http.ClientException ||
          e is SocketException;
      if (inTransit) _mayHaveRendered = true;
      if (!mounted) {
        isOutfitLoading = false;
        _discardDraft();
        return null;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        isOutfitLoading = false;
        tryOnErrorMessage = e is TimeoutException && groupId == null
            ? l10n.tryOnStillRendering(l10n.createOutfit)
            : apiErrorMessage(l10n, e, fallback: l10n.failedToGenerateOutfit);
      });
      return null;
    }
  }

  /// The render a timed-out request saved after all, so a retry shows it
  /// instead of paying for another. Null when there's nothing to look for.
  Future<Outfit?> _landedRender(int? draftGroupId) async {
    if (draftGroupId == null || !_mayHaveRendered) return null;
    final outfits = await OutfitService().getGroupOutfits(
      draftGroupId,
      forceRefresh: true,
    );
    if (outfits.isEmpty) return null;
    debugLog('performTryOn: reusing landed render in group $draftGroupId');
    return outfits.last;
  }

  void _discardDraft() {
    final id = _draftGroupId;
    _draftGroupId = null;
    _mayHaveRendered = false;
    if (id == null) return;
    OutfitService()
        .deleteGroup(id)
        .catchError((Object e) => debugLog('discard draft $id failed: $e'));
  }

  void _discardRender(Outfit outfit, {int? versionOf}) {
    final delete = versionOf != null
        ? OutfitService().deleteOutfit(versionOf, outfit.id)
        : OutfitService().deleteGroup(outfit.groupId);
    delete.catchError(
      (Object e) => debugLog('discard render ${outfit.id} failed: $e'),
    );
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
