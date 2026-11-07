import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import 'action_disc_button.dart';

/// Toolbar leading switch between Home and Explore: an [ActionDisc] showing
/// [label]'s first letter that widens to the full [label] on tap, then runs
/// [onPressed]. It collapses again once [onPressed]'s future completes, i.e.
/// when a pushed route is popped back to this page.
class SpaceSwitchButton extends StatefulWidget {
  final String label;
  final FutureOr<void> Function() onPressed;

  static const expandDuration = Duration(milliseconds: 240);

  // Lets the full label read before the route transition covers it.
  static const _hold = Duration(milliseconds: 120);

  const SpaceSwitchButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  State<SpaceSwitchButton> createState() => _SpaceSwitchButtonState();
}

class _SpaceSwitchButtonState extends State<SpaceSwitchButton> {
  bool _expanded = false;

  Future<void> _handleTap() async {
    if (_expanded) return;
    setState(() => _expanded = true);
    await Future<void>.delayed(
      SpaceSwitchButton.expandDuration + SpaceSwitchButton._hold,
    );
    if (!mounted) return;
    await widget.onPressed();
    if (mounted) setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: (AppDimens.toolbarHeight - ActionDisc.size) / 2,
          ),
          child: SizedBox(
            height: AppDimens.toolbarHeight,
            child: Center(
              widthFactor: 1,
              child: ActionDisc(
                child: AnimatedSize(
                  duration: SpaceSwitchButton.expandDuration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: _expanded ? 16 : 0,
                    ),
                    child: Text(
                      _expanded ? label : label.characters.first,
                      textScaler: TextScaler.noScaling,
                      maxLines: 1,
                      softWrap: false,
                      style: AppTextStyle.bold18,
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
