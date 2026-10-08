import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/garment/garment_outfit_ideas_card.dart';

import '../helpers/widget_harness.dart';

void main() {
  Future<void> pumpCard(WidgetTester tester, {VoidCallback? onTryOn}) {
    return pumpApp(
      tester,
      Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: GarmentOutfitIdeasCard(
            title: 'Outfit 1',
            onTryOn: onTryOn,
            child: const Text('garments'),
          ),
        ),
      ),
    );
  }

  testWidgets('header block — title and Try It On on the interactive-area '
      'tint — sits above the body, split by a divider', (tester) async {
    var taps = 0;
    await pumpCard(tester, onTryOn: () => taps++);

    final header = tester.widget<Container>(
      find
          .ancestor(of: find.text('Outfit 1'), matching: find.byType(Container))
          .first,
    );
    expect(header.color, AppColors.interactiveArea);
    expect(
      tester.getCenter(find.text('Try It On')).dy,
      tester.getCenter(find.text('Outfit 1')).dy,
    );

    final dividerY = tester.getCenter(find.byType(Divider)).dy;
    expect(tester.getBottomLeft(find.text('Outfit 1')).dy, lessThan(dividerY));
    expect(tester.getTopLeft(find.text('garments')).dy, greaterThan(dividerY));

    await tester.tap(find.text('Try It On'));
    expect(taps, 1);
  });

  testWidgets('no onTryOn: no action, same header height', (tester) async {
    await pumpCard(tester, onTryOn: () {});
    final withAction = tester.getTopLeft(find.byType(Divider)).dy;

    await pumpCard(tester);

    expect(find.text('Try It On'), findsNothing);
    expect(tester.getTopLeft(find.byType(Divider)).dy, withAction);
  });
}
