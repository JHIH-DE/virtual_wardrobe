import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/utils/ai_consent.dart';
import 'package:uwearis/features/widgets/common/overlays/ai_consent_dialog.dart';

import '../helpers/fake_auth.dart';
import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

String _jwt(String sub) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'HS256'})}.${seg({'sub': sub})}.signature';
}

void main() {
  setUp(() {
    AiConsent.debugGrantedOverride = null;
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth(accessToken: _jwt('7'));
  });
  tearDown(() => AiConsent.debugGrantedOverride = true);

  /// Pumps a button that runs [ensureAiConsent]; results land in [results].
  /// [calls] concurrent [ensureAiConsent] calls per tap, as a double tap
  /// on an unguarded trigger would make.
  Future<List<bool>> pumpTrigger(WidgetTester tester, {int calls = 1}) async {
    final results = <bool>[];
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.addAll(
            await Future.wait([
              for (var i = 0; i < calls; i++) ensureAiConsent(context),
            ]),
          ),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('declining sends nothing and asks again next time', (
    tester,
  ) async {
    final results = await pumpTrigger(tester);
    expect(find.text('How AI Features Use Your Data'), findsOneWidget);

    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(await AiConsent.isGranted(), isFalse);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('How AI Features Use Your Data'), findsOneWidget);
    await tester.tap(find.text('Not Now'));
    await tester.pumpAndSettle();
    expect(results, [false, false]);
  });

  testWidgets('agreeing is remembered for this user only', (tester) async {
    final results = await pumpTrigger(tester);
    await tester.tap(find.text('Agree and Continue'));
    await tester.pumpAndSettle();
    expect(results, [true]);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('How AI Features Use Your Data'), findsNothing);
    expect(results, [true, true]);

    setUpFakeAuth(accessToken: _jwt('8'));
    expect(await AiConsent.isGranted(), isFalse);
  });

  testWidgets('concurrent calls share one dialog', (tester) async {
    final results = await pumpTrigger(tester, calls: 2);
    expect(find.text('How AI Features Use Your Data'), findsOneWidget);

    await tester.tap(find.text('Agree and Continue'));
    await tester.pumpAndSettle();
    expect(results, [true, true]);
  });

  group('layout', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      testWidgets('disclosure and buttons stay readable · ${describeCase(c)}', (
        tester,
      ) async {
        applyLayoutCase(tester, c);
        await pumpTrigger(tester);

        final zh = c.locale.languageCode == 'zh';
        final body = find.textContaining('Gemini');
        expect(body, findsOneWidget);
        expect(isTruncated(tester, body), isFalse);
        expectNoBrokenWords(tester, body);
        final agree = find.text(zh ? '同意並繼續' : 'Agree and Continue');
        expect(agree.hitTestable(), findsOneWidget);
        await tester.tap(agree);
        await tester.pumpAndSettle();
      });
    }
  });
}
