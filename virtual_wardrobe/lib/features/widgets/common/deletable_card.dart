import 'package:flutter/material.dart';

import '../../../app/route_observer.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'card_corner_badge.dart';

/// Coordinates a group of [DeletableCard]s (e.g. all cards in one grid) so
/// opening one card's delete confirmation closes any other that's open.
/// Create one instance per list/grid and pass it to every card in it.
class DeletableCardGroup {
  VoidCallback? _openClose;

  void _requestOpen(VoidCallback close) {
    if (_openClose != null && _openClose != close) _openClose!();
    _openClose = close;
  }

  void _notifyClosed(VoidCallback close) {
    if (_openClose == close) _openClose = null;
  }
}

/// Wraps [child] with a corner delete badge; tapping it shows a full-card
/// black overlay with DELETE / cancel actions before invoking [onDelete].
class DeletableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final BorderRadius borderRadius;
  final DeletableCardGroup? group;

  const DeletableCard({
    super.key,
    required this.child,
    required this.onDelete,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.group,
  });

  @override
  State<DeletableCard> createState() => _DeletableCardState();
}

class _DeletableCardState extends State<DeletableCard> with RouteAware {
  bool _confirming = false;

  void _open() {
    widget.group?._requestOpen(_close);
    setState(() => _confirming = true);
  }

  void _close() {
    widget.group?._notifyClosed(_close);
    if (mounted && _confirming) setState(() => _confirming = false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    widget.group?._notifyClosed(_close);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Reset the confirmation state when this route becomes visible again
  // (e.g. navigated away mid-confirmation via a route pushed on top, then
  // popped back), so a stale DELETE overlay doesn't reappear silently.
  @override
  void didPopNext() => _close();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 8,
          right: 8,
          child: CardCornerBadge(
            icon: Icons.close,
            backgroundColor: AppColors.nearBlack,
            iconColor: Colors.white,
            onTap: _open,
          ),
        ),
        if (_confirming)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            _close();
                            widget.onDelete();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'DELETE',
                              style: AppTextStyle.bold16.copyWith(
                                color: Colors.black,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _close,
                          child: Text(
                            'cancel',
                            style: AppTextStyle.regular16.copyWith(
                              color: Colors.white,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
