import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/camera_capture_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';

import '../helpers/widget_harness.dart';

void main() {
  // No camera plugin under test, so this is the "no camera" path.
  testWidgets('with no usable camera it says so and offers Retry, instead '
      'of an endless spinner', (tester) async {
    // The plugin call fails on a real async gap, outside fake time.
    Future<void> settlePlatformCall() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    await pumpApp(tester, const CameraCapturePage());
    await settlePlatformCall();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Couldn't open the camera"), findsOneWidget);
    expect(find.widgetWithText(AccentPillButton, 'Retry'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    await tester.tap(find.widgetWithText(AccentPillButton, 'Retry'));
    await tester.pump();
    await settlePlatformCall();
    expect(find.text("Couldn't open the camera"), findsOneWidget);
  });
}
