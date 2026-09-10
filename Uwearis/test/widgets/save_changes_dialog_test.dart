import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/overlays/save_changes_dialog.dart';

import '../helpers/widget_harness.dart';

void main() {
  /// Opens the dialog and returns the still-pending choice future.
  Future<Future<SaveChangesChoice>> open(WidgetTester tester) async {
    Future<SaveChangesChoice>? choice;
    await pumpApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => choice = showSaveChangesDialog(
                context,
                title: 'Unsaved changes',
                body: 'Leave without saving?',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return choice!;
  }

  testWidgets('renders the title/body and the three actions', (tester) async {
    await open(tester);
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(find.text('Leave without saving?'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text("Don't Save"), findsOneWidget);
  });

  for (final (label, expected) in const [
    ('Save', SaveChangesChoice.save),
    ('Cancel', SaveChangesChoice.cancel),
    ("Don't Save", SaveChangesChoice.discard),
  ]) {
    testWidgets('$label returns $expected', (tester) async {
      final future = await open(tester);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(await future, expected);
    });
  }

  testWidgets('dismissing (barrier tap) counts as cancel', (tester) async {
    final future = await open(tester);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(await future, SaveChangesChoice.cancel);
  });
}
