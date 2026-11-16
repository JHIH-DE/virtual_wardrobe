import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/app_text_styles.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';

void main() {
  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  ButtonStyle style(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;

  testWidgets('enabled primary button is accent-colored and taps fire '
      'onPrimary', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        AppDialog(
          title: 'Title',
          body: 'Body',
          primaryLabel: 'Go',
          onPrimary: () => taps++,
        ),
      ),
    );

    expect(style(tester).backgroundColor?.resolve({}), AppColors.accent);

    await tester.tap(find.byType(ElevatedButton));
    expect(taps, 1);
  });

  testWidgets(
    'onPrimary null renders the primary button disabled/greyed and taps '
    'are ignored',
    (tester) async {
      await tester.pumpWidget(
        host(
          const AppDialog(
            title: 'Title',
            body: 'Body',
            primaryLabel: 'Go',
            onPrimary: null,
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
      expect(
        button.style!.backgroundColor?.resolve({WidgetState.disabled}),
        AppColors.borderSubtle,
      );
    },
  );

  Future<Future<bool?>?> open(WidgetTester tester, AppDialog dialog) async {
    Future<bool?>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showDialog<bool>(
              context: context,
              builder: (_) => dialog,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('without a primary, the primary slot is an OK that pops null', (
    tester,
  ) async {
    final result = await open(
      tester,
      const AppDialog(title: 'Title', body: 'Body', secondaryLabel: 'Decline'),
    );

    final label = tester.widget<Text>(find.text('Decline'));
    expect(label.style!.fontSize, AppTextStyle.medium14.fontSize);
    expect(label.style!.color, AppColors.textSecondary);

    expect(
      find.descendant(
        of: find.byKey(AppDialog.dismissButtonKey),
        matching: find.text('OK'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('with a primary only, the secondary slot is a Cancel that pops '
      'null', (tester) async {
    final result = await open(
      tester,
      AppDialog(
        title: 'Title',
        body: 'Body',
        primaryLabel: 'Go',
        onPrimary: () {},
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(AppDialog.dismissButtonKey),
        matching: find.text('Cancel'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await tester.pumpAndSettle();
    expect(find.byType(AppDialog), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('with both buttons set, there is no dismiss button', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppDialog(
          title: 'Title',
          body: 'Body',
          primaryLabel: 'Save',
          onPrimary: () {},
          secondaryLabel: "Don't Save",
          onSecondary: () {},
        ),
      ),
    );
    expect(find.byKey(AppDialog.dismissButtonKey), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('destructive renders the primary with the error fill', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AppDialog(
          title: 'Title',
          body: 'Body',
          primaryLabel: 'Delete',
          onPrimary: () {},
          destructive: true,
        ),
      ),
    );
    expect(style(tester).backgroundColor?.resolve({}), AppColors.error);
  });

  testWidgets('dismiss: cancel adds a Cancel under both buttons, and none in '
      'the primary slot without a primary', (tester) async {
    final result = await open(
      tester,
      AppDialog(
        title: 'Title',
        body: 'Body',
        primaryLabel: 'Save',
        onPrimary: () {},
        secondaryLabel: "Don't Save",
        onSecondary: () {},
        dismiss: AppDialogDismiss.cancel,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(AppDialog.dismissButtonKey)).dy,
      greaterThan(tester.getTopLeft(find.text("Don't Save")).dy),
    );
    await tester.tap(find.byKey(AppDialog.dismissButtonKey));
    await tester.pumpAndSettle();
    expect(await result, isNull);

    await tester.pumpWidget(
      host(
        const AppDialog(
          title: 'Title',
          content: SizedBox(),
          dismiss: AppDialogDismiss.cancel,
        ),
      ),
    );
    expect(find.byType(ElevatedButton), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(AppDialog.dismissButtonKey),
        matching: find.text('Cancel'),
      ),
      findsOneWidget,
    );
  });
}
