import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/common/buttons/action_button.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );

  ButtonStyle styleOf(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;

  testWidgets('tinted: pale accent fill with an accent label, and taps fire', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        ActionButton(
          label: 'View Closet Match',
          variant: ActionButtonVariant.tinted,
          onPressed: () => taps++,
        ),
      ),
    );

    final style = styleOf(tester);
    expect(style.backgroundColor!.resolve({}), AppColors.accentTint);
    expect(style.foregroundColor!.resolve({}), AppColors.accent);

    await tester.tap(find.text('View Closet Match'));
    expect(taps, 1);
  });

  testWidgets('tinted: pressed deepens the tint, disabled is far paler with '
      'a dimmed label, and no state adds elevation', (tester) async {
    await tester.pumpWidget(
      host(
        ActionButton(
          label: 'View Closet Match',
          variant: ActionButtonVariant.tinted,
          onPressed: () {},
        ),
      ),
    );
    var style = styleOf(tester);
    Color? bg(Set<WidgetState> states) =>
        style.backgroundColor!.resolve(states);

    expect(bg({}), AppColors.accentTint);
    expect(bg({WidgetState.pressed}), AppColors.accent.withValues(alpha: 0.20));
    expect(
      bg({WidgetState.disabled}),
      AppColors.accent.withValues(alpha: 0.06),
    );
    expect(
      style.overlayColor!.resolve({WidgetState.pressed}),
      Colors.transparent,
    );
    for (final states in [
      <WidgetState>{},
      {WidgetState.pressed},
      {WidgetState.disabled},
    ]) {
      expect(style.elevation!.resolve(states), 0);
    }
    // Enabled label is the full accent.
    expect(
      tester.widget<Text>(find.text('View Closet Match')).style!.color,
      AppColors.accent,
    );

    await tester.pumpWidget(
      host(
        const ActionButton(
          label: 'View Closet Match',
          variant: ActionButtonVariant.tinted,
        ),
      ),
    );
    style = styleOf(tester);
    expect(
      tester.widget<Text>(find.text('View Closet Match')).style!.color,
      AppColors.accent.withValues(alpha: 0.38),
    );
  });

  testWidgets('solid is the default: accent fill with a white label', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(ActionButton(label: 'Save', onPressed: () {})),
    );

    final style = styleOf(tester);
    expect(style.backgroundColor!.resolve({}), AppColors.accent);
    expect(style.foregroundColor!.resolve({}), AppColors.textOnPrimary);
  });

  testWidgets('every variant is exactly as big as BottomActionButton\'s '
      'button', (tester) async {
    Future<Size> sizeOf(Widget button) async {
      await tester.pumpWidget(host(button));
      return tester.getSize(find.byType(ElevatedButton));
    }

    final bottom = await sizeOf(
      BottomActionButton(
        label: 'Save',
        onPressed: () {},
        panelPadding: EdgeInsets.zero,
      ),
    );
    final tinted = await sizeOf(
      ActionButton(
        label: 'Save',
        variant: ActionButtonVariant.tinted,
        onPressed: () {},
      ),
    );

    expect(bottom.height, AppDimens.actionButtonHeight);
    expect(tinted, bottom);
  });
}
