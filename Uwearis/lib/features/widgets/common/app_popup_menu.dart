import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

/// The app's one "⋮" overflow-menu look — same shape, elevation, sizing,
/// and item layout everywhere it shows up (trip/outfit/garment detail app
/// bars, trip cards, image overlays). Deliberately never uses a
/// [PopupMenuDivider] — grouping is left to whichever items a call site
/// chooses to include, and a destructive action is told apart by color
/// (see [AppPopupMenu.item]'s [isDestructive]) rather than a rule.
///
/// The trigger defaults to a plain "⋮" glyph in a [AppDimens.toolbarHeight]
/// square, so in an AppToolBar its touch target matches the back button.
/// Pass [trigger] for a fully custom widget instead — for menus that sit on
/// top of a photo and need their own contrasting backdrop.
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
    // Always the `child` path, never `icon`: PopupMenuButton wraps `icon`
    // in its own IconButton with no way to size the hit area, whereas
    // `child` gets an explicit box and is still wrapped in PopupMenuButton's
    // opaque InkWell + Tooltip.
    final Widget target = trigger != null
        // Photo-overlay menus: keep the caller's disc pinned to its corner
        // (Align.topRight) and grow the hit band inward to minTouchTarget.
        ? SizedBox(
            width: AppDimens.minTouchTarget,
            height: AppDimens.minTouchTarget,
            child: Align(alignment: Alignment.topRight, child: trigger),
          )
        // Default "⋮" — a toolbar-slot square so the touch target matches
        // AppToolBar's back button, with the glyph sized explicitly (not via
        // the ambient IconTheme) so it stays consistent in card contexts too.
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
      // PopupMenuButton wraps `child` in an InkWell whose ink defaults to a
      // rectangle; round it to a circle for the default "⋮" so its press
      // ripple matches the IconButton-based actions (back arrow, filter).
      // The photo-overlay `trigger` keeps the default (its disc paints its
      // own shape).
      borderRadius: trigger == null
          ? BorderRadius.circular(AppDimens.toolbarHeight / 2)
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
      child: Semantics(button: true, child: target),
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
