import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/overlays/confirm_dialog.dart';

import '../helpers/widget_harness.dart';

void main() {
  /// Opens the dialog from a button; [result] completes with its answer.
  Future<List<bool>> open(
    WidgetTester tester, {
    String title = 'Delete this?',
    String body = "It can't be undone.",
    String confirmLabel = 'Delete',
    bool destructive = false,
  }) async {
    final results = <bool>[];
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => results.add(
            await showConfirmDialog(
              context,
              title: title,
              body: body,
              confirmLabel: confirmLabel,
              destructive: destructive,
            ),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  Color? primaryFill(WidgetTester tester) => tester
      .widget<ElevatedButton>(
        find.descendant(
          of: find.byType(AppDialog),
          matching: find.byType(ElevatedButton),
        ),
      )
      .style!
      .backgroundColor
      ?.resolve({});

  testWidgets('Confirm returns true', (tester) async {
    final results = await open(tester);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('Cancel returns false', (tester) async {
    final results = await open(tester);
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('tapping outside returns false', (tester) async {
    final results = await open(tester);
    await tester.tapAt(const Offset(4, 4)); // the barrier
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(find.byType(AppDialog), findsNothing);
  });

  testWidgets('a system back returns false', (tester) async {
    final results = await open(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(results, [false]);
  });

  testWidgets('shows the given texts, as the AppDialog every confirm used '
      '(a primary, an auto Cancel, no secondary)', (tester) async {
    await open(
      tester,
      title: 'Log out?',
      body: 'You can sign back in anytime.',
      confirmLabel: 'Log Out',
    );

    expect(find.text('Log out?'), findsOneWidget);
    expect(find.text('You can sign back in anytime.'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    final dialog = tester.widget<AppDialog>(find.byType(AppDialog));
    expect(dialog.title, 'Log out?');
    expect(dialog.body, 'You can sign back in anytime.');
    expect(dialog.primaryLabel, 'Log Out');
    expect(dialog.content, isNull);
    expect(dialog.secondaryLabel, isNull);
    expect(dialog.dismiss, AppDialogDismiss.auto);
    expect(dialog.destructive, isFalse);
    expect(find.byKey(AppDialog.dismissButtonKey), findsOneWidget);
  });

  testWidgets('destructive: the error fill, as AppDialog(destructive: true)', (
    tester,
  ) async {
    await open(tester, destructive: true);

    expect(
      tester.widget<AppDialog>(find.byType(AppDialog)).destructive,
      isTrue,
    );
    expect(primaryFill(tester), AppColors.error);
  });

  testWidgets('not destructive: the same fill as a plain AppDialog primary', (
    tester,
  ) async {
    await open(tester);
    final viaHelper = primaryFill(tester);
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await tester.pumpAndSettle();

    await pumpApp(
      tester,
      AppDialog(
        title: 't',
        body: 'b',
        primaryLabel: 'Delete',
        onPrimary: () {},
      ),
    );
    expect(viaHelper, primaryFill(tester));
    expect(viaHelper, isNot(AppColors.error));
  });
}
