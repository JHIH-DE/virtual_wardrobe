import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
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

  testWidgets('header — title and Try It On on the card surface, no '
      'divider — sits above the body', (tester) async {
    var taps = 0;
    await pumpCard(tester, onTryOn: () => taps++);

    final header = tester.widget<Container>(
      find
          .ancestor(of: find.text('Outfit 1'), matching: find.byType(Container))
          .first,
    );
    expect(header.color, isNull);
    expect(
      tester.getCenter(find.text('Try It On')).dy,
      tester.getCenter(find.text('Outfit 1')).dy,
    );

    expect(find.byType(Divider), findsNothing);
    expect(
      tester.getBottomLeft(find.text('Outfit 1')).dy,
      lessThan(tester.getTopLeft(find.text('garments')).dy),
    );

    await tester.tap(find.text('Try It On'));
    expect(taps, 1);
  });

  testWidgets('Try It On pill is inset equally from the top and right', (
    tester,
  ) async {
    await pumpCard(tester, onTryOn: () {});
    final card = tester.getRect(find.byType(GarmentOutfitIdeasCard));
    final pill = tester.getRect(
      find.descendant(
        of: find.byType(AccentPillButton),
        matching: find.byType(TextButton),
      ),
    );
    expect(pill.top - card.top, card.right - pill.right);
    expect(
      tester.getCenter(find.text('Outfit 1')).dy,
      moreOrLessEquals(pill.center.dy, epsilon: 0.5),
    );
  });

  testWidgets('no onTryOn: no action, same header height', (tester) async {
    await pumpCard(tester, onTryOn: () {});
    final withAction = tester.getTopLeft(find.text('garments')).dy;

    await pumpCard(tester);

    expect(find.text('Try It On'), findsNothing);
    expect(tester.getTopLeft(find.text('garments')).dy, withAction);
  });
}
