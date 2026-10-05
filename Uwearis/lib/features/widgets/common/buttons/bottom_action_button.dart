import 'package:flutter/material.dart';

import 'action_button.dart';

/// A screen's primary action pinned to the bottom (via
/// `Scaffold.bottomNavigationBar`): the solid [ActionButton] in a padded,
/// safe-area-aware panel that hides itself whenever the action can't be
/// taken.
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

  // Hidden whenever the action can't currently be taken — genuinely
  // disabled, or a request for it is already in flight — rather than
  // showing a grayed-out or spinner state in place.
  bool get _isUnavailable => !enabled || onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isUnavailable
          ? const SizedBox.shrink(key: ValueKey('bottomActionButton-hidden'))
          : _buildButton(key: const ValueKey('bottomActionButton-visible')),
    );
  }

  // Only ever built while the action is actually available (see
  // _isUnavailable), so onPressed is always non-null here — no disabled
  // styling to account for.
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
