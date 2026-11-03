import 'dart:async';

import 'package:flutter/material.dart';

/// The app's short bottom message: a dark full-width bar, centred text,
/// gone after [duration] (or when tapped). A new message replaces the one
/// showing.
///
/// Drawn on the root [Overlay] rather than through `ScaffoldMessenger`:
/// Scaffold always lays a SnackBar out above its `bottomNavigationBar`
/// (where `BottomActionButton` lives); this one sits at the very bottom of
/// the screen, over it. Being on the root overlay, it also stays up across
/// a route push or pop.
void showAppSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
}) {
  showAppSnackBarOn(
    Overlay.of(context, rootOverlay: true),
    message,
    duration: duration,
  );
}

/// [showAppSnackBar] for when the context may be gone by the time the
/// message is ready: take the overlay (`Overlay.of(context, rootOverlay:
/// true)`) before the `await`.
void showAppSnackBarOn(
  OverlayState overlay,
  String message, {
  Duration duration = const Duration(seconds: 4),
}) {
  if (!overlay.mounted) return;
  if (_current?.mounted ?? false) _current!.remove();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _AppSnackBar(
      message: message,
      duration: duration,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

OverlayEntry? _current;

class _AppSnackBar extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDone;

  const _AppSnackBar({
    required this.message,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_AppSnackBar> createState() => _AppSnackBarState();
}

class _AppSnackBarState extends State<_AppSnackBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _close);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (mounted) await _controller.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: FadeTransition(
        opacity: _curve,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(_curve),
          child: Semantics(
            liveRegion: true,
            container: true,
            child: GestureDetector(
              onTap: _close,
              child: Material(
                color: colors.inverseSurface,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onInverseSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
