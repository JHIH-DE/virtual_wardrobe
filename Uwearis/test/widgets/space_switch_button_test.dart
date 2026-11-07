import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/space_switch_button.dart';

void main() {
  Future<void> pump(WidgetTester tester, Future<void> Function() onPressed) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SpaceSwitchButton(label: 'Explore', onPressed: onPressed),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the first letter, expands, then fires', (tester) async {
    var calls = 0;
    await pump(tester, () async => calls++);
    expect(find.text('E'), findsOneWidget);
    expect(find.text('Explore'), findsNothing);

    await tester.tap(find.byType(SpaceSwitchButton));
    await tester.pump();
    expect(find.text('Explore'), findsOneWidget);
    expect(calls, 0);

    await tester.pumpAndSettle(const Duration(milliseconds: 400));
    expect(calls, 1);
    expect(find.text('E'), findsOneWidget);
  });

  testWidgets('stays expanded and ignores taps until onPressed completes', (
    tester,
  ) async {
    var calls = 0;
    final route = Completer<void>();
    await pump(tester, () {
      calls++;
      return route.future;
    });
    await tester.tap(find.byType(SpaceSwitchButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);

    await tester.tap(find.byType(SpaceSwitchButton));
    await tester.pump(const Duration(milliseconds: 400));
    expect(calls, 1);
    expect(find.text('Explore'), findsOneWidget);

    route.complete();
    await tester.pumpAndSettle();
    expect(find.text('E'), findsOneWidget);
  });
}
