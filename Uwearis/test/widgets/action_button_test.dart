import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/common/buttons/action_button.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );

  ButtonStyle styleOf(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).style!;

  testWidgets(
    'secondary: pale accent fill with an accent label, and taps fire',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          ActionButton(
            label: 'View Closet Match',
            variant: ActionButtonVariant.secondary,
            onPressed: () => taps++,
          ),
        ),
      );

      final style = styleOf(tester);
      expect(style.backgroundColor!.resolve({}), AppColors.accentTint);
      expect(style.foregroundColor!.resolve({}), AppColors.accent);

      await tester.tap(find.text('View Closet Match'));
      expect(taps, 1);
    },
  );

  testWidgets('secondary: pressed deepens the tint, disabled is far paler with '
      'a dimmed label, and no state adds elevation', (tester) async {
    await tester.pumpWidget(
      host(
        ActionButton(
          label: 'View Closet Match',
          variant: ActionButtonVariant.secondary,
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
    expect(
      tester.widget<Text>(find.text('View Closet Match')).style!.color,
      AppColors.accent,
    );

    await tester.pumpWidget(
      host(
        const ActionButton(
          label: 'View Closet Match',
          variant: ActionButtonVariant.secondary,
        ),
      ),
    );
    style = styleOf(tester);
    expect(
      tester.widget<Text>(find.text('View Closet Match')).style!.color,
      AppColors.accent.withValues(alpha: 0.38),
    );
  });

  testWidgets('primary is the default: accent fill with a white label', (
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
    final secondary = await sizeOf(
      ActionButton(
        label: 'Save',
        variant: ActionButtonVariant.secondary,
        onPressed: () {},
      ),
    );

    expect(bottom.height, AppDimens.actionButtonHeight);
    expect(secondary, bottom);
  });

  testWidgets('primary looks exactly like BottomActionButton\'s button — '
      'same fill, label, border, shape and elevation in every state', (
    tester,
  ) async {
    Future<ButtonStyle> render(Widget button) async {
      await tester.pumpWidget(host(button));
      return styleOf(tester);
    }

    final bottom = await render(
      BottomActionButton(
        label: 'Save',
        onPressed: () {},
        panelPadding: EdgeInsets.zero,
      ),
    );
    final inPage = await render(ActionButton(label: 'Save', onPressed: () {}));

    for (final states in [
      <WidgetState>{},
      {WidgetState.pressed},
      {WidgetState.hovered},
    ]) {
      expect(
        inPage.backgroundColor!.resolve(states),
        bottom.backgroundColor!.resolve(states),
      );
      expect(
        inPage.foregroundColor!.resolve(states),
        bottom.foregroundColor!.resolve(states),
      );
      expect(
        inPage.overlayColor!.resolve(states),
        bottom.overlayColor!.resolve(states),
      );
      expect(inPage.side!.resolve(states), bottom.side!.resolve(states));
      expect(inPage.shape!.resolve(states), bottom.shape!.resolve(states));
      expect(
        inPage.elevation!.resolve(states),
        bottom.elevation!.resolve(states),
      );
    }
  });

  testWidgets('primary disabled: AppDialog\'s disabled colors, no border', (
    tester,
  ) async {
    await tester.pumpWidget(host(const ActionButton(label: 'Save')));

    final style = styleOf(tester);
    final disabled = {WidgetState.disabled};
    expect(style.backgroundColor!.resolve(disabled), AppColors.borderSubtle);
    expect(style.side!.resolve(disabled), BorderSide.none);
    expect(
      tester.widget<Text>(find.text('Save')).style!.color,
      AppColors.hintText,
    );
  });

  testWidgets('a label too long for its slot wraps and grows the button '
      'instead of truncating', (tester) async {
    const label = 'Add every missing item to the suitcase';
    await tester.pumpWidget(
      host(
        SizedBox(
          width: 160,
          child: ActionButton(
            label: label,
            leading: const Icon(Icons.check),
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(isTruncated(tester, find.text(label)), isFalse);
    expect(renderedLineCount(tester, find.text(label)), greaterThan(1));
    expectWithin(tester, find.text(label), find.byType(ElevatedButton));
    expect(
      tester.getSize(find.byType(ElevatedButton)).height,
      greaterThan(AppDimens.actionButtonHeight),
    );
  });

  group('enlarged text', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      testWidgets('a full-width button keeps its whole label inside with '
          'breathing room at ${describeCase(c)}', (tester) async {
        applyLayoutCase(tester, c);
        late String label;
        await pumpApp(
          tester,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Builder(
                builder: (context) {
                  label = AppLocalizations.of(context).createOutfit;
                  return ActionButton(
                    label: label,
                    leading: const Icon(Icons.auto_awesome),
                    onPressed: () {},
                  );
                },
              ),
            ),
          ),
        );

        final text = find.text(label);
        expect(isTruncated(tester, text), isFalse);
        expectWithin(tester, text, find.byType(ElevatedButton));
        // Not just inside: the label keeps visible breathing room instead of
        // touching the pill's top and bottom edges.
        final textRect = tester.getRect(text);
        final buttonRect = tester.getRect(find.byType(ElevatedButton));
        expect(textRect.top - buttonRect.top, greaterThanOrEqualTo(8));
        expect(buttonRect.bottom - textRect.bottom, greaterThanOrEqualTo(8));
        expect(
          buttonRect.height,
          greaterThanOrEqualTo(AppDimens.actionButtonHeight),
        );
      });
    }
  });
}
