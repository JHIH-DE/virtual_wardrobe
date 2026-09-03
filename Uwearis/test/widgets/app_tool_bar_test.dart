import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('shows a back button by default, hidden when showBackButton is '
      'false', (tester) async {
    await pumpBar(tester, const AppToolBar(title: 'A'));
    expect(find.byType(IconButton), findsOneWidget);

    await pumpBar(
      tester,
      const AppToolBar(title: 'A', showBackButton: false),
    );
    expect(find.byType(IconButton), findsNothing);
  });
}
