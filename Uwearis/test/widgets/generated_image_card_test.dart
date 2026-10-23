import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/cards/generated_image_card.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('without a corner action the empty state keeps its fixed '
      'height (Trip Details)', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: GeneratedImageCard(hasAssignment: true, noImageMessage: 'None'),
      ),
    );
    // 140 plus the 1px border on each side.
    expect(tester.getSize(find.byType(GeneratedImageCard)).height, 142);
  });

  testWidgets('the corner action sits at the empty state\'s bottom-right, '
      'below its content', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: GeneratedImageCard(
          hasAssignment: true,
          noImageMessage: 'None',
          cornerAction: TextButton(onPressed: () {}, child: const Text('Act')),
        ),
      ),
    );
    final card = tester.getRect(find.byType(GeneratedImageCard));
    final action = tester.getRect(find.byType(TextButton));
    final message = tester.getRect(find.text('None'));
    expect(card.height, greaterThanOrEqualTo(140));
    expect(card.right - action.right, lessThanOrEqualTo(13));
    expect(card.bottom - action.bottom, lessThanOrEqualTo(5));
    expect(action.top, greaterThanOrEqualTo(message.bottom));
  });
}
