import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment_adjustment.dart';
import 'package:uwearis/app/theme/app_text_styles.dart';
import 'package:uwearis/features/widgets/common/overlays/picker_sheet.dart';
import 'package:uwearis/features/widgets/garment/garment_adjustment_sheet.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

const _definitions = [
  AdjustmentDefinition(
    key: 'shirt_buttons',
    label: '襯衫釦子',
    options: [
      AdjustmentOption(code: 1, label: '全扣'),
      AdjustmentOption(code: 2, label: '部分解扣'),
      AdjustmentOption(code: 3, label: '敞開'),
    ],
  ),
  AdjustmentDefinition(
    key: 'hem',
    label: 'Hem',
    options: [
      AdjustmentOption(code: 1, label: 'Untucked'),
      AdjustmentOption(code: 2, label: 'Tucked into pants'),
      AdjustmentOption(code: 3, label: 'Front tuck'),
    ],
  ),
];

/// A radio row's label (the first when several groups share it).
Finder _row(String label) => find.text(label).first;

/// Selected rows show a bold label.
bool _selected(WidgetTester tester, String label) =>
    tester.widget<Text>(_row(label)).style == AppTextStyle.bold16;

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(_row(label));
  await tester.tap(_row(label));
  await tester.pump();
}

void main() {
  /// Opens the sheet; the returned getter reads what it resolved to.
  Future<Map<String, int>? Function()> open(
    WidgetTester tester, {
    Map<String, int> selected = const {},
    Map<String, String> notes = const {},
  }) async {
    Map<String, int>? result;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await showGarmentAdjustmentSheet(
                  context,
                  definitions: _definitions,
                  selected: selected,
                  notes: notes,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
  }

  testWidgets('a note sits under its own group and leaves picking alone', (
    tester,
  ) async {
    final result = await open(
      tester,
      notes: {'hem': 'Applies once you add a bottom.'},
    );

    final note = find.text('Applies once you add a bottom.');
    expect(note, findsOneWidget);
    expect(
      tester.getTopLeft(note).dy,
      greaterThan(tester.getTopLeft(find.text('Hem')).dy),
    );
    expect(
      tester.getTopLeft(note).dy,
      lessThan(tester.getTopLeft(find.text('Untucked')).dy),
    );

    await _tap(tester, 'Tucked into pants');
    await close(tester);
    expect(result(), {'hem': 2});
  });

  testWidgets('nothing picked: every group starts on Default, in API order', (
    tester,
  ) async {
    final result = await open(tester);

    expect(find.text('襯衫釦子'), findsOneWidget);
    expect(find.text('Hem'), findsOneWidget);
    final lists = find.byWidgetPredicate((w) => w is SingleChoiceList);
    expect(lists, findsNWidgets(2));
    final firstRows = find
        .descendant(of: lists.first, matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data);
    expect(firstRows, ['Default', '全扣', '部分解扣', '敞開']);
    for (final label in ['Default', '全扣', '部分解扣', '敞開']) {
      expect(_selected(tester, label), label == 'Default');
    }

    await close(tester);
    expect(result(), isNull, reason: 'unchanged');
  });

  testWidgets('a pick is single-choice per group and resolves on close', (
    tester,
  ) async {
    final result = await open(tester);

    await _tap(tester, '全扣');
    await _tap(tester, '敞開');
    expect(_selected(tester, '全扣'), isFalse);
    expect(_selected(tester, '敞開'), isTrue);

    await close(tester);
    expect(result(), {'shirt_buttons': 3});
  });

  testWidgets('Default clears the pick instead of sending default_code', (
    tester,
  ) async {
    final result = await open(tester, selected: {'shirt_buttons': 1, 'hem': 2});
    expect(_selected(tester, '全扣'), isTrue);

    await _tap(tester, 'Default');
    await close(tester);

    expect(result(), {'hem': 2});
  });

  group('enlarged text', () {
    setUpAll(loadAppFont);
    for (final c in layoutCases) {
      testWidgets('stays readable at ${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c);
        await open(tester);

        for (final label in ['部分解扣', 'Tucked into pants', 'Front tuck']) {
          expect(isTruncated(tester, find.text(label)), isFalse);
          expectNoBrokenWords(tester, find.text(label));
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
