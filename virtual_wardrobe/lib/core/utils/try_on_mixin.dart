import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_handler.dart';
import '../services/look_service.dart';
import 'debug_log.dart';

mixin TryOnMixin<T extends StatefulWidget> on State<T> {
  bool isLookLoading = false;
  String? tryOnErrorMessage;
  String? tryOnResultUrl;
  String? tryOnAiAdvice;
  int tryOnJobId = 0;
  Timer? pollTimer;
  Completer<int?>? _tryOnCompleter;

  Future<int?> performTryOn(List<int> garmentIds, String type) async {
    if (garmentIds.isEmpty) return null;
    debugLog('--- performTryOn ---');

    pollTimer?.cancel();
    _tryOnCompleter = Completer<int?>();

    setState(() {
      isLookLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
    });

    try {
      final jobResponse = await LookService().createLook(
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
          isLookLoading = false;
          tryOnErrorMessage = 'Failed: $e';
        });
      }
      _tryOnCompleter?.complete(null);
      return null;
    }
  }

  /// Watches an already-created try-on job (e.g. a daily-look option's
  /// `job_id` returned by the backend) without creating a new one.
  Future<int?> watchJob(int jobId) {
    pollTimer?.cancel();
    _tryOnCompleter = Completer<int?>();

    setState(() {
      isLookLoading = true;
      tryOnErrorMessage = null;
      tryOnResultUrl = null;
      tryOnAiAdvice = null;
      tryOnJobId = jobId;
    });

    _startPolling(jobId);
    return _tryOnCompleter!.future;
  }

  void _startPolling(int jobId) {
    int attempts = 0;
    pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 180) {
        timer.cancel();
        if (mounted) {
          setState(() {
            isLookLoading = false;
            tryOnErrorMessage = 'Timeout.';
          });
        }
        _tryOnCompleter?.complete(null);
        return;
      }
      try {
        final statusRes = await LookService().getLook(jobId);
        final status = statusRes['status'];
        debugLog('--- Try-On Job Id: $jobId ---');
        debugLog('--- Try-On Job Status: $status ---');

        if (!mounted) {
          timer.cancel();
          _tryOnCompleter?.complete(jobId);
          return;
        }

        if (status == 'completed') {
          timer.cancel();
          setState(() {
            isLookLoading = false;
            tryOnResultUrl = statusRes['result_image_url'];
            tryOnAiAdvice = statusRes['ai_notes'] ?? 'Looking good!';
          });
          debugLog('--- Try-On Job tryOnResultUrl: $tryOnResultUrl ---');
          _tryOnCompleter?.complete(jobId);
        } else if (status == 'failed') {
          timer.cancel();
          setState(() {
            isLookLoading = false;
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
      isLookLoading = false;
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
      await LookService().deleteLook(jobId);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Delete outfit error: $e');
    }
  }
}
