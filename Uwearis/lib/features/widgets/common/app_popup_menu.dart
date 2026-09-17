import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

class AppPopupMenu<T> extends StatelessWidget {
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? trigger;

  const AppPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.trigger,
  });

  @override
  Widget build(BuildContext context) {
    final Widget target = trigger != null
        ? SizedBox(
            width: AppDimens.minTouchTarget,
            height: AppDimens.minTouchTarget,
            child: Align(alignment: Alignment.topRight, child: trigger),
          )
        : const SizedBox.square(
            dimension: AppDimens.toolbarHeight,
            child: Center(
              child: Icon(
                Icons.more_vert,
                size: AppDimens.toolbarActionIconSize,
                color: AppColors.icon,
              ),
            ),
          );

    return PopupMenuButton<T>(
      padding: EdgeInsets.zero,
      borderRadius: trigger == null
          ? BorderRadius.circular(AppDimens.toolbarHeight / 2)
          : null,
      color: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(-16, 40),
      constraints: const BoxConstraints(minWidth: 0, maxWidth: 180),
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: Semantics(button: true, child: target),
    );
  }

  static PopupMenuItem<T> item<T>({
    required T value,
    Widget? icon,
    required String label,
    bool isDestructive = false,
    bool enabled = true,
  }) {
    return PopupMenuItem<T>(
      value: value,
      enabled: enabled,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (icon != null) ...[icon, const SizedBox(width: 8)],
          Text(
            label,
            style: AppTextStyle.regular14.copyWith(
              fontWeight: FontWeight.w500,
              color: isDestructive ? AppColors.error : null,
            ),
          ),
        ],
      ),
    );
  }
}
