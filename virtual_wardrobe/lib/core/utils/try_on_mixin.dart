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
  int tryOnJobId = 0;

  /// The `look_id` of the look currently being watched — only set by
  /// [performLookRegeneration] (regular [performTryOn]/[watchJob] callers
  /// don't need a specific look, just whichever `primaryLookOf` resolves).
  int? tryOnLookId;
  Timer? pollTimer;
  Completer<int?>? _tryOnCompleter;

  Future<int?> performTryOn(
    List<int> garmentIds,
    String type, {
    String style = 'Minimal',
  }) async {
    if (garmentIds.isEmpty) return null;
    debugLog('--- performTryOn ---');

    pollTimer?.cancel();
    _tryOnCompleter = Completer<int?>();

    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
    });

    try {
      final jobResponse = await OutfitService().createOutfit(
        garmentIds: garmentIds,
        type: type,
        style: style,
      );

      // Backend now returns the outfit's own id as `outfit_id` (the create
      // response is shaped like a single outfit with a nested `looks[]`);
      // `job_id` is kept as a fallback in case some path still returns it.
      final jobId = jobResponse['outfit_id'] ?? jobResponse['job_id'];
      if (!mounted) {
        _tryOnCompleter?.complete(jobId);
        return jobId;
      }

      setState(() => tryOnJobId = jobId);

      _startPolling(jobId);

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

  /// Watches an already-created try-on job (e.g. a daily-outfit option's
  /// `job_id` returned by the backend) without creating a new one.
  Future<int?> watchJob(int jobId) {
    pollTimer?.cancel();
    _tryOnCompleter = Completer<int?>();

    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
      tryOnJobId = jobId;
    });

    _startPolling(jobId);
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
      tryOnJobId = outfitId;
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

  /// Creates a brand new outfit from [garmentIds] (the core garments), then
  /// immediately generates its first look with [accessoryGarmentIds] and
  /// [backgroundId] via [performLookRegeneration] — used when accessories/
  /// background were picked ahead of time (e.g. Add Outfit's Customization
  /// Look flow), since [OutfitService.createOutfit] itself has no
  /// `background_id` field.
  Future<int?> performTryOnWithCustomization(
    List<int> garmentIds, {
    List<int>? accessoryGarmentIds,
    int? backgroundId,
  }) async {
    if (garmentIds.isEmpty) return null;
    debugLog('--- performTryOnWithCustomization ---');

    setState(() {
      isOutfitLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
    });

    int? newOutfitId;
    try {
      final response = await OutfitService().createOutfit(
        garmentIds: garmentIds,
        type: 'general',
      );
      newOutfitId = (response['outfit_id'] ?? response['job_id']) as int?;
      if (newOutfitId == null) {
        throw Exception('createOutfit: response missing outfit id');
      }
    } on AuthExpiredException {
      if (mounted) {
        await AuthExpiredHandler.handle(context);
      }
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

    return performLookRegeneration(
      newOutfitId,
      accessoryGarmentIds: accessoryGarmentIds,
      backgroundId: backgroundId,
    );
  }

  void _startPolling(int jobId, {int? lookId}) {
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
        final statusRes = await OutfitService().getOutfit(jobId);
        final look = lookId != null
            ? lookById(statusRes, lookId)
            : primaryLookOf(statusRes);
        final status = look?['status'] ?? statusRes['status'];
        debugLog('--- Try-On Job Id: $jobId ---');
        debugLog('--- Try-On Job raw response: $statusRes ---');
        debugLog('--- Try-On Job Status: $status ---');

        if (!mounted) {
          timer.cancel();
          _tryOnCompleter?.complete(jobId);
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
          _tryOnCompleter?.complete(jobId);
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
      tryOnJobId = 0;
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

  Future<void> deleteOutfitJob(int jobId) async {
    try {
      await OutfitService().deleteOutfit(jobId);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Delete outfit error: $e');
    }
  }
}
