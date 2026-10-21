import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/app_popup_menu.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('tapping an item calls onSelected with its value', (
    tester,
  ) async {
    String? selected;
    await pumpApp(
      tester,
      Scaffold(
        appBar: AppBar(
          actions: [
            AppPopupMenu<String>(
              onSelected: (value) => selected = value,
              items: [
                AppPopupMenu.item(value: 'rename', label: 'Rename'),
                AppPopupMenu.item(
                  value: 'delete',
                  label: 'Delete',
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
        body: const SizedBox(),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(selected, 'delete');
  });

  // Longest menu label in the app (create_outfit_page.dart).
  testWidgets('the longest existing label renders without overflowing', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        appBar: AppBar(
          actions: [
            AppPopupMenu<String>(
              onSelected: (_) {},
              items: [
                AppPopupMenu.item(
                  value: 'remove',
                  label: 'Remove Reference Look',
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
        body: const SizedBox(),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Remove Reference Look'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens below the trigger, right edge inset 10px from it, '
      'regardless of screen position', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        appBar: AppBar(
          actions: [
            AppPopupMenu<String>(
              onSelected: (_) {},
              items: [AppPopupMenu.item(value: 'a', label: 'A')],
            ),
          ],
        ),
        body: const SizedBox(),
      ),
    );

    // The menu anchors to the hit-target box, not the smaller glyph.
    final triggerRect = tester.getRect(find.byType(CompositedTransformTarget));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final menuRect = tester.getRect(
      find.ancestor(of: find.text('A'), matching: find.byType(Material)).first,
    );

    // Anchored to the trigger (10px in), not clamped to the screen edge.
    expect(menuRect.top, greaterThanOrEqualTo(triggerRect.bottom));
    expect(menuRect.right, closeTo(triggerRect.right - 10, 1));
  });

  testWidgets('menu item width is snug to its content, not rounded up to a '
      'fixed step', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        appBar: AppBar(
          actions: [
            AppPopupMenu<String>(
              onSelected: (_) {},
              items: [AppPopupMenu.item(value: 'a', label: 'A')],
            ),
          ],
        ),
        body: const SizedBox(),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    final itemWidth = tester
        .getSize(
          find
              .ancestor(of: find.text('A'), matching: find.byType(Container))
              .last,
        )
        .width;
    final textWidth = tester.getSize(find.text('A')).width;

    // 12px padding each side, no icon.
    expect(itemWidth, closeTo(textWidth + 24, 1));
  });

  testWidgets('tapping outside the menu dismisses it without selecting', (
    tester,
  ) async {
    String? selected;
    await pumpApp(
      tester,
      Scaffold(
        appBar: AppBar(
          actions: [
            AppPopupMenu<String>(
              onSelected: (value) => selected = value,
              items: [AppPopupMenu.item(value: 'a', label: 'A')],
            ),
          ],
        ),
        body: const SizedBox(),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('A'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsNothing);
    expect(selected, isNull);
  });

  testWidgets('a disabled item does not fire onSelected', (tester) async {
    String? selected;
    await pumpApp(
      tester,
      Scaffold(
        appBar: AppBar(
          actions: [
            AppPopupMenu<String>(
              onSelected: (value) => selected = value,
              items: [
                AppPopupMenu.item(value: 'a', label: 'A', enabled: false),
              ],
            ),
          ],
        ),
        body: const SizedBox(),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
