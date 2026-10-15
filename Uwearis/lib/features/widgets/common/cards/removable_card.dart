import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/route_observer.dart';
import '../../../../l10n/generated/app_localizations.dart';
import 'card_corner_badge.dart';

/// One per list/grid: opening one card's delete confirmation closes any
/// other that's open.
class RemovableCardGroup {
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
/// REMOVE / cancel overlay before invoking [onDelete].
class RemovableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;
  final RemovableCardGroup? group;

  static const BorderRadius _borderRadius = BorderRadius.all(
    Radius.circular(AppDimens.cardRadius),
  );

  const RemovableCard({
    super.key,
    required this.child,
    required this.onDelete,
    this.group,
  });

  @override
  State<RemovableCard> createState() => _RemovableCardState();
}

class _RemovableCardState extends State<RemovableCard> with RouteAware {
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

  // Don't leave a stale confirmation overlay up after returning to this route.
  @override
  void didPopNext() => _close();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 8,
          right: 8,
          child: CardCornerBadge(
            icon: Icons.close,
            backgroundColor: AppColors.surfaceTranslucent,
            iconColor: AppColors.hintText,
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [],
            size: 36,
            iconSize: 20,
            discAlignment: Alignment.topRight,
            onTap: _open,
          ),
        ),
        if (_confirming)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: RemovableCard._borderRadius,
              child: Container(
                color: AppColors.scrimBackdrop,
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
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
                              color: AppColors.surfaceTranslucentMedium,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              l10n.remove.toUpperCase(),
                              style: AppTextStyle.bold16.copyWith(
                                color: AppColors.textPrimary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: _close,
                          child: Text(
                            l10n.cancel.toLowerCase(),
                            style: AppTextStyle.regular16.copyWith(
                              color: AppColors.textOnPrimary,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.textOnPrimary,
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
