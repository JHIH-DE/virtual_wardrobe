import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/outfits_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/widget_harness.dart';

class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._items);
  final List<Garment> _items;

  @override
  Future<List<Garment>> build() async => _items;

  // refreshIfNeeded() would otherwise fire a real HTTP refresh() when empty.
  @override
  Future<void> refresh() async => state = AsyncData(_items);
}

class _FakeOutfits extends OutfitsNotifier {
  _FakeOutfits(this._items);
  final List<Outfit> _items;

  @override
  Future<List<Outfit>> build() async => _items;

  // refreshIfNeeded() would otherwise fire a real HTTP refresh() when empty.
  @override
  Future<void> refresh() async => state = AsyncData(_items);
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets('no outfits shows the "no outfits" empty state, centered, with a '
      'Create Outfit action that opens the create-outfit flow', (tester) async {
    await pumpApp(
      tester,
      const OutfitsPage(),
      overrides: [
        outfitsProvider.overrideWith(() => _FakeOutfits([])),
        garmentsProvider.overrideWith(() => _FakeGarments([])),
      ],
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('No outfits yet'), findsOneWidget);
    expect(
      find.text('Combine pieces from your closet into a complete look.'),
      findsOneWidget,
    );
    expect(find.text('Create Outfit'), findsOneWidget);

    await tester.tap(find.text('Create Outfit'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Match a Look'), findsOneWidget);
  });
}
