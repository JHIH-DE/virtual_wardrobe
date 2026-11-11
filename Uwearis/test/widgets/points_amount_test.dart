import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/points_amount.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('an accent P, then the grouped number in the given style', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: PointsAmount(1234, style: TextStyle(fontSize: 14))),
    );

    expect(find.text('P 1,234', findRichText: true), findsOneWidget);
    final root =
        tester.widget<RichText>(find.byType(RichText)).text as TextSpan;
    final spans = <TextSpan>[];
    root.visitChildren((span) {
      if (span is TextSpan && span.text != null) spans.add(span);
      return true;
    });
    expect(spans.first.text, 'P ');
    expect(spans.first.style!.color, AppColors.accent);
    expect(spans.last.text, '1,234');
    expect(root.style!.fontSize, 14);
  });
}
