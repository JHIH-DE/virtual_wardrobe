import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';

void main() {
  Future<void> pumpOverPage(WidgetTester tester, {VoidCallback? onCancel}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Scaffold(
              extendBody: true,
              body: const SizedBox.expand(),
              bottomNavigationBar: BottomActionButton(
                label: 'Create Version',
                onPressed: () {},
              ),
            ),
            Positioned.fill(
              child: LoadingOverlay(
                label: 'Generating…',
                actionLabel: 'Cancel',
                onAction: onCancel ?? () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('the label and the action sit below the spinner', (tester) async {
    await pumpOverPage(tester);

    final label = tester.getRect(find.textContaining('Generating'));
    // The spinner is the overlay's fixed 90×90 box.
    final spinner = tester.getRect(
      find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 90 && w.height == 90,
      ),
    );
    final cancel = tester.getRect(find.text('Cancel'));
    expect(label.top, greaterThanOrEqualTo(spinner.bottom));
    expect(cancel.top, greaterThan(label.bottom));
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('the spinner and label stay where an overlay without an '
      'action has them', (tester) async {
    await pumpOverPage(tester);
    final withAction = tester.getCenter(find.textContaining('Generating'));

    await tester.pumpWidget(
      const MaterialApp(home: LoadingOverlay(label: 'Generating…')),
    );
    final without = tester.getCenter(find.textContaining('Generating'));

    expect(withAction, without);
  });

  testWidgets('the action keeps its width without the close icon', (
    tester,
  ) async {
    await pumpOverPage(tester);

    final text = tester.getSize(find.text('Cancel')).width;
    final disc = tester.getSize(
      find.ancestor(of: find.text('Cancel'), matching: find.byType(ActionDisc)),
    );
    // 14px padding + 4px gap + 16px icon on one side, 14px on the other,
    // plus the disc's hairline border.
    expect(disc.width, moreOrLessEquals(text + 48, epsilon: 1));
  });

  testWidgets('tapping the action calls it', (tester) async {
    var cancelled = 0;
    await pumpOverPage(tester, onCancel: () => cancelled++);

    await tester.tap(find.text('Cancel'));
    expect(cancelled, 1);
  });
}
