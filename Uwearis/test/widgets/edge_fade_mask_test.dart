import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/widgets/common/edge_fade_mask.dart';

void main() {
  Widget host(ScrollController controller) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        height: 100,
        width: 300,
        child: EdgeFadeMask(
          controller: controller,
          fadeWidth: 24,
          child: ListView.builder(
            controller: controller,
            scrollDirection: Axis.horizontal,
            itemCount: 10,
            itemBuilder: (_, i) => const SizedBox(width: 120),
          ),
        ),
      ),
    ),
  );

  // The mask's fade amounts can't be read back off the Shader, so assert via
  // the (start, end) target the ShaderMask is driven by.
  Offset fade(WidgetTester tester) =>
      tester
          .widget<TweenAnimationBuilder<Offset>>(
            find.byType(TweenAnimationBuilder<Offset>),
          )
          .tween
          .end ??
      Offset.zero;

  double startFade(WidgetTester tester) => fade(tester).dx;
  double endFade(WidgetTester tester) => fade(tester).dy;

  testWidgets('at the start only the trailing edge is faded', (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();

    expect(startFade(tester), 0);
    expect(endFade(tester), 1);
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('the fade ramps in proportionally with the scroll offset', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();

    controller.jumpTo(12); // half a fade-width
    await tester.pumpAndSettle();
    expect(startFade(tester), moreOrLessEquals(0.5, epsilon: 0.05));

    controller.jumpTo(200); // well past
    await tester.pumpAndSettle();
    expect(startFade(tester), 1);
  });

  testWidgets('startFade:false keeps the leading edge clear even when scrolled', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            height: 100,
            width: 300,
            child: EdgeFadeMask(
              controller: controller,
              startFade: false,
              child: ListView.builder(
                controller: controller,
                scrollDirection: Axis.horizontal,
                itemCount: 10,
                itemBuilder: (_, i) => const SizedBox(width: 120),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller.jumpTo(200);
    await tester.pumpAndSettle();

    expect(find.byType(ShaderMask), findsOneWidget);
    expect(tester.takeException(), isNull);
    // The trailing edge still fades even with the leading one turned off.
    expect(endFade(tester), 1);
  });

  testWidgets('scrolled to the end, the leading edge is faded and not the trailing', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(host(controller));
    await tester.pumpAndSettle();

    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pumpAndSettle();

    expect(startFade(tester), 1);
    expect(endFade(tester), 0);
    expect(tester.takeException(), isNull);
  });
}
