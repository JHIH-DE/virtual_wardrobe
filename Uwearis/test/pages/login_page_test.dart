import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/login_page.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  setUpAll(loadAppFont);

  for (final c in layoutCases) {
    testWidgets('terms notice keeps both links readable · ${describeCase(c)}', (
      tester,
    ) async {
      applyLayoutCase(tester, c, height: 1400);
      await pumpApp(tester, const LoginPage());
      await tester.pumpAndSettle();

      final zh = c.locale.languageCode == 'zh';
      final notice = find.textContaining(zh ? '隱私權政策' : 'Privacy Policy');
      expect(notice, findsOneWidget);
      expect(isTruncated(tester, notice), isFalse);
      expectNoBrokenWords(tester, notice);
      final text = tester.widget<Text>(notice).textSpan!.toPlainText();
      expect(text, contains(zh ? '服務條款' : 'Terms of Service'));
    });
  }
}
