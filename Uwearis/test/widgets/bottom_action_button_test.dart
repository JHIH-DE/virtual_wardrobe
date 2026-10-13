import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('flipping hidden → visible → hidden before the 200ms switch '
      'finishes does not collide the two outgoing "hidden" children', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    await pumpApp(
      tester,
      Scaffold(
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, isEnabled, _) => BottomActionButton(
            label: 'Confirm',
            enabled: isEnabled,
            onPressed: () {},
          ),
        ),
      ),
    );

    enabled.value = true;
    await tester.pump(const Duration(milliseconds: 50));
    enabled.value = false;
    await tester.pump(const Duration(milliseconds: 50));
    enabled.value = true;
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('bottomActionButton-visible')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bottomActionButton-hidden')),
      findsNothing,
    );
  });
}
