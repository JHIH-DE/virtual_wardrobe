import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/filter_button.dart';

import '../helpers/widget_harness.dart';

void main() {
  group('FilterButton.toggleWithAll', () {
    test('selecting "All" clears everything else', () {
      expect(FilterButton.toggleWithAll({'Summer', 'Winter'}, 'All'), {'All'});
    });

    test('selecting a value drops "All" and adds it', () {
      expect(FilterButton.toggleWithAll({'All'}, 'Summer'), {'Summer'});
    });

    test('deselecting the last value falls back to "All"', () {
      expect(FilterButton.toggleWithAll({'Summer'}, 'Summer'), {'All'});
    });

    test('adds a second value alongside the first', () {
      expect(FilterButton.toggleWithAll({'Summer'}, 'Winter'), {
        'Summer',
        'Winter',
      });
    });
  });

  group('FilterGroup.toggleAll factory', () {
    test('onToggle routes through toggleWithAll and hands the result to '
        'onChanged', () {
      var selected = {'All'};
      final group = FilterGroup.toggleAll(
        label: 'Season',
        options: const ['All', 'Summer', 'Winter'],
        selected: () => selected,
        onChanged: (next) => selected = next,
      );

      group.onToggle('Summer');
      expect(selected, {'Summer'});
      group.onToggle('Winter');
      expect(selected, {'Summer', 'Winter'});
      group.onToggle('All');
      expect(selected, {'All'});
    });
  });

  testWidgets('chips show labelOf text but toggle the option value', (
    tester,
  ) async {
    var selected = {'All'};
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChipGroupsSheet(
              context,
              groups: [
                FilterGroup.toggleAll(
                  label: 'Style',
                  options: const ['All', 'smart_casual'],
                  labelOf: (v) => v == 'smart_casual' ? '質感休閒' : v,
                  selected: () => selected,
                  onChanged: (next) => selected = next,
                ),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('smart_casual'), findsNothing);
    await tester.tap(find.text('質感休閒'));
    await tester.pump();
    expect(selected, {'smart_casual'});
  });

  testWidgets('All is the first chip of its row, not beside the title', (
    tester,
  ) async {
    var selected = {'Blue'};
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showChipGroupsSheet(
              context,
              groups: [
                FilterGroup.toggleAll(
                  label: 'Color',
                  options: const ['All', 'Blue', 'Extremely Long Green'],
                  selected: () => selected,
                  onChanged: (next) => selected = next,
                ),
              ],
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final all = tester.getTopLeft(find.text('All'));
    expect(all.dy, greaterThan(tester.getBottomLeft(find.text('Color')).dy));
    expect(all.dy, tester.getTopLeft(find.text('Blue')).dy);
    expect(all.dx, lessThan(tester.getTopLeft(find.text('Blue')).dx));
    expect(
      all.dx,
      lessThan(tester.getTopLeft(find.text('Extremely Long Green')).dx),
    );

    await tester.tap(find.text('All'));
    await tester.pump();
    expect(selected, {'All'});
  });

  group('FilterButton widget', () {
    testWidgets('shows the filtered dot only when isFiltered', (tester) async {
      Widget btn(bool filtered) => FilterButton(
        isFiltered: filtered,
        groups: [
          FilterGroup.toggleAll(
            label: 'Season',
            options: const ['All'],
            selected: () => {'All'},
            onChanged: (_) {},
          ),
        ],
      );

      await pumpApp(tester, Scaffold(body: Center(child: btn(false))));
      final unfilteredDots = find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxWidth == 6,
      );
      expect(unfilteredDots, findsNothing);

      await pumpApp(tester, Scaffold(body: Center(child: btn(true))));
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 6,
        ),
        findsOneWidget,
      );
    });
  });
}
