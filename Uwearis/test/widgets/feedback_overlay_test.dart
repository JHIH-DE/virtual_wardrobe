import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/overlays/dialog_glass_panel.dart';
import 'package:uwearis/features/widgets/common/overlays/feedback_overlay.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets('a back that already closed the overlay leaves the page under '
      'it alone when the timer ends', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (pageContext) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        showFeedbackOverlay(pageContext, message: 'Saved'),
                    child: const Text('show'),
                  ),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsOneWidget);

    // A system back closes the overlay before its 2s are up.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('show'), findsOneWidget);
  });

  testWidgets('the overlay closes itself after its duration', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showFeedbackOverlay(context, message: 'Saved'),
            child: const Text('show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
    expect(find.text('show'), findsOneWidget);
  });

  for (final (scale, label) in [
    (1.0, 'stays 130 tall'),
    (2.0, 'grows with large text but never fills the screen'),
  ]) {
    testWidgets('the panel $label (text ×$scale)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showFeedbackOverlay(context, message: 'Saved'),
              child: const Text('show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final height = tester.getSize(find.byType(DialogGlassPanel)).height;
      final screen =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      if (scale == 1.0) {
        expect(height, 130);
      } else {
        expect(height, greaterThan(130));
        expect(height, lessThan(screen / 2));
      }
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  }
}
