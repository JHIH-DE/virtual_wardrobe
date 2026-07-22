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
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

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
                      padding: const EdgeInsets.all(4),
                      child: Image.asset(
                        'assets/images/page_arrow_left.png',
                        height: AppDimens.iconMediumSize,
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
