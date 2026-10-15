import 'package:flutter/material.dart';

import 'action_button.dart';

/// A screen's primary action, for `Scaffold.bottomNavigationBar`. Hides
/// itself (rather than greying out) whenever the action can't be taken.
class BottomActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool isLoading;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsets panelPadding;

  const BottomActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.enabled = true,
    this.isLoading = false,
    this.leading,
    this.trailing,
    this.panelPadding = const EdgeInsets.fromLTRB(20, 0, 20, 0),
  });

  bool get _isUnavailable => !enabled || onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      // The default transition keys by child key, so a quick hidden →
      // visible → hidden flip hits "Duplicate keys found".
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: _isUnavailable
          ? const SizedBox.shrink(key: ValueKey('bottomActionButton-hidden'))
          : _buildButton(key: const ValueKey('bottomActionButton-visible')),
    );
  }

  Widget _buildButton({required Key key}) {
    return Padding(
      key: key,
      padding: panelPadding,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: ActionButton(
          label: label,
          onPressed: onPressed,
          leading: leading,
          trailing: trailing,
        ),
      ),
    );
  }
}
