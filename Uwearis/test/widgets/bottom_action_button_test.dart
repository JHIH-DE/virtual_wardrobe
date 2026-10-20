import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  testWidgets('flipping hidden → visible → hidden before the 200ms switch '
      'finishes does not collide the two outgoing "hidden" children', (
    tester,
  ) async {
    final enabled = ValueNotifier(false);
    addTearDown(enabled.dispose);
    await pumpApp(
      tester,
      Scaffold(
        bottomNavigationBar: ValueListenableBuilder<bool>(
          valueListenable: enabled,
          builder: (_, isEnabled, _) => BottomActionButton(
            label: 'Confirm',
            enabled: isEnabled,
            onPressed: () {},
          ),
        ),
      ),
    );

    enabled.value = true;
    await tester.pump(const Duration(milliseconds: 50));
    enabled.value = false;
    await tester.pump(const Duration(milliseconds: 50));
    enabled.value = true;
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('bottomActionButton-visible')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('bottomActionButton-hidden')),
      findsNothing,
    );
  });

  group('scrollClearance', () {
    setUpAll(loadAppFont);

    const longLabel = 'Add every unpacked garment to the suitcase';
    const longLabelZh = '把所有尚未打包的衣物加入行李箱';

    Future<double> pumpListPage(WidgetTester tester, String label) async {
      late double clearance;
      await pumpApp(
        tester,
        Scaffold(
          extendBody: true,
          bottomNavigationBar: BottomActionButton(
            label: label,
            leading: const Icon(Icons.luggage_outlined),
            onPressed: () {},
          ),
          body: Builder(
            builder: (bodyContext) {
              clearance = BottomActionButton.scrollClearance(bodyContext);
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, clearance),
                children: [
                  for (var i = 0; i < 30; i++)
                    SizedBox(height: 60, child: Text('Row $i')),
                  const SizedBox(height: 60, child: Text('LAST ROW')),
                ],
              );
            },
          ),
        ),
      );
      return clearance;
    }

    for (final c in layoutCases.where((c) => c.scale != 1.3)) {
      testWidgets('tracks the real bar height and lets the last row scroll '
          'fully above a long, wrapping label at ${describeCase(c)}', (
        tester,
      ) async {
        applyLayoutCase(tester, c);
        tester.view.padding = const FakeViewPadding(bottom: 34 * 3);
        final label = c.locale.languageCode == 'zh' ? longLabelZh : longLabel;
        final clearance = await pumpListPage(tester, label);

        final bar = tester.getRect(find.byType(BottomActionButton));
        // The bar is the button (however many lines) plus the 34pt inset.
        expect(clearance, closeTo(math.max(85, bar.height + 8), 0.5));
        if (c.scale == 2.0) {
          expect(renderedLineCount(tester, find.text(label)), greaterThan(1));
        }

        await tester.drag(find.byType(ListView), const Offset(0, -10000));
        await tester.pumpAndSettle();
        final last = tester.getRect(find.text('LAST ROW'));
        final button = tester.getRect(find.byType(ElevatedButton));
        expect(last.bottom, lessThanOrEqualTo(button.top));
      });
    }

    testWidgets('never less than the existing fixed clearance', (tester) async {
      applyLayoutCase(tester, layoutCases.first);
      expect(
        await pumpListPage(tester, 'Save'),
        AppDimens.bottomActionBtnClearance,
      );
    });

    testWidgets('asserts when given a context outside the Scaffold body', (
      tester,
    ) async {
      late BuildContext pageContext;
      await pumpApp(
        tester,
        Builder(
          builder: (context) {
            pageContext = context;
            return const Scaffold();
          },
        ),
      );
      expect(
        () => BottomActionButton.scrollClearance(pageContext),
        throwsAssertionError,
      );
    });
  });
}
