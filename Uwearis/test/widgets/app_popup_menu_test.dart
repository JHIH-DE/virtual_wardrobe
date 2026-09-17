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

  // Fixed (min == max) width, chosen to comfortably fit the app's longest
  // existing menu label without wrapping/overflowing — see
  // add_outfit_page.dart's Match a Look card ("Remove Reference Look",
  // no icon, text-only item).
  testWidgets('the longest existing label fits the fixed menu width without '
      'overflowing', (tester) async {
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

  testWidgets('opens offset 12px down and 8px left of the default anchor', (
    tester,
  ) async {
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

    final button = tester.widget<PopupMenuButton<String>>(
      find.byType(PopupMenuButton<String>),
    );
    expect(button.offset, const Offset(-8, 12));
  });
}
