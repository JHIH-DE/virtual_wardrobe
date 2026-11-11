import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/labeled_divider.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFont();
  });

  testWidgets('a label too long for one line wraps between the rules', (
    tester,
  ) async {
    applyLayoutCase(tester, (width: 320, scale: 2, locale: const Locale('en')));
    await pumpApp(
      tester,
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: LabeledDivider(label: 'Match Your Wardrobe'),
      ),
    );

    final label = find.text('Match Your Wardrobe');
    expect(renderedLineCount(tester, label), greaterThan(1));
    expectNoBrokenWords(tester, label);
    for (final rule in tester.widgetList(find.byType(Divider))) {
      expect(
        tester.getSize(find.byWidget(rule)).width,
        greaterThanOrEqualTo(LabeledDivider.minRuleWidth),
      );
    }
  });
}
