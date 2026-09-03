import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/filter_button.dart';

import '../helpers/widget_harness.dart';

void main() {
  group('FilterButton.toggleWithAll', () {
    test('selecting "All" clears everything else', () {
      expect(
        FilterButton.toggleWithAll({'Summer', 'Winter'}, 'All'),
        {'All'},
      );
    });

    test('selecting a value drops "All" and adds it', () {
      expect(FilterButton.toggleWithAll({'All'}, 'Summer'), {'Summer'});
    });

    test('deselecting the last value falls back to "All"', () {
      expect(FilterButton.toggleWithAll({'Summer'}, 'Summer'), {'All'});
    });

    test('adds a second value alongside the first', () {
      expect(
        FilterButton.toggleWithAll({'Summer'}, 'Winter'),
        {'Summer', 'Winter'},
      );
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
        (w) => w is Container && w.constraints?.maxWidth == 8,
      );
      expect(unfilteredDots, findsNothing);

      await pumpApp(tester, Scaffold(body: Center(child: btn(true))));
      expect(
        find.byWidgetPredicate(
          (w) => w is Container && w.constraints?.maxWidth == 8,
        ),
        findsOneWidget,
      );
    });
  });
}
