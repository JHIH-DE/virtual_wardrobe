import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_icon_button.dart';

void main() {
  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  Color iconColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon)).color!;

  testWidgets('enabled: accent colored and taps fire onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(AccentIconButton(icon: Icons.add, onPressed: () => taps++)),
    );

    expect(iconColor(tester), AppColors.accent);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

    await tester.tap(find.byType(AccentIconButton));
    expect(taps, 1);
  });

  testWidgets('disabled: greyed out and taps are ignored', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        AccentIconButton(
          icon: Icons.add,
          enabled: false,
          onPressed: () => taps++,
        ),
      ),
    );

    expect(iconColor(tester), AppColors.hintText);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));

    await tester.tap(find.byType(AccentIconButton));
    expect(taps, 0);
  });
}
