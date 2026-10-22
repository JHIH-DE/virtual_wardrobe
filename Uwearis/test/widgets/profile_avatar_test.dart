import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/profile_avatar.dart';

import '../helpers/widget_harness.dart';

void main() {
  BoxDecoration outerDecoration(WidgetTester tester) =>
      tester
              .widget<Container>(
                find
                    .descendant(
                      of: find.byType(ProfileAvatar),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  testWidgets('no ringColor: no ring, the photo fills the size', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: Center(child: ProfileAvatar(size: 96, showEditLabel: false)),
      ),
    );

    expect(outerDecoration(tester).border, isNull);
    expect(tester.getSize(find.byType(ClipOval)), const Size.square(96));
  });

  testWidgets('a ringColor draws the ring and keeps the overall size', (
    tester,
  ) async {
    await pumpApp(
      tester,
      const Scaffold(
        body: Center(
          child: ProfileAvatar(
            size: 96,
            showEditLabel: false,
            ringColor: AppColors.tierGold,
          ),
        ),
      ),
    );

    final border = outerDecoration(tester).border! as Border;
    expect(border.top.color, AppColors.tierGold);
    expect(tester.getSize(find.byType(ProfileAvatar)), const Size.square(96));
    expect(
      tester.getSize(find.byType(ClipOval)).width,
      lessThan(96),
      reason: 'the photo sits inside the ring',
    );
  });
}
