import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/explore_nav_bar.dart';
import 'package:uwearis/features/widgets/common/main_nav_bar.dart';
import 'package:uwearis/features/widgets/common/nav_bar_tab.dart';

import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

/// Each tab's tap/highlight area.
List<double> _tabWidths(WidgetTester tester, int count) {
  final tabs = find.byType(NavBarTab);
  expect(tabs, findsNWidgets(count));
  return [
    for (final e in tabs.evaluate())
      tester
          .getSize(
            find.descendant(
              of: find.byWidget(e.widget),
              matching: find.byType(InkWell),
            ),
          )
          .width,
  ];
}

/// At the default text size no label is ever cut.
void _expectWholeLabels(WidgetTester tester) {
  for (final e in find.byType(NavBarTab).evaluate()) {
    if (MediaQuery.textScalerOf(e).scale(1) != 1) return;
    final label = find.descendant(
      of: find.byWidget(e.widget),
      matching: find.byType(Text),
    );
    expect(isTruncated(tester, label), isFalse);
  }
}

/// Whether [p] is inside the stadium (round-ended pill) [bar].
bool _inStadium(Rect bar, Offset p, {double slack = 0.5}) {
  if (!bar.inflate(slack).contains(p)) return false;
  final r = bar.height / 2;
  final cy = bar.center.dy;
  if (p.dx < bar.left + r) {
    return (p - Offset(bar.left + r, cy)).distance <= r + slack;
  }
  if (p.dx > bar.right - r) {
    return (p - Offset(bar.right - r, cy)).distance <= r + slack;
  }
  return true;
}

void _expectInsideStadium(
  WidgetTester tester,
  Rect bar,
  Finder part, {
  double slack = 0.5,
}) {
  for (final e in part.evaluate()) {
    final rect = tester.getRect(find.byWidget(e.widget));
    if (rect.isEmpty) continue;
    for (final corner in [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ]) {
      expect(
        _inStadium(bar, corner, slack: slack),
        isTrue,
        reason: '$rect pokes out of $bar',
      );
    }
  }
}

/// The tap highlight sits the same distance from the bar's top and bottom.
void _expectHighlightCentered(WidgetTester tester) {
  final bar = tester.getRect(find.byType(PhysicalShape));
  for (final e in find.byType(NavBarTab).evaluate()) {
    final ink = tester.getRect(
      find.descendant(
        of: find.byWidget(e.widget),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.top - bar.top, greaterThan(0));
    expect(ink.top - bar.top, closeTo(bar.bottom - ink.bottom, 0.5));
  }
}

/// Icons, labels and the active marker stay clear of the round ends.
void _expectNothingClipped(WidgetTester tester) {
  final bar = tester.getRect(find.byType(PhysicalShape));
  final tabs = find.byType(NavBarTab);
  for (final type in [Icon, Text]) {
    _expectInsideStadium(
      tester,
      bar,
      find.descendant(of: tabs, matching: find.byType(type)),
    );
  }
  // The marker's outer corner may dip ~1px into the curve (it's rounded).
  _expectInsideStadium(
    tester,
    bar,
    find.descendant(of: tabs, matching: find.byType(AnimatedContainer)),
    slack: 1.5,
  );
}

Future<void> _pumpMain(WidgetTester tester, {MainTab current = MainTab.home}) =>
    pumpApp(
      tester,
      Scaffold(
        body: Stack(
          children: [
            MainNavBar(
              current: current,
              onSelect: (_) {},
              onQuickAction: (_) {},
            ),
          ],
        ),
      ),
    );

Future<void> _pumpExplore(
  WidgetTester tester, {
  ExploreTab current = ExploreTab.forYou,
}) => pumpApp(
  tester,
  Scaffold(
    body: Stack(
      children: [ExploreNavBar(current: current, onSelect: (_) {})],
    ),
  ),
);

void main() {
  setUpAll(loadAppFont);

  for (final locale in [const Locale('en'), const Locale('zh', 'TW')]) {
    testWidgets('390pt · 1.0× · $locale: every tab in both bars is the same '
        '${NavBarTabRow.tabWidth}px', (tester) async {
      applyLayoutCase(tester, (width: 390, scale: 1.0, locale: locale));
      await _pumpMain(tester);
      expect(_tabWidths(tester, 4), everyElement(NavBarTabRow.tabWidth));
      await _pumpExplore(tester);
      expect(_tabWidths(tester, 5), everyElement(NavBarTabRow.tabWidth));
    });
  }

  for (final c in layoutCases) {
    testWidgets('${describeCase(c)}: no overflow, and no label cut at the '
        'default text size, and nothing clipped by the round ends', (
      tester,
    ) async {
      applyLayoutCase(tester, c);
      for (final tab in [MainTab.home, MainTab.tripPlanner]) {
        await _pumpMain(tester, current: tab);
        await tester.pumpAndSettle();
        _tabWidths(tester, 4);
        _expectWholeLabels(tester);
        _expectNothingClipped(tester);
        _expectHighlightCentered(tester);
      }
      for (final tab in [ExploreTab.forYou, ExploreTab.account]) {
        await _pumpExplore(tester, current: tab);
        await tester.pumpAndSettle();
        _tabWidths(tester, 5);
        _expectWholeLabels(tester);
        _expectNothingClipped(tester);
        _expectHighlightCentered(tester);
      }
    });
  }
}
