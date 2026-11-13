import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/garment/garment_card.dart';

import '../helpers/widget_harness.dart';

const _garment = Garment(
  id: 1,
  name: 'Bomber',
  category: GarmentCategory.outer,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
  imageUrl: '',
);

Future<void> _pump(WidgetTester tester, Garment garment) => pumpApp(
  tester,
  Center(
    child: SizedBox(
      width: 180,
      child: GarmentCard(garment: garment, showSelectionIndicator: false),
    ),
  ),
);

void main() {
  testWidgets('a Not-yet garment shows the Not Owned tag top-left', (
    tester,
  ) async {
    await _pump(tester, _garment.copyWith(isOwned: false));

    final tag = find.text('Not Owned');
    expect(tag, findsOneWidget);
    final card = tester.getRect(find.byType(GarmentCard));
    final tagRect = tester.getRect(tag);
    expect(tagRect.left - card.left, lessThan(card.width / 2));
    expect(tagRect.top - card.top, lessThan(card.height / 2));
  });

  testWidgets('an owned garment has no tag', (tester) async {
    await _pump(tester, _garment);
    expect(find.text('Not Owned'), findsNothing);
  });
}
