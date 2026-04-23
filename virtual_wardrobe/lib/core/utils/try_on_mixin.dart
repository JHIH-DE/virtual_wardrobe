import 'dart:async';
import 'package:flutter/material.dart';
import '../services/outfit_service.dart';
import '../services/error_handler.dart';

mixin TryOnMixin<T extends StatefulWidget> on State<T> {
  bool isOutfitLoading = false;
  String? tryOnErrorMessage;
  String? tryOnResultUrl;
  String? tryOnAiAdvice;
  int tryOnJobId = 0;
  Timer? pollTimer;
  Completer<int?>? _tryOnCompleter;

  Future<int?> performTryOn(List<int> garmentIds, String type) async {
    if (garmentIds.isEmpty) return null;
    debugPrint('--- performTryOn ---');

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
      );

      final jobId = jobResponse['job_id'];
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

  void _startPolling(int jobId) {
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
        final status = statusRes['status'];
        debugPrint('--- Try-On Job Id: $jobId ---');
        debugPrint('--- Try-On Job Status: $status ---');
        
        if (!mounted) {
          timer.cancel();
          _tryOnCompleter?.complete(jobId);
          return;
        }

        if (status == 'completed') {
          timer.cancel();
          setState(() {
            isOutfitLoading = false;
            tryOnResultUrl = statusRes['result_image_url'];
            tryOnAiAdvice = statusRes['ai_notes'] ?? 'Looking good!';
          });
          debugPrint('--- Try-On Job tryOnResultUrl: $tryOnResultUrl ---');
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
        debugPrint('Polling error: $e');
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
      debugPrint('Delete outfit error: $e');
    }
  }
}
