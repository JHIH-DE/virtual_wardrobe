import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';

/// The app's one "⋮" overflow-menu look — same shape, elevation, sizing,
/// and item layout everywhere it shows up (trip/outfit/garment detail app
/// bars, trip cards, image overlays). Deliberately never groups items with
/// a divider — a destructive action is told apart by color (see
/// [AppPopupMenu.item]'s [isDestructive]) rather than a rule.
///
/// Positions itself with a plain [CompositedTransformFollower] rather than
/// [PopupMenuButton] or [MenuAnchor]: both frameworks widgets round their
/// menu width up to a fixed step/cap, and — for [MenuAnchor] specifically —
/// its screen-edge collision handling only flips to the far side of a
/// horizontal *sibling* menu; a standalone anchor like this one always
/// falls through to clamping flush against the physical screen edge
/// instead of the trigger, which visibly detaches the menu from a trigger
/// that (as ours always is) sits near a corner. Anchoring manually keeps
/// the menu's top-right corner pinned to the trigger's bottom-right corner
/// regardless of screen position.
///
/// The trigger defaults to a plain "⋮" glyph in a [AppDimens.toolbarHeight]
/// square, so in an AppToolBar its touch target matches the back button.
/// Pass [trigger] for a fully custom widget instead — for menus that sit on
/// top of a photo and need their own contrasting backdrop.
class AppPopupMenu<T> extends StatefulWidget {
  final List<AppPopupMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget? trigger;

  const AppPopupMenu({
    super.key,
    required this.items,
    required this.onSelected,
    this.trigger,
  });

  /// One row: an optional [icon] + [label], sized/spaced the same in every
  /// menu that uses [AppPopupMenu]. [isDestructive] tints the label (never
  /// the icon) red instead of relying on a divider to set a delete/remove
  /// action apart from the rest. Omit [icon] for a text-only item (e.g. a
  /// single-action menu with nothing to differentiate via icon).
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

  // The app navigates with a plain Navigator (see CLAUDE.md's Navigation
  // section) rather than the Router API, so BackButtonListener — which
  // requires a Router ancestor — isn't available here. didPopRoute is the
  // Router-independent hook for the same job: close the menu on Android's
  // back gesture instead of letting it pop the whole page underneath.
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

    return CompositedTransformTarget(
      link: _layerLink,
      child: Tooltip(
        message: MaterialLocalizations.of(context).showMenuTooltip,
        child: InkWell(
          borderRadius: widget.trigger == null
              ? BorderRadius.circular(AppDimens.toolbarHeight / 2)
              : null,
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
                                      style: AppTextStyle.regular14.copyWith(
                                        fontWeight: FontWeight.w500,
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

/// One [AppPopupMenu] entry, built via [AppPopupMenu.item] — a plain data
/// description, not a widget itself; [AppPopupMenu] turns each one into the
/// actual tappable row wired to its [ValueChanged] callback.
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
