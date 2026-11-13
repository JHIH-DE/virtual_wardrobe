import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/cards/category_tag.dart';

import '../helpers/widget_harness.dart';

ShapeDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<Container>(
              find.descendant(
                of: find.byType(CategoryTag),
                matching: find.byType(Container),
              ),
            )
            .decoration!
        as ShapeDecoration;

void main() {
  testWidgets('is a capsule, with the border only when one is given', (
    tester,
  ) async {
    await pumpApp(tester, const Center(child: CategoryTag(label: 'Outer')));
    final plain = _decoration(tester).shape as StadiumBorder;
    expect(plain.side, BorderSide.none);

    await pumpApp(
      tester,
      const Center(
        child: CategoryTag(label: 'Outer', borderColor: AppColors.surface),
      ),
    );
    final bordered = _decoration(tester).shape as StadiumBorder;
    expect(bordered.side.color, AppColors.surface);
  });
}
