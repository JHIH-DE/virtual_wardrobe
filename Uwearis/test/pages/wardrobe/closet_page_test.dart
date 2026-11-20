import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/wardrobe/closet_page.dart';
import 'package:uwearis/features/widgets/garment/category_selector.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

Garment _garment(int id, GarmentCategory category) => Garment(
  id: id,
  garmentId: id,
  name: 'Item $id',
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
);

void main() {
  setUp(setUpFakeAuth);

  testWidgets(
    'an empty closet shows the "no garments" empty state, centered, with '
    'an Add Garment action that opens the add-clothing dialog',
    (tester) async {
      await pumpApp(
        tester,
        const ClosetPage(),
        overrides: [
          garmentsProvider.overrideWith(
            () => SeededGarmentsNotifier([], refreshReseeds: true),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('No garments in Closet'), findsOneWidget);
      expect(
        find.text('Add pieces from this category to build out your closet.'),
        findsOneWidget,
      );
      expect(find.text('Add Garment'), findsOneWidget);

      expect(find.byType(CategorySelector), findsNothing);

      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();

      expect(find.text('Add Clothing'), findsOneWidget);
    },
  );

  testWidgets('a non-empty closet still shows CategorySelector, so switching '
      'categories stays available', (tester) async {
    await pumpApp(
      tester,
      const ClosetPage(),
      overrides: [
        garmentsProvider.overrideWith(
          () => SeededGarmentsNotifier([
            _garment(1, GarmentCategory.top),
          ], refreshReseeds: true),
        ),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CategorySelector), findsOneWidget);
  });
}
