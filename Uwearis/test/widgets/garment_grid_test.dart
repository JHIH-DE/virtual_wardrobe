import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/garment/garment_grid.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('renders one tile per item using the shared row height', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: GarmentGrid(
          itemCount: 4,
          itemBuilder: (context, i) => Text('tile $i'),
        ),
      ),
    );

    expect(find.text('tile 0'), findsOneWidget);
    expect(find.text('tile 3'), findsOneWidget);

    final delegate = tester.widget<GridView>(find.byType(GridView)).gridDelegate
        as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.mainAxisExtent, AppDimens.garmentCardHeight);
  });

  testWidgets('scrollable: false shrink-wraps and does not scroll', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: GarmentGrid(
          scrollable: false,
          itemCount: 2,
          itemBuilder: (context, i) => Text('tile $i'),
        ),
      ),
    );

    final grid = tester.widget<GridView>(find.byType(GridView));
    expect(grid.shrinkWrap, isTrue);
    expect(grid.physics, isA<NeverScrollableScrollPhysics>());
  });

  test('gridDelegate is the shared 2-column, fixed-row-height delegate', () {
    const delegate = GarmentGrid.gridDelegate;
    expect(delegate.crossAxisCount, 2);
    expect(delegate.crossAxisSpacing, AppDimens.cardSpacing);
    expect(delegate.mainAxisSpacing, AppDimens.cardSpacing);
    expect(delegate.mainAxisExtent, AppDimens.garmentCardHeight);
  });
}
