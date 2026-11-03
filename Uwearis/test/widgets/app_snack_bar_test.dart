import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/buttons/bottom_action_button.dart';
import 'package:uwearis/features/widgets/common/overlays/app_snack_bar.dart';

import '../helpers/widget_harness.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester) => pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showAppSnackBar(context, 'Added to this trip'),
            child: const Text('show'),
          ),
        ),
        bottomNavigationBar: BottomActionButton(
          label: 'Find More Outfits',
          onPressed: () {},
        ),
      ),
    ),
  );

  Future<void> show(WidgetTester tester) async {
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('sits at the very bottom, over the bottom action button, with '
      'centred text', (tester) async {
    await pumpPage(tester);
    await show(tester);

    final screen = tester.getRect(find.byType(Scaffold));
    final message = find.text('Added to this trip');
    final bar = tester.getRect(
      find.ancestor(of: message, matching: find.byType(Material)).first,
    );
    final button = tester.getRect(find.byType(BottomActionButton));
    expect(bar.bottom, screen.bottom);
    expect(bar.width, screen.width);
    expect(bar.overlaps(button), isTrue);
    expect(tester.widget<Text>(message).textAlign, TextAlign.center);
    expect(
      tester.getCenter(message).dx,
      moreOrLessEquals(screen.center.dx, epsilon: 1),
    );
  });

  testWidgets('goes away by itself after 4 seconds, or when tapped', (
    tester,
  ) async {
    await pumpPage(tester);
    await show(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Added to this trip'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Added to this trip'), findsNothing);

    await show(tester);
    await tester.tap(find.text('Added to this trip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Added to this trip'), findsNothing);
  });

  testWidgets('a new message replaces the one showing', (tester) async {
    late BuildContext pageContext;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          pageContext = context;
          return const Scaffold();
        },
      ),
    );
    showAppSnackBar(pageContext, 'first');
    await tester.pump(const Duration(milliseconds: 300));
    showAppSnackBar(pageContext, 'second');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('stays up across a route change (shown from a captured '
      'overlay)', (tester) async {
    late BuildContext pageContext;
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          pageContext = context;
          return const Scaffold(body: Text('first page'));
        },
      ),
    );
    final overlay = Overlay.of(pageContext, rootOverlay: true);
    Navigator.of(pageContext).push(
      MaterialPageRoute(builder: (_) => const Scaffold(body: Text('next'))),
    );
    await tester.pumpAndSettle();
    showAppSnackBarOn(overlay, 'shown on the next page');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('next'), findsOneWidget);
    expect(find.text('shown on the next page'), findsOneWidget);
  });

  testWidgets('is announced to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);
    await show(tester);
    final node = tester.getSemantics(find.text('Added to this trip'));
    expect(node.getSemanticsData().flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });
}
