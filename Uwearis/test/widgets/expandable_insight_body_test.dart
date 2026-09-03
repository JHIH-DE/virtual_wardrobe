import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/expand_arrow_icon.dart';
import 'package:uwearis/features/widgets/common/expandable_insight_body.dart';

import '../helpers/widget_harness.dart';

void main() {
  Widget body({
    bool expanded = false,
    bool showToggle = true,
    VoidCallback? onToggle,
  }) {
    return ExpandableInsightBody(
      title: const Text('The Title'),
      detail: 'The detail paragraph.',
      expanded: expanded,
      showToggle: showToggle,
      onToggle: onToggle ?? () {},
    );
  }

  testWidgets('always shows the title', (tester) async {
    await pumpApp(tester, Scaffold(body: body()));
    expect(find.text('The Title'), findsOneWidget);
  });

  testWidgets('the detail paragraph is present in the tree regardless of '
      'expanded (AnimatedCrossFade keeps both children)', (tester) async {
    await pumpApp(tester, Scaffold(body: body(expanded: true)));
    expect(find.text('The detail paragraph.'), findsOneWidget);
  });

  testWidgets('tapping toggles', (tester) async {
    var toggles = 0;
    await pumpApp(
      tester,
      Scaffold(body: body(onToggle: () => toggles++)),
    );
    await tester.tap(find.byType(ExpandableInsightBody));
    expect(toggles, 1);
  });

  testWidgets('showToggle:false hides the arrow and disables the tap', (
    tester,
  ) async {
    var toggles = 0;
    await pumpApp(
      tester,
      Scaffold(body: body(showToggle: false, onToggle: () => toggles++)),
    );
    expect(find.byType(ExpandArrowIcon), findsNothing);
    await tester.tap(find.byType(ExpandableInsightBody));
    expect(toggles, 0);
  });

  testWidgets('showToggle:true shows the arrow', (tester) async {
    await pumpApp(tester, Scaffold(body: body(showToggle: true)));
    expect(find.byType(ExpandArrowIcon), findsOneWidget);
  });
}
