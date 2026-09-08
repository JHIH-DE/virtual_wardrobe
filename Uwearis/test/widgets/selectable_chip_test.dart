import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/common/fields/selectable_chip.dart';
import 'package:uwearis/features/widgets/garment/category_selector.dart';
import 'package:uwearis/data/garment.dart' show GarmentCategory;

import '../helpers/widget_harness.dart';

void main() {
  // The visible pill (the decorated Container) inside a chip.
  Finder pillOf(Finder chip) => find.descendant(
    of: chip,
    matching: find.byType(Container),
  );

  group('SelectableChip tap target', () {
    testWidgets('is at least AppDimens.minTouchTarget tall while the visible '
        'pill stays smaller', (tester) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: SelectableChip(label: 'Summer', selected: false),
          ),
        ),
      );

      final chipRect = tester.getRect(find.byType(SelectableChip));
      final pillRect = tester.getRect(pillOf(find.byType(SelectableChip)));

      expect(
        chipRect.height,
        greaterThanOrEqualTo(AppDimens.minTouchTarget),
        reason: 'hit target must clear the 44px minimum',
      );
      expect(
        pillRect.height,
        lessThan(chipRect.height),
        reason: 'the visible pill is not stretched — only the hit area grows',
      );
      // pill stays vertically centred in the band
      expect(
        (pillRect.center.dy - chipRect.center.dy).abs(),
        lessThan(0.5),
      );
    });

    testWidgets('a near-miss tap in the transparent band above the pill still '
        'selects', (tester) async {
      var taps = 0;
      await pumpApp(
        tester,
        Scaffold(
          body: Center(
            child: SelectableChip(
              label: 'Winter',
              selected: false,
              onTap: () => taps++,
            ),
          ),
        ),
      );

      final chipRect = tester.getRect(find.byType(SelectableChip));
      final pillRect = tester.getRect(pillOf(find.byType(SelectableChip)));

      // A point above the visible pill but inside the chip's hit box.
      final aboveThePill = Offset(
        chipRect.center.dx,
        (chipRect.top + pillRect.top) / 2,
      );
      expect(pillRect.contains(aboveThePill), isFalse);
      expect(chipRect.contains(aboveThePill), isTrue);

      await tester.tapAt(aboveThePill);
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('does not inflate its width — Wrap spacing is unchanged', (
      tester,
    ) async {
      await pumpApp(
        tester,
        const Scaffold(
          body: Center(
            child: Wrap(
              spacing: 10,
              children: [
                SelectableChip(label: 'AAAA', selected: false),
                SelectableChip(label: 'BBBB', selected: false),
              ],
            ),
          ),
        ),
      );

      final chips = find.byType(SelectableChip);
      final firstChip = tester.getRect(chips.at(0));
      final firstPill = tester.getRect(pillOf(chips.at(0)));
      final secondChip = tester.getRect(chips.at(1));

      // chip width == pill width (no transparent horizontal padding added)
      expect((firstChip.width - firstPill.width).abs(), lessThan(0.5));
      // exactly the Wrap spacing between the two chips
      expect(secondChip.left - firstChip.right, moreOrLessEquals(10, epsilon: 0.5));
    });
  });

  group('CategorySelector', () {
    testWidgets('every tab has a >=44px tall tap target and a near-miss tap '
        'still switches category', (tester) async {
      GarmentCategory? picked;
      await pumpApp(
        tester,
        Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: CategorySelector(
              categories: const [
                GarmentCategory.top,
                GarmentCategory.bottom,
                GarmentCategory.shoes,
              ],
              selectedCategory: GarmentCategory.top,
              onSelected: (c) => picked = c,
            ),
          ),
        ),
      );

      for (final chip in [0, 1, 2]) {
        final rect = tester.getRect(find.byType(SelectableChip).at(chip));
        expect(
          rect.height,
          greaterThanOrEqualTo(AppDimens.minTouchTarget),
          reason: 'tab $chip tap target',
        );
      }

      // Tap the top edge of the 2nd tab (would miss a ~38px pill centred in
      // the row) and confirm it still registers.
      final secondTab = tester.getRect(find.byType(SelectableChip).at(1));
      await tester.tapAt(Offset(secondTab.center.dx, secondTab.top + 2));
      await tester.pump();
      expect(picked, GarmentCategory.bottom);
    });
  });
}
