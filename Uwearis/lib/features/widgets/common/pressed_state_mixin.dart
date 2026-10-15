import 'package:flutter/widgets.dart';

/// A `pressed` flag driven by tap-down/up/cancel, for widgets that animate
/// their own pressed look.
mixin PressedStateMixin<T extends StatefulWidget> on State<T> {
  bool pressed = false;

  void setPressed(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }
}
