import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/overlays/empty_state_placeholder.dart';

void main() {
  // The default flutter_test surface is 800x600 — smaller than the 800px
  // SizedBox heights these tests use, which would otherwise get silently
  // clamped down and throw the expected-center math off.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget host({
    required double height,
    required double bottomInset,
    Widget? pinnedTop,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: height,
          child: EmptyStatePlaceholder(
            message: 'Nothing here',
            fillAvailableSpace: true,
            bottomInset: bottomInset,
            pinnedTop: pinnedTop,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'fillAvailableSpace centers across the whole given height when there is '
    'no bottomInset or pinnedTop',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(host(height: 800, bottomInset: 0));
      await tester.pump();

      final center = tester.getCenter(find.text('Nothing here'));
      expect(center.dy, closeTo(400, 1));
    },
  );

  testWidgets(
    'bottomInset excludes that much space from the bottom of the centering '
    'area (e.g. a floating MainNavBar the Scaffold.body does not shrink for)',
    (tester) async {
      useTallSurface(tester);
      const height = 800.0;
      const inset = 200.0;
      await tester.pumpWidget(host(height: height, bottomInset: inset));
      await tester.pump();

      final center = tester.getCenter(find.text('Nothing here'));
      // Centered within (0, height - inset), not (0, height).
      expect(center.dy, closeTo((height - inset) / 2, 1));
    },
  );

  testWidgets(
    'pinnedTop growing/shrinking never moves the centered content below it',
    (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        host(
          height: 800,
          bottomInset: 0,
          pinnedTop: const SizedBox(height: 40),
        ),
      );
      await tester.pump();
      final collapsedCenter = tester.getCenter(find.text('Nothing here'));

      await tester.pumpWidget(
        host(
          height: 800,
          bottomInset: 0,
          pinnedTop: const SizedBox(height: 300),
        ),
      );
      await tester.pump();
      final expandedCenter = tester.getCenter(find.text('Nothing here'));

      expect(expandedCenter, collapsedCenter);
    },
  );

  testWidgets(
    'pinnedTop and bottomInset combine correctly (top pin ignores '
    'bottomInset, centered content excludes both)',
    (tester) async {
      useTallSurface(tester);
      const height = 800.0;
      const inset = 100.0;
      await tester.pumpWidget(
        host(
          height: height,
          bottomInset: inset,
          pinnedTop: const SizedBox(key: ValueKey('pinned'), height: 40),
        ),
      );
      await tester.pump();

      final center = tester.getCenter(find.text('Nothing here'));
      expect(center.dy, closeTo((height - inset) / 2, 1));

      final pinnedTopWidget = tester.getTopLeft(
        find.byKey(const ValueKey('pinned')),
      );
      expect(pinnedTopWidget.dy, closeTo(0, 1));
    },
  );
}
