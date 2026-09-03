import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/carousel_dots_indicator.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('renders nothing for a single page', (tester) async {
    await pumpApp(
      tester,
      const CarouselDotsIndicator(count: 1, currentIndex: 0),
    );
    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('renders one dot per page plus an "n / total" counter', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const CarouselDotsIndicator(count: 3, currentIndex: 1),
    );
    expect(find.byType(AnimatedContainer), findsNWidgets(3));
    expect(find.text('2 / 3'), findsOneWidget);
  });

  testWidgets('the active dot is wider than the inactive ones', (tester) async {
    await pumpApp(
      tester,
      const CarouselDotsIndicator(count: 3, currentIndex: 0),
    );
    final widths = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .map((c) => (c.constraints ?? const BoxConstraints()).minWidth)
        .toList();
    expect(widths, [18.0, 6.0, 6.0]);
  });
}
