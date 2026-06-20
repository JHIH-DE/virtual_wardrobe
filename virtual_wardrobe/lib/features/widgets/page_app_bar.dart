import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class PageAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color? backgroundColor;
  final VoidCallback? onBack;
  final bool showBackButton;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  const PageAppBar({
    super.key,
    required this.title,
    this.backgroundColor,
    this.onBack,
    this.showBackButton = true,
    this.actions,
    this.bottom,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor ?? AppColors.toolBar,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: centerTitle,
      title: Text(
        title,
        textScaler: TextScaler.noScaling,
        style: AppTextStyle.bold16,
      ),
      leading: showBackButton
          ? IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                child:
                    Image.asset('assets/images/page_arrow_left.png', height: 28),
              ),
              onPressed: onBack ?? () => Navigator.pop(context),
            )
          : null,
      actions: actions,
      bottom: bottom,
    );
  }
}
