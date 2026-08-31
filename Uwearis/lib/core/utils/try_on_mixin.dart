import 'package:flutter/material.dart';

import '../../data/outfit.dart';
import '../services/auth_handler.dart';
import '../services/outfit_service.dart';
import 'debug_log.dart';

/// `generate`/`regenerate` on the new OutfitGroup + Outfit API are
/// synchronous (the AI render finishes before the call returns), so unlike
/// the old job-polling version of this mixin there's no `Timer`/`Completer`
/// here anymore — a single `await` is enough.
mixin TryOnMixin<T extends StatefulWidget> on State<T> {
  bool isOutfitLoading = false;
  String? tryOnErrorMessage;
  String? tryOnResultUrl;
  int tryOnGroupId = 0;
  int tryOnOutfitId = 0;
  // The full outfit from the last successful performTryOn — richer than the
  // individual tryOn*/fields above (carries name/style/season/isFavorite
  // too), for callers that need to hand the whole thing off (e.g. Outfit
  // Details' "Create Another Version" result).
  Outfit? tryOnOutfit;

  /// Creates a new outfit from [garmentIds] and renders it in one call.
  /// Pass [groupId] to add this as another version alongside an existing
  /// outfit (Outfit Details' "Create Another Version") instead of starting
  /// a fresh group.
  Future<int?> performTryOn(
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

    try {
      final outfit = await OutfitService().generateOutfit(
        garmentIds: garmentIds,
        groupId: groupId,
        type: type,
        backgroundId: backgroundId,
      );
      if (!mounted) return outfit.id;
      setState(() {
        isOutfitLoading = false;
        tryOnGroupId = outfit.groupId;
        tryOnOutfitId = outfit.id;
        tryOnResultUrl = outfit.imageUrl;
        tryOnOutfit = outfit;
      });
      return outfit.id;
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return null;
    } catch (e) {
      if (mounted) {
        setState(() {
          isOutfitLoading = false;
          tryOnErrorMessage = 'Failed: $e';
        });
      }
      return null;
    }
  }

  void resetTryOnState() {
    setState(() {
      isOutfitLoading = false;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnGroupId = 0;
      tryOnOutfitId = 0;
      tryOnOutfit = null;
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
