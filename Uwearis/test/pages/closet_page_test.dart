import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/closet_page.dart';
import 'package:uwearis/features/widgets/garment/category_selector.dart';

import '../helpers/fake_auth.dart';
import '../helpers/widget_harness.dart';

Garment _garment(int id, GarmentCategory category) => Garment(
  id: id,
  garmentId: id,
  name: 'Item $id',
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
);

class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._items);
  final List<Garment> _items;

  @override
  Future<List<Garment>> build() async => _items;

  // Overridden too — the base refreshIfNeeded() would otherwise fire a real
  // (unmocked) HTTP refresh() whenever _items is empty.
  @override
  Future<void> refresh() async => state = AsyncData(_items);
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets(
    'an empty closet shows the "no garments" empty state, centered, with '
    'an Add Garment action that opens the add-clothing dialog',
    (tester) async {
      await pumpApp(
        tester,
        const ClosetPage(),
        overrides: [garmentsProvider.overrideWith(() => _FakeGarments([]))],
      );
      await tester.pump();
      await tester.pump();

      // The whole closet is empty — no category to name, so this reads
      // "No garments in Closet", not "No garments in Top" (the
      // fallback-category text used when only the *selected* category is
      // empty but others have stock).
      expect(find.text('No garments in Closet'), findsOneWidget);
      expect(
        find.text('Add pieces from this category to build out your closet.'),
        findsOneWidget,
      );
      expect(find.text('Add Garment'), findsOneWidget);

      // Nothing to switch between when the closet is totally empty — see
      // _buildBody's `if (available.isNotEmpty)`. Without this the empty
      // state would center in a shorter area this 64px bar pushes down.
      expect(find.byType(CategorySelector), findsNothing);

      await tester.tap(find.text('Add Garment'));
      await tester.pumpAndSettle();

      // GarmentUploadHelper's own dialog opened.
      expect(find.text('Add Clothing'), findsOneWidget);
    },
  );

  testWidgets(
    'a non-empty closet still shows CategorySelector, so switching '
    'categories stays available',
    (tester) async {
      await pumpApp(
        tester,
        const ClosetPage(),
        overrides: [
          garmentsProvider.overrideWith(
            () => _FakeGarments([_garment(1, GarmentCategory.top)]),
          ),
        ],
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CategorySelector), findsOneWidget);
    },
  );
}
