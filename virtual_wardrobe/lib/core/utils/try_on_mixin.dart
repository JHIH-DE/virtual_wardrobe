import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/outfit.dart';
import '../services/auth_handler.dart';
import '../services/outfit_service.dart';
import 'debug_log.dart';

mixin TryOnMixin<T extends StatefulWidget> on State<T> {
  bool isOutfitLoading = false;
  String? tryOnErrorMessage;
  String? tryOnResultUrl;
  String? tryOnAiAdvice;
  int tryOnOutfitId = 0;

  /// The `look_id` of the look currently being watched — set whenever a
  /// look is created ([performTryOn], [performTryOnWithCustomization],
  /// [performLookRegeneration]). Left `null` by [watchJob], which watches
  /// an already-created job without a specific look, falling back to
  /// whichever `primaryLookOf` resolves.
  int? tryOnLookId;
  Timer? pollTimer;
  Completer<int?>? _tryOnCompleter;

  /// Creates a brand new outfit and renders its first look in one call
  /// (see `OutfitService.createOutfitAndRender`), then watches that look.
  Future<int?> performTryOn(
    List<int> garmentIds,
    String type, {
    String style = 'Minimal',
  }) {
    if (garmentIds.isEmpty) return Future.value(null);
    debugLog('--- performTryOn ---');
    return _createOutfitAndWatch(garmentIds: garmentIds, type: type, style: style);
  }

  /// Watches an already-created try-on job (e.g. a daily-outfit option's
  /// `outfit_id` returned by the backend) without creating a new one.
  Future<int?> watchJob(int outfitId) {
    pollTimer?.cancel();
    _tryOnCompleter = Completer<int?>();

    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
      tryOnOutfitId = outfitId;
    });

    _startPolling(outfitId);
    return _tryOnCompleter!.future;
  }

  /// Regenerates a new look on an already-existing outfit (see
  /// `OutfitService.createLook`) and watches that specific look — unlike
  /// [performTryOn], which always creates a brand new outfit.
  /// [accessoryGarmentIds]: leave null to reuse the previous look's
  /// accessories, pass `[]` for none this time, or a list to swap to those.
  Future<int?> performLookRegeneration(
    int outfitId, {
    List<int>? accessoryGarmentIds,
    int? backgroundId,
  }) async {
    debugLog('--- performLookRegeneration: $outfitId ---');

    pollTimer?.cancel();
    _tryOnCompleter = Completer<int?>();

    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
      tryOnOutfitId = outfitId;
      tryOnLookId = null;
    });

    try {
      final response = await OutfitService().createLook(
        outfitId,
        accessoryGarmentIds: accessoryGarmentIds,
        backgroundId: backgroundId,
      );
      final lookId = response['look_id'] as int?;
      if (lookId == null) {
        throw Exception('createLook: response missing look_id');
      }
      tryOnLookId = lookId;

      if (!mounted) {
        _tryOnCompleter?.complete(outfitId);
        return outfitId;
      }

      _startPolling(outfitId, lookId: lookId);
      return _tryOnCompleter!.future;
    } on AuthExpiredException {
      if (mounted) {
        await AuthExpiredHandler.handle(context);
      }
      _tryOnCompleter?.complete(null);
      return null;
    } catch (e) {
      if (mounted) {
        setState(() {
          isOutfitLoading = false;
          tryOnErrorMessage = 'Failed: $e';
        });
      }
      _tryOnCompleter?.complete(null);
      return null;
    }
  }

  /// Creates a brand new outfit from [garmentIds] (the core garments) and
  /// renders its first look with [accessoryGarmentIds]/[backgroundId] in
  /// one call (see `OutfitService.createOutfitAndRender`) — used when
  /// accessories/background were picked ahead of time (e.g. Add Outfit's
  /// Customization Look flow), unlike [performTryOn] which has no
  /// accessory/background inputs.
  Future<int?> performTryOnWithCustomization(
    List<int> garmentIds, {
    List<int>? accessoryGarmentIds,
    int? backgroundId,
  }) {
    if (garmentIds.isEmpty) return Future.value(null);
    debugLog('--- performTryOnWithCustomization ---');
    return _createOutfitAndWatch(
      garmentIds: garmentIds,
      type: 'general',
      accessoryGarmentIds: accessoryGarmentIds,
      backgroundId: backgroundId,
    );
  }

  /// Shared by [performTryOn] and [performTryOnWithCustomization]: creates
  /// a new outfit and renders its first look via
  /// `OutfitService.createOutfitAndRender`, then watches that look. If the
  /// outfit was created but rendering failed
  /// ([OutfitRenderException]), [tryOnOutfitId] is still set to the created
  /// outfit so a caller can retry via [performLookRegeneration] instead of
  /// creating a duplicate outfit.
  Future<int?> _createOutfitAndWatch({
    required List<int> garmentIds,
    required String type,
    String style = 'Minimal',
    List<int>? accessoryGarmentIds,
    int? backgroundId,
  }) async {
    pollTimer?.cancel();
    _tryOnCompleter = Completer<int?>();

    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
      tryOnLookId = null;
    });

    try {
      final response = await OutfitService().createOutfitAndRender(
        garmentIds: garmentIds,
        type: type,
        style: style,
        accessoryGarmentIds: accessoryGarmentIds,
        backgroundId: backgroundId,
      );
      final outfitId = response['outfit_id'] as int;
      final lookId = response['look_id'] as int?;

      if (!mounted) {
        _tryOnCompleter?.complete(outfitId);
        return outfitId;
      }

      setState(() {
        tryOnOutfitId = outfitId;
        tryOnLookId = lookId;
      });

      _startPolling(outfitId, lookId: lookId);
      return _tryOnCompleter!.future;
    } on OutfitRenderException catch (e) {
      if (mounted) {
        setState(() {
          isOutfitLoading = false;
          tryOnOutfitId = e.outfitId;
          tryOnErrorMessage = 'Failed: ${e.cause}';
        });
      }
      _tryOnCompleter?.complete(null);
      return null;
    } on AuthExpiredException {
      if (mounted) {
        await AuthExpiredHandler.handle(context);
      }
      _tryOnCompleter?.complete(null);
      return null;
    } catch (e) {
      if (mounted) {
        setState(() {
          isOutfitLoading = false;
          tryOnErrorMessage = 'Failed: $e';
        });
      }
      _tryOnCompleter?.complete(null);
      return null;
    }
  }

  void _startPolling(int outfitId, {int? lookId}) {
    int attempts = 0;
    pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 180) {
        timer.cancel();
        if (mounted) {
          setState(() {
            isOutfitLoading = false;
            tryOnErrorMessage = 'Timeout.';
          });
        }
        _tryOnCompleter?.complete(null);
        return;
      }
      try {
        final statusRes = await OutfitService().getOutfit(outfitId);
        final look = lookId != null
            ? lookById(statusRes, lookId)
            : primaryLookOf(statusRes);
        final status = look?['status'] ?? statusRes['status'];
        debugLog('--- Try-On Outfit Id: $outfitId ---');
        debugLog('--- Try-On Job raw response: $statusRes ---');
        debugLog('--- Try-On Job Status: $status ---');

        if (!mounted) {
          timer.cancel();
          _tryOnCompleter?.complete(outfitId);
          return;
        }

        if (status == 'completed') {
          timer.cancel();
          setState(() {
            isOutfitLoading = false;
            tryOnResultUrl =
                look?['result_image_url'] ?? statusRes['result_image_url'];
            tryOnAiAdvice =
                look?['ai_notes'] ?? statusRes['ai_notes'] ?? 'Looking good!';
          });
          debugLog('--- Try-On Job tryOnResultUrl: $tryOnResultUrl ---');
          _tryOnCompleter?.complete(outfitId);
        } else if (status == 'failed') {
          timer.cancel();
          setState(() {
            isOutfitLoading = false;
            tryOnErrorMessage = 'Failed on server.';
          });
          _tryOnCompleter?.complete(null);
        }
      } catch (e) {
        debugLog('Polling error: $e');
      }
    });
  }

  void resetTryOnState() {
    pollTimer?.cancel();
    if (_tryOnCompleter != null && !_tryOnCompleter!.isCompleted) {
      _tryOnCompleter?.complete(null);
    }
    setState(() {
      isOutfitLoading = false;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
      tryOnOutfitId = 0;
      tryOnLookId = null;
    });
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    if (_tryOnCompleter != null && !_tryOnCompleter!.isCompleted) {
      _tryOnCompleter?.complete(null);
    }
    super.dispose();
  }

  Future<void> deleteOutfitJob(int outfitId) async {
    try {
      await OutfitService().deleteOutfit(outfitId);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Delete outfit error: $e');
    }
  }
}
