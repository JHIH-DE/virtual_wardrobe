import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

class AppToolBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color? backgroundColor;
  final VoidCallback? onBack;
  final bool showBackButton;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const AppToolBar({
    super.key,
    required this.title,
    this.backgroundColor,
    this.onBack,
    this.showBackButton = true,
    this.leading,
    this.actions,
    this.bottom,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 1));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.defaultToolBar,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: centerTitle,
      title: Text(
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
      bottom:
          bottom ??
          const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.dividerSubtle,
            ),
          ),
    );
  }
}
