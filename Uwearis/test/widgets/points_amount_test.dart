import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/points_amount.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('a coin icon, then the grouped number in the given style', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: PointsAmount(1234, style: TextStyle(fontSize: 14))),
    );

    expect(find.text('\u{FFFC} 1,234', findRichText: true), findsOneWidget);
    expect(find.byType(SvgPicture), findsOneWidget);
    final root =
        tester.widget<RichText>(find.byType(RichText).first).text as TextSpan;
    expect(root.style!.fontSize, 14);
  });

  testWidgets('the icon sits on the baseline at the digit height', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(body: PointsAmount(1234, style: TextStyle(fontSize: 40))),
    );

    final icon = tester.getSize(find.byType(SvgPicture));
    expect(icon.height, closeTo(40 * 0.73, 0.01));
  });
}
