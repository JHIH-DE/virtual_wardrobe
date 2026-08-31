import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../images/petal_loader.dart';

class LoadingOverlay extends StatefulWidget {
  final String label;

  const LoadingOverlay({super.key, required this.label});

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> {
  static const _dotInterval = Duration(milliseconds: 400);
  // Wide enough for 3 dots at AppTextStyle.bold16 — reserved so the dots
  // growing/shrinking never shifts the label text next to them.
  static const _dotsWidth = 18.0;

  late final Timer _timer;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    LoadingOverlayActivity.activeCount.value++;
    _timer = Timer.periodic(
      _dotInterval,
      (_) => setState(() => _dotCount = (_dotCount + 1) % 4),
    );
  }

  @override
  void dispose() {
    LoadingOverlayActivity.activeCount.value--;
    _timer.cancel();
    super.dispose();
  }

  /// Labels come from l10n already ending in "…" (or "..."), so this
  /// strips that off — the trailing dots are re-added below, animated.
  String get _baseLabel {
    final text = widget.label.trimRight();
    if (text.endsWith('…')) return text.substring(0, text.length - 1);
    if (text.endsWith('...')) return text.substring(0, text.length - 3);
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = AppTextStyle.bold16.copyWith(
      color: AppColors.textOnPrimary,
      decoration: TextDecoration.none,
    );
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Container(
        color: AppColors.overlayScrim,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // This is the active overlay itself, so it must never pause —
            // see LoadingOverlayActivity/PetalLoader.pausable.
            const PetalLoader(size: 90, pausable: false),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_baseLabel, style: textStyle),
                const SizedBox(width: 1),
                SizedBox(
                  width: _dotsWidth,
                  child: Text('.' * _dotCount, style: textStyle),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
