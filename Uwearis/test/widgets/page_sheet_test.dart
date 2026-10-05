import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/common/app_popup_menu.dart';
import 'package:uwearis/features/widgets/common/app_tool_bar.dart';
import 'package:uwearis/features/widgets/common/overlays/page_sheet.dart';
import 'package:uwearis/features/widgets/common/overlays/picker_sheet.dart';

import '../helpers/widget_harness.dart';

void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    double width = 390,
    Widget? leading,
  }) async {
    // A phone-like screen with a status bar, so the sheet's top edge (kept
    // below it) and the toolbar's both sit under a non-zero inset.
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      Scaffold(
        appBar: AppToolBar(
          title: 'Page',
          actions: [
            AppPopupMenu<int>(
              onSelected: (_) {},
              items: [AppPopupMenu.item(value: 1, label: 'One')],
            ),
          ],
        ),
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPageSheet<void>(
              context,
              title: 'Sheet',
              leading: leading,
              builder: (_) => const Text('Body'),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sheet starts right at the tool bar\'s bottom, with a title and '
      'an X', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.byType(SheetDragHandle), findsNothing);
    expect(find.byType(PickerSheetHeader), findsNothing);
    expect(find.byType(AppDivider), findsNothing);
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(sheet.top, tester.getBottomLeft(find.byType(AppToolBar)).dy);
    expect(sheet.bottom, 844);
  });

  testWidgets('the X disc sits 16 from the top and 16 from the right, with '
      'the title level with it and centred on the sheet', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    // The glyph is centred on its 36px disc.
    final sheet = tester.getRect(find.byType(BottomSheet));
    final close = tester.getCenter(find.byIcon(Icons.close));
    expect(close.dx, sheet.right - 16 - 18);
    expect(close.dy, sheet.top + 16 + 18);
    final title = tester.getCenter(find.text('Sheet'));
    expect(title.dy, close.dy);
    expect(title.dx, sheet.center.dx);
  });

  testWidgets('spans the full screen width, even past 640', (tester) async {
    await pumpAndOpen(tester, width: 800);

    expect(tester.getSize(find.byType(BottomSheet)).width, 800);
    expect(tester.getCenter(find.byIcon(Icons.close)).dx, 800 - 16 - 18);
  });

  testWidgets('a leading action mirrors the X at the top left', (
    tester,
  ) async {
    var taps = 0;
    await pumpAndOpen(
      tester,
      leading: PageSheetAction(
        icon: Icons.refresh,
        label: 'Refresh',
        onTap: () => taps++,
      ),
    );

    final sheet = tester.getRect(find.byType(BottomSheet));
    final leading = tester.getCenter(find.byIcon(Icons.refresh));
    expect(leading.dx, sheet.left + 16 + 18);
    expect(leading.dy, tester.getCenter(find.byIcon(Icons.close)).dy);

    await tester.tap(find.byIcon(Icons.refresh));
    expect(taps, 1);
  });

  testWidgets('a busy action shows a spinner and ignores taps', (
    tester,
  ) async {
    var taps = 0;
    // pumpAndOpen settles the open animation; the busy spinner never settles,
    // so open with a plain action and only then swap in the busy one.
    final busy = ValueNotifier(false);
    addTearDown(busy.dispose);
    await pumpAndOpen(
      tester,
      leading: ValueListenableBuilder<bool>(
        valueListenable: busy,
        builder: (_, isBusy, _) => PageSheetAction(
          icon: Icons.refresh,
          label: 'Refresh',
          busy: isBusy,
          onTap: () => taps++,
        ),
      ),
    );
    busy.value = true;
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byIcon(Icons.refresh), warnIfMissed: false);
    expect(taps, 0);
  });

  testWidgets('close button dismisses the sheet', (tester) async {
    await pumpAndOpen(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Sheet'), findsNothing);
  });
}
