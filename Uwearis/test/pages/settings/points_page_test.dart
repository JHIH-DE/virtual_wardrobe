import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/settings/points_page.dart';

import '../../helpers/text_scale_harness.dart';
import '../../helpers/widget_harness.dart';

void main() {
  setUpAll(loadAppFont);

  testWidgets('selecting a package updates the Continue price', (tester) async {
    await pumpApp(tester, const PointsPage());
    await tester.pumpAndSettle();

    expect(find.text('Continue · NT\$150'), findsOneWidget);

    await tester.tap(find.text('NT\$270'));
    await tester.pumpAndSettle();
    expect(find.text('Continue · NT\$270'), findsOneWidget);
  });

  for (final c in layoutCases) {
    testWidgets('lays out without overflow · ${describeCase(c)}', (
      tester,
    ) async {
      applyLayoutCase(tester, c, height: 1600);
      await pumpApp(tester, const PointsPage());
      await tester.pumpAndSettle();
      expect(find.byType(RadioGroup<int>), findsOneWidget);
    });
  }
}
