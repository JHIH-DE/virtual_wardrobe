import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/fields/number_stepper.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('pill variant renders no label, just minus/value/plus', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        NumberStepper(
          variant: NumberStepperVariant.pill,
          valueLabel: '1',
          onDecrement: null,
          onIncrement: () {},
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
  });

  testWidgets('pill variant: tapping +/- fires the right callback', (
    tester,
  ) async {
    var incremented = 0;
    var decremented = 0;
    await tester.pumpWidget(
      host(
        NumberStepper(
          variant: NumberStepperVariant.pill,
          valueLabel: '2',
          onDecrement: () => decremented++,
          onIncrement: () => incremented++,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.tap(find.byIcon(Icons.remove_circle_outline));

    expect(incremented, 1);
    expect(decremented, 1);
  });

  testWidgets('pill variant: null onDecrement means a tap on minus does '
      'nothing (no crash)', (tester) async {
    await tester.pumpWidget(
      host(
        NumberStepper(
          variant: NumberStepperVariant.pill,
          valueLabel: '1',
          onDecrement: null,
          onIncrement: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  double opacityOf(WidgetTester tester) =>
      tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

  testWidgets(
    'pill variant with startRevealed opens fully opaque, fades to '
    'translucent after 3s idle, and a +/- tap revives it for another 3s',
    (tester) async {
      await tester.pumpWidget(
        host(
          NumberStepper(
            variant: NumberStepperVariant.pill,
            valueLabel: '1',
            onDecrement: null,
            onIncrement: () {},
            startRevealed: true,
          ),
        ),
      );

      // Just appeared because the caller says this is a fresh selection —
      // fully visible.
      expect(opacityOf(tester), 1);

      // Not yet 3s — still fully revealed.
      await tester.pump(const Duration(seconds: 2));
      expect(opacityOf(tester), 1);

      await tester.pump(const Duration(seconds: 2));
      expect(opacityOf(tester), 0.6);

      // A tap revives it for another 3s.
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(opacityOf(tester), 1);

      await tester.pump(const Duration(seconds: 4));
      expect(opacityOf(tester), 0.6);
    },
  );

  testWidgets(
    'pill variant defaults to startRevealed: false — mounts already at '
    'rest opacity, e.g. a category-tab remount of an already-selected item',
    (tester) async {
      await tester.pumpWidget(
        host(
          NumberStepper(
            variant: NumberStepperVariant.pill,
            valueLabel: '1',
            onDecrement: null,
            onIncrement: () {},
          ),
        ),
      );

      expect(opacityOf(tester), 0.6);

      // A +/- tap still reveals it like normal.
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(opacityOf(tester), 1);
    },
  );

  testWidgets(
    'pill variant: onRevealConsumed fires once, right after a startRevealed '
    'mount, so the caller can clear its one-shot flag',
    (tester) async {
      var consumedCount = 0;
      await tester.pumpWidget(
        host(
          NumberStepper(
            variant: NumberStepperVariant.pill,
            valueLabel: '1',
            onDecrement: null,
            onIncrement: () {},
            startRevealed: true,
            onRevealConsumed: () => consumedCount++,
          ),
        ),
      );
      await tester.pump();

      expect(consumedCount, 1);

      // A later +/- tap (not a fresh mount) must not fire it again.
      await tester.tap(find.byIcon(Icons.add_circle_outline));
      await tester.pump();
      expect(consumedCount, 1);
    },
  );

  testWidgets('pill variant: a second tap before 3s restarts the countdown '
      'instead of stacking on top of the first', (tester) async {
    await tester.pumpWidget(
      host(
        NumberStepper(
          variant: NumberStepperVariant.pill,
          valueLabel: '1',
          onDecrement: null,
          onIncrement: () {},
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    // Tap again before the first countdown would have fired.
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    // Only 2s since the second tap — still revealed, not the stale 4s mark.
    expect(opacityOf(tester), 1);

    await tester.pump(const Duration(seconds: 1));
    expect(opacityOf(tester), 0.6);
  });

  testWidgets('card/row variants are never wrapped in AnimatedOpacity — '
      'always fully opaque', (tester) async {
    await tester.pumpWidget(
      host(
        NumberStepper(
          label: 'Guests',
          valueLabel: '1',
          onDecrement: null,
          onIncrement: () {},
        ),
      ),
    );

    expect(find.byType(AnimatedOpacity), findsNothing);
  });
}
