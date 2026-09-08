import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/filter_button.dart';
import 'package:uwearis/features/widgets/common/fields/selectable_chip.dart';

import '../helpers/widget_harness.dart';

void main() {
  Future<void> open(WidgetTester tester, VoidCallback Function(BuildContext) run) {
    return pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: run(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Finder chipWithText(String text) => find.byWidgetPredicate(
    (w) => w is SelectableChip && w.label == text,
  );

  MainAxisAlignment rowAlignmentOf(WidgetTester tester, String chipLabel) {
    // The chip's own subtree has no Row, so its single Row ancestor is the
    // one _buildRow produced.
    final rows = find
        .ancestor(of: chipWithText(chipLabel), matching: find.byType(Row))
        .evaluate()
        .map((e) => e.widget as Row)
        .toList();
    return rows.first.mainAxisAlignment;
  }

  void useNarrowSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('showChipGroupsSheet — filter (toggleAll) group', () {
    testWidgets('the "All" pill sits beside the title, above the option chips', (
      tester,
    ) async {
      var seasons = {'All'};
      await open(
        tester,
        (context) => () => showChipGroupsSheet<void>(
          context,
          groups: [
            FilterGroup.toggleAll(
              label: 'Season',
              options: const ['All', 'Summer', 'Winter'],
              selected: () => seasons,
              onChanged: (next) => seasons = next,
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // one "All" chip (a real SelectableChip pill), and the option chips
      expect(chipWithText('All'), findsOneWidget);
      expect(chipWithText('Summer'), findsOneWidget);
      expect(chipWithText('Winter'), findsOneWidget);

      // the "All" pill is on the title's row...
      final titleY = tester.getCenter(find.text('Season')).dy;
      final allY = tester.getCenter(chipWithText('All')).dy;
      expect((allY - titleY).abs(), lessThan(30));

      // ...and the option chips are below it
      expect(
        tester.getTopLeft(chipWithText('Summer')).dy,
        greaterThan(tester.getBottomLeft(chipWithText('All')).dy),
      );
    });

    Future<void> openColorSheet(WidgetTester tester, List<String> opts) async {
      var colors = {'All'};
      await open(
        tester,
        (context) => () => showChipGroupsSheet<void>(
          context,
          groups: [
            FilterGroup.toggleAll(
              label: 'Color',
              options: ['All', ...opts],
              selected: () => colors,
              onChanged: (n) => colors = n,
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('a single row that fills most of the width is justified '
        'edge-to-edge', (tester) async {
      useNarrowSurface(tester);
      await openColorSheet(tester, const ['Red', 'Blue', 'Tan']);
      expect(rowAlignmentOf(tester, 'Red'), MainAxisAlignment.spaceBetween);
    });

    testWidgets('a sparse row (2 short chips) stays left-aligned', (
      tester,
    ) async {
      useNarrowSurface(tester);
      await openColorSheet(tester, const ['Red', 'Tan']);
      expect(
        rowAlignmentOf(tester, 'Red'),
        isNot(MainAxisAlignment.spaceBetween),
      );
    });

    testWidgets('tapping the "All" pill runs the same toggleWithAll logic', (
      tester,
    ) async {
      var seasons = {'All'};
      await open(
        tester,
        (context) => () => showChipGroupsSheet<void>(
          context,
          groups: [
            FilterGroup.toggleAll(
              label: 'Season',
              options: const ['All', 'Summer', 'Winter'],
              selected: () => seasons,
              onChanged: (next) => seasons = next,
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(chipWithText('Summer'));
      await tester.pumpAndSettle();
      expect(seasons, {'Summer'});

      await tester.tap(chipWithText('All'));
      await tester.pumpAndSettle();
      expect(seasons, {'All'});
    });
  });

  group('showChipGroupsSheet — plain multi-select + confirm button', () {
    testWidgets('no "All" pill, a Save button, and it pops confirmResult', (
      tester,
    ) async {
      final sel = <String>{'Spring'};
      ({List<String> tags})? result;

      await open(
        tester,
        (context) => () async {
          result = await showChipGroupsSheet<({List<String> tags})>(
            context,
            groups: [
              FilterGroup(
                label: 'Season',
                options: const ['Spring', 'Summer', 'Winter'],
                selected: () => sel,
                onToggle: (o) {
                  if (!sel.remove(o)) sel.add(o);
                },
              ),
            ],
            confirmLabel: 'Save',
            confirmResult: () => (tags: sel.toList()),
          );
        },
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(chipWithText('All'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Save'), findsOneWidget);

      await tester.tap(chipWithText('Summer'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.tags.toSet(), {'Spring', 'Summer'});
    });

    testWidgets('dismissing without Save pops null', (tester) async {
      final sel = <String>{'Spring'};
      Object? result = 'unset';

      await open(
        tester,
        (context) => () async {
          result = await showChipGroupsSheet<({List<String> tags})>(
            context,
            groups: [
              FilterGroup(
                label: 'Season',
                options: const ['Spring', 'Summer'],
                selected: () => sel,
                onToggle: (o) {
                  if (!sel.remove(o)) sel.add(o);
                },
              ),
            ],
            confirmLabel: 'Save',
            confirmResult: () => (tags: sel.toList()),
          );
        },
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });
}
