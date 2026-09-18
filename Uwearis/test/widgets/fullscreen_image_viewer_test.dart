import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/images/fullscreen_image_viewer.dart';
import 'package:uwearis/features/widgets/common/images/refreshable_network_image.dart';

void main() {
  bool isBlackScaffold(Widget w) =>
      w is Scaffold && w.backgroundColor == Colors.black;

  // Not pumpAndSettle anywhere in this file — CachedNetworkImage's
  // placeholder spinner animates indefinitely while the (blocked-in-tests)
  // network fetch never resolves, so pumpAndSettle would time out waiting
  // for it to stop. Two plain pumps (one to start the push/pop transition,
  // one past its 200ms duration, with a little slack so the route's own
  // post-animation teardown — which lands a frame after the animation
  // controller itself reports complete — has also run) settles it instead.
  Future<void> pumpTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }

  testWidgets(
    'shows the image full-screen over a black backdrop, height-matched '
    'via BoxFit.cover',
    (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const Scaffold(body: SizedBox());
            },
          ),
        ),
      );

      showFullscreenImage(
        capturedContext,
        imageUrl: 'https://example.com/outfit.jpg',
        cacheKey: 'outfit-1',
      );
      await pumpTransition(tester);

      expect(find.byWidgetPredicate(isBlackScaffold), findsOneWidget);
      final image = tester.widget<RefreshableNetworkImage>(
        find.byType(RefreshableNetworkImage),
      );
      expect(image.imageUrl, 'https://example.com/outfit.jpg');
      expect(image.cacheKey, 'outfit-1');
      expect(image.fit, BoxFit.cover);

      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      expect(viewer.minScale, 1);
      expect(viewer.maxScale, 4);
    },
  );

  testWidgets('tapping anywhere on the full-screen view closes it', (
    tester,
  ) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            capturedContext = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );

    showFullscreenImage(
      capturedContext,
      imageUrl: 'https://example.com/outfit.jpg',
    );
    await pumpTransition(tester);
    expect(find.byWidgetPredicate(isBlackScaffold), findsOneWidget);

    await tester.tapAt(const Offset(50, 50));
    await pumpTransition(tester);

    expect(find.byWidgetPredicate(isBlackScaffold), findsNothing);
  });
}
