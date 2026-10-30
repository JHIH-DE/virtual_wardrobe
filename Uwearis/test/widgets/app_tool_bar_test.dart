import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/app_tool_bar.dart';
import 'package:uwearis/features/widgets/common/cards/count_pill.dart';

import '../helpers/widget_harness.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, AppToolBar bar) {
    return pumpApp(tester, Scaffold(appBar: bar, body: const SizedBox()));
  }

  testWidgets('renders the plain title', (tester) async {
    await pumpBar(tester, const AppToolBar(title: 'My Closet'));
    expect(find.text('My Closet'), findsOneWidget);
    expect(find.byType(CountPill), findsNothing);
  });

  testWidgets('titleCount renders a CountPill next to the title', (
    tester,
  ) async {
    await pumpBar(tester, const AppToolBar(title: 'Outfits', titleCount: 7));
    expect(find.text('Outfits'), findsOneWidget);
    expect(find.byType(CountPill), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('an explicit titleWidget wins over titleCount', (tester) async {
    await pumpBar(
      tester,
      const AppToolBar(
        title: 'ignored',
        titleCount: 3,
        titleWidget: Text('custom'),
      ),
    );
    expect(find.text('custom'), findsOneWidget);
    expect(find.byType(CountPill), findsNothing);
  });

  testWidgets('showTitle: false hides the title but still announces it', (
    tester,
  ) async {
    await pumpBar(
      tester,
      const AppToolBar(title: 'Outfit Details', showTitle: false),
    );
    expect(find.text('Outfit Details'), findsNothing);
    expect(find.bySemanticsLabel('Outfit Details'), findsOneWidget);
    expect(find.byType(ActionDiscButton), findsOneWidget);
  });

  testWidgets('shows a back button by default, hidden when showBackButton is '
      'false', (tester) async {
    await pumpBar(tester, const AppToolBar(title: 'A'));
    expect(find.byType(ActionDiscButton), findsOneWidget);

    await pumpBar(tester, const AppToolBar(title: 'A', showBackButton: false));
    expect(find.byType(ActionDiscButton), findsNothing);
  });

  testWidgets('pushing between two pages with back buttons keeps the back '
      'button still while the new page slides in', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          appBar: const AppToolBar(title: 'First'),
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  appBar: AppToolBar(title: 'Second'),
                  body: SizedBox(),
                ),
              ),
            ),
            child: const Text('next'),
          ),
        ),
      ),
    );
    final back = find.byIcon(Icons.arrow_back_ios_new_rounded);
    final restingCenter = tester.getCenter(back);

    await tester.tap(find.text('next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    // Mid-transition: the new page's title is still sliding in…
    final secondTitle = tester.getCenter(find.text('Second')).dx;
    // …but every on-screen back button is exactly where it rests.
    expect(back, findsWidgets);
    for (final e in back.evaluate()) {
      expect(tester.getCenter(find.byWidget(e.widget)), restingCenter);
    }

    await tester.pumpAndSettle();
    expect(tester.getCenter(find.text('Second')).dx, lessThan(secondTitle));
    expect(tester.getCenter(back), restingCenter);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
