import 'package:flutter/widgets.dart';

/// Tracks a boolean `pressed` flag via tap-down/up/cancel, for widgets that
/// animate their own look in response to a press (scale, color, ...)
/// without each hand-rolling the same field + setter.
mixin PressedStateMixin<T extends StatefulWidget> on State<T> {
  bool pressed = false;

  void setPressed(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }
}
