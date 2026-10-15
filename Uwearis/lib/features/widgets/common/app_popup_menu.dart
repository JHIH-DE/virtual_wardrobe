import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import 'buttons/action_disc_button.dart';

/// The app's shared "⋮" overflow menu. No dividers: destructive items are
/// told apart by color ([AppPopupMenuItem.isDestructive]).
///
/// Not [PopupMenuButton]/[MenuAnchor]: both round the menu width up to a
/// fixed step, and [MenuAnchor] clamps a standalone menu to the screen edge
/// rather than the trigger. A [CompositedTransformFollower] keeps the menu's
/// top-right pinned to the trigger's bottom-right.
///
/// Pass [trigger] for a custom trigger (e.g. over a photo).
class AppPopupMenu<T> extends StatefulWidget {
  final List<AppPopupMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? trigger;
  final AppPopupMenuVariant variant;

  const AppPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.trigger,
    this.variant = AppPopupMenuVariant.inline,
  });

  /// [isDestructive] tints the label (not the icon) red.
  static AppPopupMenuItem<T> item<T>({
    required T value,
    Widget? icon,
    required String label,
    bool isDestructive = false,
    bool enabled = true,
  }) {
    return AppPopupMenuItem<T>(
      value: value,
      icon: icon,
      label: label,
      isDestructive: isDestructive,
      enabled: enabled,
    );
  }

  @override
  State<AppPopupMenu<T>> createState() => _AppPopupMenuState<T>();
}

/// Where an [AppPopupMenu]'s default "⋮" trigger sits.
enum AppPopupMenuVariant {
  /// A bare glyph, for cards and rows.
  inline,

  /// On an [ActionDisc], for AppToolBar actions.
  toolbar,
}

class _AppPopupMenuState<T> extends State<AppPopupMenu<T>>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final LayerLink _layerLink = LayerLink();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120),
  );
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _removeOverlay();
    _animation.dispose();
    super.dispose();
  }

  // Closes the menu on Android back instead of popping the page.
  // BackButtonListener needs a Router, and the app uses a plain Navigator.
  @override
  Future<bool> didPopRoute() async {
    if (_overlayEntry != null) {
      await _close();
      return true;
    }
    return false;
  }

  void _toggle() {
    if (_overlayEntry != null) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final overlay = Overlay.of(context);
    WidgetsBinding.instance.addObserver(this);
    _overlayEntry = OverlayEntry(
      builder: (context) => _PopupMenuOverlay<T>(
        layerLink: _layerLink,
        animation: _animation,
        items: widget.items,
        onDismiss: _close,
        onSelected: (value) {
          _close();
          widget.onSelected(value);
        },
      ),
    );
    overlay.insert(_overlayEntry!);
    _animation.forward(from: 0);
  }

  Future<void> _close() async {
    if (_overlayEntry == null) return;
    WidgetsBinding.instance.removeObserver(this);
    await _animation.reverse();
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    final Widget target = widget.trigger != null
        ? SizedBox(
            width: AppDimens.minTouchTarget,
            height: AppDimens.minTouchTarget,
            child: Align(alignment: Alignment.topRight, child: widget.trigger),
          )
        : SizedBox.square(
            dimension: AppDimens.toolbarHeight,
            child: Center(
              child: switch (widget.variant) {
                AppPopupMenuVariant.inline => const Icon(
                  Icons.more_vert,
                  size: AppDimens.toolbarActionIconSize,
                  color: AppColors.icon,
                ),
                AppPopupMenuVariant.toolbar => const ActionDisc(
                  child: Icon(
                    Icons.more_vert,
                    size: ActionDisc.iconSize,
                    color: AppColors.icon,
                  ),
                ),
              },
            ),
          );

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: MaterialLocalizations.of(context).showMenuTooltip,
        child: InkWell(
          customBorder: widget.trigger == null ? const CircleBorder() : null,
          onTap: _toggle,
          child: Semantics(button: true, child: target),
        ),
      ),
    );
  }
}

class _PopupMenuOverlay<T> extends StatelessWidget {
  final LayerLink layerLink;
  final Animation<double> animation;
  final List<AppPopupMenuItem<T>> items;
  final VoidCallback onDismiss;
  final ValueChanged<T> onSelected;

  const _PopupMenuOverlay({
    required this.layerLink,
    required this.animation,
    required this.items,
    required this.onDismiss,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(-10, 0),
          child: FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
              ),
              alignment: Alignment.topRight,
              child: Material(
                color: AppColors.surface,
                elevation: 4,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IntrinsicWidth(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in items)
                          InkWell(
                            onTap: entry.enabled
                                ? () => onSelected(entry.value)
                                : null,
                            child: Opacity(
                              opacity: entry.enabled ? 1 : 0.38,
                              child: Container(
                                height: 44,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                alignment: AlignmentDirectional.centerStart,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (entry.icon != null) ...[
                                      entry.icon!,
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      entry.label,
                                      style: AppTextStyle.medium14.copyWith(
                                        color: entry.isDestructive
                                            ? AppColors.error
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),
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
        ),
      ],
    );
  }
}

/// One [AppPopupMenu] entry (data, not a widget); build via
/// [AppPopupMenu.item].
class AppPopupMenuItem<T> {
  final T value;
  final Widget? icon;
  final String label;
  final bool isDestructive;
  final bool enabled;

  const AppPopupMenuItem({
    required this.value,
    this.icon,
    required this.label,
    this.isDestructive = false,
    this.enabled = true,
  });
}
