import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../buttons/action_disc_button.dart';

/// One round button revealed behind a [SwipeActionCard].
class SwipeAction {
  final IconData icon;

  /// Read by screen readers; also the card's custom semantics action.
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback onPressed;

  const SwipeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.backgroundColor = AppColors.primary,
    this.iconColor = AppColors.textOnPrimary,
  });
}

/// A card that slides left to reveal round [actions] at its right end, and
/// right to reveal [leadingActions] at its left end. Tapping an action runs
/// it and closes the card; tapping the open card closes it instead of
/// reaching [child]. Screen readers get every action as a custom semantics
/// action, since a swipe can't be discovered there.
class SwipeActionCard extends StatefulWidget {
  final Widget child;

  /// Revealed by swiping left.
  final List<SwipeAction> actions;

  /// Revealed by swiping right.
  final List<SwipeAction> leadingActions;

  /// False closes the card and ignores swipes.
  final bool enabled;

  const SwipeActionCard({
    super.key,
    required this.child,
    this.actions = const [],
    this.leadingActions = const [],
    this.enabled = true,
  });

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  static const double _discSize = ActionDisc.size;
  static const double _hitSize = AppDimens.minTouchTarget;
  // Visible gap between discs = this + the hit padding around each disc.
  static const double _gap = 4;
  // Extra space between the card's edge and the disc nearest to it.
  static const double _cardGap = 6;
  static const double _flingVelocity = 300;

  /// The card's horizontal offset in logical px: negative shows [actions],
  /// positive shows [leadingActions].
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  static double _widthOf(List<SwipeAction> actions) =>
      actions.isEmpty ? 0 : actions.length * (_hitSize + _gap) + _cardGap;
  double get _trailingWidth => _widthOf(widget.actions);
  double get _leadingWidth => _widthOf(widget.leadingActions);
  bool get _canSwipe =>
      widget.enabled &&
      (widget.actions.isNotEmpty || widget.leadingActions.isNotEmpty);

  @override
  void didUpdateWidget(SwipeActionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final offset = _controller.value;
    if (offset != 0 &&
        (!_canSwipe || offset < -_trailingWidth || offset > _leadingWidth)) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _settle(double target) =>
      _controller.animateTo(target, curve: Curves.easeOut);
  void _close() => _settle(0);

  // A drag that starts with one side open can only close it, never carry
  // on to reveal the other side.
  double _dragMin = 0;
  double _dragMax = 0;

  void _onDragStart(DragStartDetails details) {
    _controller.stop();
    final offset = _controller.value;
    _dragMin = offset > 0 ? 0 : -_trailingWidth;
    _dragMax = offset < 0 ? 0 : _leadingWidth;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value = (_controller.value + (details.primaryDelta ?? 0)).clamp(
      _dragMin,
      _dragMax,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final offset = _controller.value;
    if (offset < 0) {
      final open =
          velocity < -_flingVelocity ||
          (velocity <= _flingVelocity && -offset >= _trailingWidth / 2);
      _settle(open ? -_trailingWidth : 0);
    } else if (offset > 0) {
      final open =
          velocity > _flingVelocity ||
          (velocity >= -_flingVelocity && offset >= _leadingWidth / 2);
      _settle(open ? _leadingWidth : 0);
    }
  }

  void _run(SwipeAction action) {
    _controller.stop();
    _controller.value = 0;
    action.onPressed();
  }

  Widget _discs(
    List<SwipeAction> actions,
    double progress, {
    required bool left,
  }) {
    return Positioned.fill(
      child: Align(
        alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!left) const SizedBox(width: _cardGap),
            for (final action in actions)
              Padding(
                padding: left
                    ? const EdgeInsets.only(right: _gap)
                    : const EdgeInsets.only(left: _gap),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Opacity(
                    opacity: progress,
                    child: _ActionDisc(
                      action: action,
                      size: _discSize,
                      hitSize: _hitSize,
                      onPressed: () => _run(action),
                    ),
                  ),
                ),
              ),
            if (left) const SizedBox(width: _cardGap),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final offset = _controller.value;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            if (offset < 0)
              _discs(
                widget.actions,
                (-offset / _trailingWidth).clamp(0.0, 1.0),
                left: false,
              ),
            if (offset > 0)
              _discs(
                widget.leadingActions,
                (offset / _leadingWidth).clamp(0.0, 1.0),
                left: true,
              ),
            Transform.translate(offset: Offset(offset, 0), child: child),
            // Covers the card's resting bounds, not its slid-out ones: a
            // hit outside the Stack's own box would never reach it.
            if (offset != 0)
              Positioned(
                left: offset > 0 ? _leadingWidth : 0,
                right: offset < 0 ? _trailingWidth : 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                ),
              ),
          ],
        );
      },
    );

    final canSwipe = _canSwipe;
    return Semantics(
      customSemanticsActions: canSwipe
          ? {
              for (final action in [
                ...widget.leadingActions,
                ...widget.actions,
              ])
                CustomSemanticsAction(label: action.label): action.onPressed,
            }
          : null,
      child: GestureDetector(
        onHorizontalDragStart: canSwipe ? _onDragStart : null,
        onHorizontalDragUpdate: canSwipe ? _onDragUpdate : null,
        onHorizontalDragEnd: canSwipe ? _onDragEnd : null,
        child: card,
      ),
    );
  }
}

class _ActionDisc extends StatelessWidget {
  final SwipeAction action;
  final double size;
  final double hitSize;
  final VoidCallback onPressed;

  const _ActionDisc({
    required this.action,
    required this.size,
    required this.hitSize,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: GestureDetector(
        // Near-misses around the disc; direct hits go to the InkWell.
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: hitSize,
          child: Center(
            child: Material(
              color: action.backgroundColor,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: size,
                  child: Icon(
                    action.icon,
                    size: ActionDisc.iconSize,
                    color: action.iconColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
