import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// The app's one "⋮" overflow-menu look — same shape, elevation, sizing,
/// and item layout everywhere it shows up (trip/outfit/garment detail app
/// bars, trip cards, image overlays). Deliberately never uses a
/// [PopupMenuDivider] — grouping is left to whichever items a call site
/// chooses to include, and a destructive action is told apart by color
/// (see [AppPopupMenu.item]'s [isDestructive]) rather than a rule.
///
/// Pass exactly one of [icon] (a plain icon-button trigger, for menus that
/// sit on an opaque toolbar/card background) or [trigger] (a fully custom
/// widget, for menus that sit on top of a photo and need their own
/// contrasting backdrop — see [PopupMenuButton.child]).
class AppPopupMenu<T> extends StatelessWidget {
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? icon;
  final Widget? trigger;

  const AppPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon,
    this.trigger,
  }) : assert(
         icon == null || trigger == null,
         'Pass either icon or trigger, not both',
       );

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      padding: EdgeInsets.zero,
      icon: trigger == null
          ? (icon ?? const Icon(Icons.more_vert, color: AppColors.icon))
          : null,
      color: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Narrower than the default 112-280 range, which leaves a lot of
      // empty space around these short one-line items.
      constraints: const BoxConstraints(minWidth: 0, maxWidth: 220),
      // Default menuPadding is 8px vertical around the whole item list on
      // top of each item's own height — shrunk since these menus only ever
      // hold a handful of short items.
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      onSelected: onSelected,
      itemBuilder: (context) => items,
      // PopupMenuButton only reads `child` when `icon` is null.
      child: trigger,
    );
  }

  /// One row: an optional [icon] + [label], sized/spaced the same in every
  /// menu that uses [AppPopupMenu]. [isDestructive] tints the label (never
  /// the icon) red instead of relying on a divider to set a delete/remove
  /// action apart from the rest. Omit [icon] for a text-only item (e.g. a
  /// single-action menu with nothing to differentiate via icon).
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
