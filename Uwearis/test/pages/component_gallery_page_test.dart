import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/component_gallery_page.dart';
import 'package:uwearis/features/pages/debug_tools_page.dart';
import 'package:uwearis/features/widgets/common/fields/selectable_chip.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  testWidgets('Debug Tools opens the component gallery', (tester) async {
    await pumpApp(tester, const DebugToolsPage());
    await tester.tap(find.text('Component Gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(ComponentGalleryPage), findsOneWidget);
  });

  testWidgets('renders every section at 1.0 without a layout error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 8000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await pumpApp(tester, const ComponentGalleryPage());

    expect(tester.takeException(), isNull);
    expect(find.text('ErrorStateWidget'), findsOneWidget);
  });

  testWidgets('the BottomActionButton chip toggles the bottom bar', (
    tester,
  ) async {
    await pumpApp(tester, const ComponentGalleryPage());
    expect(find.text('Save'), findsWidgets);

    await tester.tap(find.widgetWithText(SelectableChip, 'BottomActionButton'));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.bottomNavigationBar, isNull);
  });

  group('every layout case', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      testWidgets('lays out with no overflow, and the button pair keeps '
          'whole labels at ${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c, height: 9000);
        await pumpApp(tester, const ComponentGalleryPage());
        // The gallery applies its own scale chip on top of the system one;
        // pick the case's scale there and keep the system at 1.0.
        tester.platformDispatcher.textScaleFactorTestValue = 1.0;
        await tester.tap(
          find.widgetWithText(SelectableChip, '${c.scale.toStringAsFixed(1)}×'),
        );
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(ComponentGalleryPage)),
        );
        final pair = find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ActionButtonPair',
        );
        Finder inPair(String label) =>
            find.descendant(of: pair, matching: find.text(label));
        final primary = inPair(l10n.createOutfit);
        final secondary = inPair(l10n.viewClosetMatch);

        final stacked =
            tester.getRect(secondary).top >= tester.getRect(primary).bottom;
        for (final label in [primary, secondary]) {
          // Side by side only happens when both fit on one line; once
          // stacked, a label wider than the whole row wraps — never cut.
          expect(renderedLineCount(tester, label), stacked ? lessThan(3) : 1);
          expectWithin(
            tester,
            label,
            find.ancestor(of: label, matching: find.byType(ElevatedButton)),
          );
        }
        if (c.width == 390 && c.scale == 1.0 && c.locale.languageCode == 'zh') {
          expect(stacked, isFalse, reason: 'short labels stay side by side');
        }
        if (c.scale == 2.0) {
          expect(stacked, isTrue, reason: '2.0× cannot fit both in a row');
        }
      });
    }
  });
}
