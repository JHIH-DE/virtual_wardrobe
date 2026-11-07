import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../adaptive_side_layout.dart';

class AppListCard extends StatelessWidget {
  final String? title;
  final VoidCallback? onTap;
  final Widget child;
  final bool showArrow;
  final String? leadingAsset;
  final Widget? leading;
  final String? summary;
  final double minHeight;
  final double leadingSize;
  final Widget? trailing;

  /// Disabled: not tappable, no arrow, content dimmed.
  final bool enabled;

  const AppListCard({
    super.key,
    this.title,
    this.onTap,
    required this.child,
    this.showArrow = false,
    this.leadingAsset,
    this.leading,
    this.summary,
    this.minHeight = 54,
    this.leadingSize = 40,
    this.trailing,
    this.enabled = true,
  });

  static const double _disabledOpacity = 0.4;
  static const double _leadingGap = 18;

  @override
  Widget build(BuildContext context) {
    final tap = enabled ? onTap : null;
    final summaryText = summary == null
        ? null
        : Text(
            summary!,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          );
    // A leading decoration moves above the text when a long word at the
    // current text size wouldn't fit beside it, rather than breaking it.
    final leadingWidget =
        leading ??
        (leadingAsset == null
            ? null
            : Image.asset(
                leadingAsset!,
                width: leadingSize,
                height: leadingSize,
              ));
    Widget buildContent(bool summaryBelow) {
      final textColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Text(title!, style: AppTextStyle.bold16),
            const SizedBox(height: 2),
          ],
          child,
          if (summaryText != null && summaryBelow) ...[
            const SizedBox(height: 2),
            summaryText,
          ],
        ],
      );
      final content = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: leadingWidget == null
                ? textColumn
                : AdaptiveSideLayout(
                    sideEdge: AdaptiveSide.leading,
                    side: leadingWidget,
                    content: textColumn,
                    gap: _leadingGap,
                    stackedGap: 8,
                  ),
          ),
          if (summaryText != null && !summaryBelow) ...[
            const SizedBox(width: 8),
            summaryText,
          ],
          if (showArrow && tap != null) ...[
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: AppDimens.iconSmallSize,
              color: AppColors.hintText,
            ),
          ],
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      );
      return content;
    }

    // [summary] sits beside the label while the label still fits on one line
    // next to it at the current text size; otherwise it moves under the label
    // instead of squeezing it.
    final layout = summary == null
        ? buildContent(false)
        : LayoutBuilder(
            builder: (context, constraints) => buildContent(
              !_summaryFitsBeside(
                context,
                constraints.maxWidth,
                leadingWidth: leadingWidget == null
                    ? 0
                    : _leadingWidth(context, leadingWidget),
                hasArrow: showArrow && tap != null,
              ),
            ),
          );

    final card = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFaint,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: enabled
          ? layout
          : Opacity(opacity: _disabledOpacity, child: layout),
    );

    if (!enabled) return Semantics(enabled: false, child: card);
    if (tap != null) {
      return InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        child: card,
      );
    }
    return card;
  }

  /// An [Icon] or sized box reports its own width; anything else is
  /// assumed to fill [leadingSize].
  double _leadingWidth(BuildContext context, Widget leading) =>
      switch (leading) {
        Icon(:final size) => size ?? IconTheme.of(context).size ?? 24,
        SizedBox(:final width?) => width,
        _ => leadingSize,
      };

  /// The label is [title] or a plain [Text] [child]; anything else can't be
  /// measured here, so it falls back to moving [summary] under it as soon as
  /// text is enlarged at all.
  bool _summaryFitsBeside(
    BuildContext context,
    double maxWidth, {
    required double leadingWidth,
    required bool hasArrow,
  }) {
    final scaler = MediaQuery.textScalerOf(context);
    final label = title != null
        ? TextSpan(text: title, style: AppTextStyle.bold16)
        : child is Text && (child as Text).data != null
        ? TextSpan(text: (child as Text).data, style: (child as Text).style)
        : null;
    if (label == null) return scaler.scale(1) <= 1;
    if (trailing != null) return scaler.scale(1) <= 1;

    double widthOf(InlineSpan span) {
      final painter = TextPainter(
        text: span,
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final summaryWidth = widthOf(
      TextSpan(text: summary, style: AppTextStyle.regular14),
    );
    final reserved =
        (leadingWidth > 0 ? leadingWidth + _leadingGap : 0) +
        8 +
        summaryWidth +
        (hasArrow ? 4 + AppDimens.iconSmallSize : 0);
    return widthOf(label) <= maxWidth - reserved;
  }
}
