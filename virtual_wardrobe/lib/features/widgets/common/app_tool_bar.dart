import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

class AppToolBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final VoidCallback? onBack;
  final bool showBackButton;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  /// Height of the default back-arrow glyph (ignored if [leading] is set).
  /// Defaults to [AppDimens.backArrowIconSize] — override per-page only for
  /// a deliberately different size than every other toolbar.
  final double? leadingIconSize;

  /// Padding around the default back-arrow glyph (ignored if [leading] is
  /// set). Defaults to `EdgeInsets.all(2)` — shrink this alongside a larger
  /// [leadingIconSize] so the glyph doesn't get cramped inside the tap
  /// target.
  final EdgeInsetsGeometry? leadingIconPadding;

  const AppToolBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.onBack,
    this.showBackButton = true,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle = true,
    this.leadingIconSize,
    this.leadingIconPadding,
  });

  @override
  Size get preferredSize => Size.fromHeight(
    AppDimens.toolbarHeight + (bottom?.preferredSize.height ?? 0),
  );

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
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: centerTitle,
        title: titleWidget != null
            ? Semantics(header: true, label: title, child: titleWidget)
            : Text(
                title,
                textScaler: TextScaler.noScaling,
                style: AppTextStyle.bold16,
              ),
        leading:
            leading ??
            (showBackButton
                ? IconButton(
                    icon: Container(
                      padding: leadingIconPadding ?? const EdgeInsets.all(2),
                      child: Image.asset(
                        'assets/images/page_arrow_left.png',
                        height: leadingIconSize ?? AppDimens.backArrowIconSize,
                      ),
                    ),
                    onPressed: onBack ?? () => Navigator.pop(context),
                  )
                : null),
        actions: actions,
        bottom: bottom,
      ),
    );
  }
}
