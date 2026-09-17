import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/overlays/text_input_dialog.dart';

import '../helpers/widget_harness.dart';

void main() {
  // Every test below opens the dialog against 'Kyoto Trip' as the initial
  // value and stashes the eventual result in [resultFuture] — the caller
  // resolves it after interacting, exactly like each real call site does.
  late Future<String?> resultFuture;

  Future<void> pumpAndOpen(WidgetTester tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              resultFuture = showTextInputDialog(
                context,
                title: 'Rename',
                hint: 'Name',
                initialValue: 'Kyoto Trip',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  ElevatedButton saveButton(WidgetTester tester) =>
      tester.widgetList<ElevatedButton>(find.byType(ElevatedButton)).last;

  testWidgets('Save starts disabled when the field is unchanged', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets(
    'typing a different value enables Save, which returns the trimmed text',
    (tester) async {
      await pumpAndOpen(tester);

      await tester.enterText(find.byType(TextField), '  Osaka Trip  ');
      await tester.pump();
      expect(saveButton(tester).onPressed, isNotNull);

      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pumpAndSettle();

      expect(await resultFuture, 'Osaka Trip');
    },
  );

  testWidgets('clearing the field back to whitespace disables Save again', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    await tester.enterText(find.byType(TextField), 'Osaka Trip');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(saveButton(tester).onPressed, isNull);
  });

  testWidgets('Cancel returns null regardless of the field value', (
    tester,
  ) async {
    await pumpAndOpen(tester);

    await tester.enterText(find.byType(TextField), 'Osaka Trip');
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await resultFuture, isNull);
  });
}
