import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/app_divider.dart';
import 'package:uwearis/features/widgets/common/app_popup_menu.dart';
import 'package:uwearis/features/widgets/common/app_tool_bar.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/overlays/page_sheet.dart';
import 'package:uwearis/features/widgets/common/overlays/picker_sheet.dart';

import '../helpers/widget_harness.dart';

void main() {
  Future<void> pumpAndOpen(
    WidgetTester tester, {
    double width = 390,
    Widget? leading,
  }) async {
    // A phone-like screen with a status bar, so the toolbar (and the sheet
    // lined up with it) sits under a non-zero inset.
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
              variant: AppPopupMenuVariant.toolbar,
              onSelected: (_) {},
              items: [AppPopupMenu.item(value: 1, label: 'One')],
            ),
          ],
        ),
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => pageSheet<void>(
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

  testWidgets('sheet\'s top is level with the top of the toolbar\'s action '
      'discs, with a title and an X', (tester) async {
    await pumpAndOpen(tester);

    expect(find.text('Sheet'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);
    expect(find.byType(SheetDragHandle), findsNothing);
    expect(find.byType(PickerSheetHeader), findsNothing);
    expect(find.byType(AppDivider), findsNothing);
    final sheet = tester.getRect(find.byType(BottomSheet));
    expect(
      sheet.top,
      tester
          .getRect(
            find
                .descendant(
                  of: find.byType(AppToolBar),
                  matching: find.byType(ActionDisc),
                )
                .last,
          )
          .top,
    );
    expect(sheet.bottom, 844);
  });

  testWidgets('the X disc sits 20 from the top and 20 from the right, with '
      'the title level with it and centred on the sheet', (tester) async {
    await pumpAndOpen(tester);

    // The glyph is centred on its disc.
    final sheet = tester.getRect(find.byType(BottomSheet));
    final close = tester.getCenter(find.byIcon(Icons.close));
    expect(close.dx, sheet.right - 20 - ActionDisc.size / 2);
    expect(close.dy, sheet.top + 20 + ActionDisc.size / 2);
    final title = tester.getCenter(find.text('Sheet'));
    expect(title.dy, close.dy);
    expect(title.dx, sheet.center.dx);
  });

  testWidgets('spans the full screen width, even past 640', (tester) async {
    await pumpAndOpen(tester, width: 800);

    expect(tester.getSize(find.byType(BottomSheet)).width, 800);
    expect(
      tester.getCenter(find.byIcon(Icons.close)).dx,
      800 - 20 - ActionDisc.size / 2,
    );
  });

  testWidgets('a leading action mirrors the X at the top left', (tester) async {
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
    expect(leading.dx, sheet.left + 20 + ActionDisc.size / 2);
    expect(leading.dy, tester.getCenter(find.byIcon(Icons.close)).dy);

    await tester.tap(find.byIcon(Icons.refresh));
    expect(taps, 1);
  });

  testWidgets('a busy action shows a spinner and ignores taps', (tester) async {
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
    await tester.tap(
      find.byType(CircularProgressIndicator),
      warnIfMissed: false,
    );
    expect(taps, 0);
  });

  testWidgets('the sheet is plain pageBackground, with no gradient', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
      AppColors.pageBackground,
    );
    // The header actions' ActionDisc carries its own gradient fill; only
    // the sheet's own surface must be flat.
    final discs = find.byType(ActionDisc);
    final gradients = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where(
          (d) =>
              (d.decoration as BoxDecoration?)?.gradient != null &&
              !discs.evaluate().any(
                (disc) => find
                    .descendant(
                      of: find.byWidget(disc.widget),
                      matching: find.byWidget(d),
                    )
                    .evaluate()
                    .isNotEmpty,
              ),
        );
    expect(gradients, isEmpty);
  });

  testWidgets('close button dismisses the sheet', (tester) async {
    await pumpAndOpen(tester);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('Sheet'), findsNothing);
  });
}
