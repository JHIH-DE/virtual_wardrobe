import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import 'buttons/action_disc_button.dart';
import 'cards/count_pill.dart';

class AppToolBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;

  /// When set (and [titleWidget] is null), the title renders as
  /// `<title>  <CountPill>` — the My Closet / Outfits tab header shape.
  final int? titleCount;
  final VoidCallback? onBack;
  final bool showBackButton;
  final Widget? leading;
  final double? leadingWidth;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const AppToolBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.titleCount,
    this.onBack,
    this.showBackButton = true,
    this.leading,
    this.leadingWidth,
    this.actions,
    this.bottom,
    this.centerTitle = true,
  });

  bool get _usesBackButton => leading == null && showBackButton;

  @override
  Size get preferredSize => Size.fromHeight(
    AppDimens.toolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

  Widget _buildTitle() {
    final text = Text(
      title,
      textScaler: TextScaler.noScaling,
      style: AppTextStyle.bold22,
    );
    if (titleCount == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        const SizedBox(width: 8),
        CountPill(count: titleCount!),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // No Material `elevation` here — that casts a diffuse, all-around shadow
    // that reads as distinctly "Material". A hand-tuned, near-black,
    // bottom-only shadow instead gives just enough depth for the bar to
    // read as floating above the page, without a hard dividing line.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.toolbarBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: 12,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: AppColors.toolbarBackground,
        foregroundColor: AppColors.textPrimary,
        toolbarHeight: AppDimens.toolbarHeight,
        actionsIconTheme: const IconThemeData(
          size: ActionDisc.iconSize,
          color: AppColors.icon,
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: centerTitle,
        // With nothing leading, the title's own inset lines it up with the
        // discs' 20 from the edge.
        titleSpacing: leading == null && !showBackButton
            ? 20
            : NavigationToolbar.kMiddleSpacing,
        leadingWidth:
            leadingWidth ??
            (_usesBackButton
                ? ActionDisc.edgeInset + AppDimens.toolbarHeight
                : null),
        title: titleWidget != null
            ? Semantics(header: true, label: title, child: titleWidget)
            : _buildTitle(),
        leading:
            leading ??
            (showBackButton
                ? Padding(
                    padding: const EdgeInsets.only(left: ActionDisc.edgeInset),
                    child: ActionDiscButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).backButtonTooltip,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: ActionDisc.iconSize,
                        color: AppColors.icon,
                      ),
                      onPressed: onBack ?? () => Navigator.pop(context),
                    ),
                  )
                : null),
        actions: actions,
        actionsPadding: const EdgeInsets.only(right: ActionDisc.edgeInset),
        bottom: bottom,
      ),
    );
  }
}
