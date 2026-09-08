import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_dimens.dart';
import 'package:uwearis/features/widgets/common/cards/card_corner_badge.dart';

import '../helpers/widget_harness.dart';

void main() {
  Finder discOf(Finder badge) =>
      find.descendant(of: badge, matching: find.byType(Container));

  testWidgets('default: >=44px hit target while the visible disc stays "size"', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: CardCornerBadge(
            icon: Icons.favorite_border,
            onTap: () {},
          ),
        ),
      ),
    );

    final badge = tester.getSize(find.byType(CardCornerBadge));
    final disc = tester.getSize(discOf(find.byType(CardCornerBadge)));

    expect(badge.width, greaterThanOrEqualTo(AppDimens.minTouchTarget));
    expect(badge.height, greaterThanOrEqualTo(AppDimens.minTouchTarget));
    expect(disc.width, 24);
    expect(disc.height, 24);
  });

  testWidgets('a tap in the transparent band (outside the disc) fires onTap', (
    tester,
  ) async {
    var taps = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: CardCornerBadge(icon: Icons.close, onTap: () => taps++),
        ),
      ),
    );

    final box = tester.getRect(find.byType(CardCornerBadge));
    final disc = tester.getRect(discOf(find.byType(CardCornerBadge)));
    final corner = Offset(box.left + 3, box.top + 3);
    expect(disc.contains(corner), isFalse);

    await tester.tapAt(corner);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('hitTargetSize gives a tall-but-narrow target, disc unchanged', (
    tester,
  ) async {
    var taps = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: CardCornerBadge(
            icon: Icons.lock,
            hitTargetSize: const Size(24, AppDimens.minTouchTarget),
            onTap: () => taps++,
          ),
        ),
      ),
    );

    final box = tester.getSize(find.byType(CardCornerBadge));
    final disc = tester.getSize(discOf(find.byType(CardCornerBadge)));
    expect(box.width, 24);
    expect(box.height, AppDimens.minTouchTarget);
    expect(disc.width, 24);

    // a tap near the top of the tall box (above the centred 24px disc) works
    final rect = tester.getRect(find.byType(CardCornerBadge));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 3));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('discAlignment corner pins the disc to that corner of the box', (
    tester,
  ) async {
    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: CardCornerBadge(
            icon: Icons.favorite,
            discAlignment: Alignment.topRight,
            onTap: () {},
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(CardCornerBadge));
    final disc = tester.getRect(discOf(find.byType(CardCornerBadge)));
    expect(disc.right, moreOrLessEquals(box.right, epsilon: 0.5));
    expect(disc.top, moreOrLessEquals(box.top, epsilon: 0.5));
  });

  testWidgets('adjacent lock/close badges: 44px boxes, 8px between discs, each '
      'taps its own callback', (tester) async {
    var lock = 0;
    var close = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CardCornerBadge(
                icon: Icons.lock,
                discAlignment: Alignment.centerRight,
                onTap: () => lock++,
              ),
              const SizedBox(width: 8),
              CardCornerBadge(
                icon: Icons.close,
                discAlignment: Alignment.centerLeft,
                onTap: () => close++,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.lock));
    await tester.pump();
    expect(lock, 1);
    expect(close, 0);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(close, 1);

    final lockDisc = tester.getRect(find.widgetWithIcon(Container, Icons.lock));
    final closeDisc = tester.getRect(
      find.widgetWithIcon(Container, Icons.close),
    );
    expect(closeDisc.left - lockDisc.right, moreOrLessEquals(8, epsilon: 1));
  });
}
