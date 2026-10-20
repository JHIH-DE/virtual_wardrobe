import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Auto-Complete card starts collapsed; this reveals its temperature
/// and style tiles.
Future<void> expandFinishOutfit(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
  await tester.pump();
}
