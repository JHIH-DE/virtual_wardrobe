import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/features/widgets/common/cards/removable_card.dart';

import '../helpers/widget_harness.dart';

void main() {
  testWidgets(
    'the delete badge uses hintText, matching FavoriteCard\'s neutral-state '
    'color — not the darker AppColors.icon',
    (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: RemovableCard(onDelete: () {}, child: const SizedBox.square(dimension: 80)),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.close));
      expect(icon.color, AppColors.hintText);
    },
  );
}
