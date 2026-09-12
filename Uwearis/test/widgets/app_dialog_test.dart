import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
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

    expect(
      style(tester).backgroundColor?.resolve({}),
      AppColors.accent,
    );

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

      // A disabled ElevatedButton simply has no onPressed — tapping it is a
      // no-op at the framework level, nothing further to assert here beyond
      // onPressed being null (already checked above).
    },
  );
}
