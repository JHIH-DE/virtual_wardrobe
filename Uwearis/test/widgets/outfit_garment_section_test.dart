import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/outfit/outfit_garment_section.dart';

import '../helpers/widget_harness.dart';

void main() {
  const tee = Garment(
    id: 1,
    name: 'Tee',
    category: GarmentCategory.top,
    subCategory: '',
    uploadUrl: '',
    objectName: '',
    imageUrl: '',
  );

  testWidgets('a failed load shows Retry instead of a list', (tester) async {
    var retries = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: OutfitGarmentSection(
          garments: null,
          garmentCount: 2,
          isLoading: false,
          onGarmentTap: (_) {},
          error: Exception('offline'),
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.text('Failed to Load'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('without an error the garments show', (tester) async {
    await pumpApp(
      tester,
      Scaffold(
        body: OutfitGarmentSection(
          garments: const [tee],
          garmentCount: 1,
          isLoading: false,
          onGarmentTap: (_) {},
          onRetry: () {},
        ),
      ),
    );

    expect(find.text('Tee'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
