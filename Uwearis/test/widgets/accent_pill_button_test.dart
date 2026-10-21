import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  Color labelColor(WidgetTester tester, String label) =>
      tester.widget<Text>(find.text(label)).style!.color!;

  Color? fillColor(WidgetTester tester) => tester
      .widget<TextButton>(find.byType(TextButton))
      .style!
      .backgroundColor!
      .resolve({});

  testWidgets('enabled: solid accent with a white label; taps fire onPressed', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        AccentPillButton(label: 'Complete with AI', onPressed: () => taps++),
      ),
    );

    expect(find.text('Complete with AI'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(fillColor(tester), AppColors.accent);
    expect(labelColor(tester, 'Complete with AI'), AppColors.textOnPrimary);

    await tester.tap(find.byType(AccentPillButton));
    expect(taps, 1);
  });

  testWidgets('disabled: grey fill and hint label; taps are ignored', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        AccentPillButton(
          label: 'Complete with AI',
          enabled: false,
          onPressed: () => taps++,
        ),
      ),
    );

    expect(fillColor(tester), AppColors.borderSubtle);
    expect(labelColor(tester, 'Complete with AI'), AppColors.hintText);

    await tester.tap(find.byType(AccentPillButton));
    expect(taps, 0);
  });

  testWidgets('disabled with a disabledMessage: explains why above the pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AccentPillButton(
          label: 'Generate Outfit',
          enabled: false,
          disabledMessage: 'Missing a core item',
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Missing a core item'), findsOneWidget);
    expect(
      tester.getBottomLeft(find.text('Missing a core item')).dy,
      lessThan(tester.getTopLeft(find.text('Generate Outfit')).dy),
    );
  });

  testWidgets('enabled: a disabledMessage is not shown', (tester) async {
    await tester.pumpWidget(
      host(
        AccentPillButton(
          label: 'Generate Outfit',
          disabledMessage: 'Missing a core item',
          onPressed: () {},
        ),
      ),
    );

    expect(find.text('Missing a core item'), findsNothing);
  });
}
