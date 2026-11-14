import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/cards/swipe_action_card.dart';

import '../helpers/widget_harness.dart';

Future<List<String>> _pump(WidgetTester tester, {bool enabled = true}) async {
  final log = <String>[];
  await pumpApp(
    tester,
    Center(
      child: SizedBox(
        width: 360,
        child: SwipeActionCard(
          enabled: enabled,
          leadingActions: [
            SwipeAction(
              icon: Icons.tune,
              label: 'Adjust',
              onPressed: () => log.add('adjust'),
            ),
          ],
          actions: [
            SwipeAction(
              icon: Icons.lock_outline,
              label: 'Lock',
              onPressed: () => log.add('lock'),
            ),
            SwipeAction(
              icon: Icons.delete_outline,
              label: 'Remove',
              onPressed: () => log.add('remove'),
            ),
          ],
          child: GestureDetector(
            onTap: () => log.add('card'),
            child: const SizedBox(
              height: 84,
              width: double.infinity,
              child: Text('Row', textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    ),
  );
  return log;
}

// warnIfMissed: once open, the card's resting-bounds tap layer sits above
// the slid text, which is expected.
Future<void> _swipe(WidgetTester tester, double dx) async {
  await tester.drag(find.text('Row'), Offset(dx, 0), warnIfMissed: false);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('actions are hidden until the card is swiped left', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await _swipe(tester, -300);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    // Both discs sit right of the slid card, inside its resting bounds.
    final card = tester.getRect(find.byType(SwipeActionCard));
    final row = tester.getRect(find.text('Row'));
    for (final icon in [Icons.lock_outline, Icons.delete_outline]) {
      final disc = tester.getRect(find.byIcon(icon));
      expect(disc.left, greaterThan(row.right));
      expect(disc.right, lessThanOrEqualTo(card.right + 0.5));
    }
  });

  testWidgets('discs match the app bar action discs, with a full '
      'touch target', (tester) async {
    expect(AppDimens.minTouchTarget, greaterThanOrEqualTo(ActionDisc.size + 4));
    final log = await _pump(tester);
    for (final (dx, icon) in [
      (-300.0, Icons.delete_outline),
      (300.0, Icons.tune),
    ]) {
      await _swipe(tester, dx);
      final disc = find
          .ancestor(of: find.byIcon(icon), matching: find.byType(Material))
          .first;
      expect(tester.getSize(disc), const Size.square(ActionDisc.size));
      expect(tester.widget<Icon>(find.byIcon(icon)).size, ActionDisc.iconSize);

      // Just outside the disc is still inside its touch target.
      final rect = tester.getRect(disc);
      await tester.tapAt(rect.bottomCenter + const Offset(0, 1.5));
      await tester.pumpAndSettle();
    }
    expect(log, ['remove', 'adjust']);
  });

  testWidgets('a short swipe snaps back closed', (tester) async {
    await _pump(tester);
    await tester.timedDrag(
      find.text('Row'),
      const Offset(-20, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('tapping an action runs it and closes the card', (tester) async {
    final log = await _pump(tester);
    await _swipe(tester, -300);
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(log, ['remove']);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('tapping the open card closes it without tapping through', (
    tester,
  ) async {
    final log = await _pump(tester);
    await _swipe(tester, -300);
    await tester.tap(find.text('Row'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(log, isEmpty);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    await tester.tap(find.text('Row'));
    expect(log, ['card']);
  });

  testWidgets('swiping right closes an open card', (tester) async {
    await _pump(tester);
    await _swipe(tester, -300);
    await _swipe(tester, 300);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('swiping right reveals the leading action on the left', (
    tester,
  ) async {
    final log = await _pump(tester);
    await _swipe(tester, 300);
    expect(find.byIcon(Icons.tune), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);

    final card = tester.getRect(find.byType(SwipeActionCard));
    final disc = tester.getRect(find.byIcon(Icons.tune));
    expect(disc.left, greaterThanOrEqualTo(card.left - 0.5));
    expect(disc.right, lessThan(tester.getRect(find.text('Row')).left));

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    expect(log, ['adjust']);
    expect(find.byIcon(Icons.tune), findsNothing);
  });

  testWidgets('swiping left closes a right-opened card', (tester) async {
    await _pump(tester);
    await _swipe(tester, 300);
    await _swipe(tester, -300);
    expect(find.byIcon(Icons.tune), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('a disabled card ignores swipes', (tester) async {
    await _pump(tester, enabled: false);
    await _swipe(tester, -300);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await _swipe(tester, 300);
    expect(find.byIcon(Icons.tune), findsNothing);
  });

  testWidgets('screen readers get the actions without swiping', (tester) async {
    final handle = tester.ensureSemantics();
    final log = await _pump(tester);
    final node = tester.getSemantics(find.byType(SwipeActionCard));
    final ids = node.getSemanticsData().customSemanticsActionIds!;
    final labels = [
      for (final id in ids) CustomSemanticsAction.getAction(id)!.label,
    ];
    expect(labels, containsAll(['Adjust', 'Lock', 'Remove']));

    final removeId = ids.firstWhere(
      (id) => CustomSemanticsAction.getAction(id)!.label == 'Remove',
    );
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.customAction,
        viewId: tester.view.viewId,
        nodeId: node.id,
        arguments: removeId,
      ),
    );
    expect(log, ['remove']);
    handle.dispose();
  });
}
