import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/common/buttons/circle_icon_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  Color iconColor(WidgetTester tester) =>
      tester.widget<Icon>(find.byType(Icon)).color!;

  testWidgets('enabled: black glyph and taps fire onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(CircleIconButton(icon: Icons.add, onPressed: () => taps++)),
    );

    expect(iconColor(tester), AppColors.icon);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

    await tester.tap(find.byType(CircleIconButton));
    expect(taps, 1);
  });

  testWidgets('disabled: greyed out and taps are ignored', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        CircleIconButton(
          icon: Icons.add,
          enabled: false,
          onPressed: () => taps++,
        ),
      ),
    );

    expect(iconColor(tester), AppColors.hintText);
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));

    await tester.tap(find.byType(CircleIconButton));
    expect(taps, 0);
  });

  testWidgets('the glass disc fades from a light centre to a darker edge, so '
      'it reads on both the cream page and a white card', (tester) async {
    await tester.pumpWidget(
      host(CircleIconButton(icon: Icons.add, onPressed: () {})),
    );

    final gradients = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(CircleIconButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((b) => (b.decoration as BoxDecoration).gradient)
        .whereType<RadialGradient>();
    final colors = gradients.single.colors;
    expect(colors.first, AppColors.iconButtonFillCenter);
    expect(colors.last, AppColors.iconButtonFillEdge);
  });

  testWidgets('tooltip wraps the button and labels it', (tester) async {
    await tester.pumpWidget(
      host(CircleIconButton(icon: Icons.add, tooltip: 'Replan')),
    );

    expect(find.byTooltip('Replan'), findsOneWidget);
  });

  testWidgets('discAlignment centerRight puts the disc flush with the tap '
      "box's right edge, keeping the full 44px tap target", (tester) async {
    await tester.pumpWidget(
      host(
        CircleIconButton(
          icon: Icons.add,
          discAlignment: Alignment.centerRight,
          onPressed: () {},
        ),
      ),
    );

    final box = tester.getRect(find.byType(CircleIconButton));
    final disc = tester.getRect(
      find
          .descendant(
            of: find.byType(CircleIconButton),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(box.width, AppDimens.minTouchTarget);
    expect(disc.right, box.right);
    expect(disc.width, 32);
  });
}
