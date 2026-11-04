import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/explore_shell.dart';
import 'package:uwearis/features/pages/explore/bag_page.dart';
import 'package:uwearis/features/pages/explore/explore_home_page.dart';
import 'package:uwearis/features/pages/explore/inbox_page.dart';
import 'package:uwearis/features/pages/explore/saved_page.dart';
import 'package:uwearis/features/pages/explore/search_page.dart';
import 'package:uwearis/features/widgets/common/app_tool_bar.dart';
import 'package:uwearis/features/widgets/common/explore_nav_bar.dart';

import '../../helpers/widget_harness.dart';

Future<void> _pumpShell(WidgetTester tester) async {
  await pumpApp(tester, const ExploreShell());
  await tester.pump();
}

Future<void> _tapTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(ExploreNavBar), matching: find.text(label)),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('opens on the Explore page and switches tabs from the nav bar', (
    tester,
  ) async {
    await _pumpShell(tester);
    expect(find.byType(ExploreHomePage), findsOneWidget);

    for (final (label, type) in [
      ('Search', SearchPage),
      ('Bag', BagPage),
      ('Saved', SavedPage),
      ('Inbox', InboxPage),
      ('Home', ExploreHomePage),
    ]) {
      await _tapTab(tester, label);
      expect(find.byType(type), findsOneWidget, reason: label);
    }
  });

  testWidgets('Bag, Saved and Inbox carry a title bar named after the tab', (
    tester,
  ) async {
    await _pumpShell(tester);

    for (final (label, type) in [
      ('Bag', BagPage),
      ('Saved', SavedPage),
      ('Inbox', InboxPage),
    ]) {
      await _tapTab(tester, label);
      final bar = tester.widget<AppToolBar>(
        find.descendant(
          of: find.byType(type),
          matching: find.byType(AppToolBar),
        ),
      );
      expect(bar.title, label);
      expect(bar.centerTitle, isFalse);
      expect(bar.showBackButton, isFalse);
    }
  });

  testWidgets('a tab keeps its state across tab switches', (tester) async {
    await _pumpShell(tester);

    await _tapTab(tester, 'Search');
    await tester.enterText(find.byType(TextField), 'denim');
    await _tapTab(tester, 'Bag');
    await _tapTab(tester, 'Search');

    expect(find.text('denim'), findsOneWidget);
  });

  testWidgets('swiping cycles through the tabs', (tester) async {
    await _pumpShell(tester);

    await tester.fling(
      find.byType(ExploreHomePage),
      const Offset(-300, 0),
      1000,
    );
    await tester.pump();
    expect(find.byType(SearchPage), findsOneWidget);

    await tester.fling(find.byType(SearchPage), const Offset(300, 0), 1000);
    await tester.pump();
    await tester.fling(
      find.byType(ExploreHomePage),
      const Offset(300, 0),
      1000,
    );
    await tester.pump();
    expect(find.byType(InboxPage), findsOneWidget);
  });
}
