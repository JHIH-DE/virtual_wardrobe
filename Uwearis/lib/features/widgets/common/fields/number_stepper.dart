import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';

enum NumberStepperVariant { card, row, pill }

class NumberStepper extends StatefulWidget {
  final String? label;
  final String valueLabel;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final NumberStepperVariant variant;
  final bool startRevealed;
  final VoidCallback? onRevealConsumed;

  const NumberStepper({
    super.key,
    this.label,
    required this.valueLabel,
    this.onDecrement,
    this.onIncrement,
    this.variant = NumberStepperVariant.card,
    this.startRevealed = false,
    this.onRevealConsumed,
  }) : assert(
         label != null || variant == NumberStepperVariant.pill,
         'label is required for the card/row variants',
       );

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  static const _revealDuration = Duration(seconds: 3);
  static const _restOpacity = 0.6;

  bool _isPill = false;
  bool _revealed = false;
  Timer? _revealTimer;

  @override
  void didUpdateWidget(covariant NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    _isPill = widget.variant == NumberStepperVariant.pill;
  }

  @override
  void initState() {
    super.initState();
    _isPill = widget.variant == NumberStepperVariant.pill;
    if (_isPill && widget.startRevealed) {
      _revealed = true;
      _startRevealTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRevealConsumed?.call();
      });
    }
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  void _startRevealTimer() {
    _revealTimer?.cancel();
    _revealTimer = Timer(_revealDuration, () {
      if (mounted) setState(() => _revealed = false);
    });
  }

  void _handleStepTap(VoidCallback? onPressed) {
    if (onPressed == null) return;
    onPressed();
    if (!_isPill) return;
    setState(() => _revealed = true);
    _startRevealTimer();
  }

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: _isPill ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (!_isPill)
          Expanded(
            child: Text(
              widget.label!,
              style: AppTextStyle.semibold16,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        _buildStepButton(
          icon: Icons.remove_circle_outline,
          onPressed: widget.onDecrement,
        ),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 20),
          child: Text(
            widget.valueLabel,
            textAlign: TextAlign.center,
            style: _valueTextStyle,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        const SizedBox(width: 6),
        _buildStepButton(
          icon: Icons.add_circle_outline,
          onPressed: widget.onIncrement,
          trailing: !_isPill,
        ),
      ],
    );

    final content = switch (widget.variant) {
      NumberStepperVariant.row => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
      NumberStepperVariant.pill => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(color: AppColors.overlaySubtle, blurRadius: 4),
          ],
        ),
        child: row,
      ),
      NumberStepperVariant.card => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: row,
      ),
    };

    if (!_isPill) return content;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _revealed ? 1 : _restOpacity,
      child: content,
    );
  }

  double get _glyphSize => 28;
  TextStyle get _valueTextStyle =>
      _isPill ? AppTextStyle.bold16 : AppTextStyle.regular16;
  double get _buttonBoxSize => _isPill ? 36 : AppDimens.minTouchTarget;
  double get _hitPad => (_buttonBoxSize - _glyphSize) / 2;

  Widget _buildStepButton({
    required IconData icon,
    required VoidCallback? onPressed,
    bool trailing = false,
  }) {
    final baseColor = _isPill ? AppColors.accent : AppColors.icon;
    final boxSize = _buttonBoxSize;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _handleStepTap(onPressed),
      child: SizedBox(
        width: trailing ? _glyphSize + _hitPad : boxSize,
        height: boxSize,
        child: Align(
          alignment: trailing ? Alignment.centerRight : Alignment.center,
          child: Icon(
            icon,
            size: _glyphSize,
            color: onPressed == null
                ? baseColor.withValues(alpha: 0.3)
                : baseColor,
          ),
        ),
      ),
    );
  }
}
