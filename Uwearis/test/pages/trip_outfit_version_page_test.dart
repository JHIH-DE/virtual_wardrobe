import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/trip_outfit_version_page.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._items);
  final List<Garment> _items;

  @override
  Future<List<Garment>> build() async => _items;

  @override
  Future<void> refresh() async => state = AsyncData(_items);
}

Garment _garment(int id, String name, GarmentCategory category) => Garment(
  id: id,
  garmentId: id,
  name: name,
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
);

Map<String, dynamic> _outfitJson(int id, int groupId, List<int> garmentIds) => {
  'outfit_id': id,
  'group_id': groupId,
  'group_type': 'general',
  'status': 'completed',
  'garment_ids': garmentIds,
  'result_image_url': '',
  'season': <String>[],
  'style': <String>[],
  'is_favorite': false,
};

void main() {
  setUp(setUpFakeAuth);

  final closet = [
    _garment(1, 'Tee', GarmentCategory.top),
    _garment(2, 'Jeans', GarmentCategory.bottom),
    _garment(3, 'Sneakers', GarmentCategory.shoes),
  ];

  /// Returns a getter for the popped result.
  Future<Outfit? Function()> pumpPage(WidgetTester tester, Outfit seed) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Outfit? popped;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              popped = await Navigator.push<Outfit>(
                context,
                MaterialPageRoute(
                  builder: (_) => TripOutfitVersionPage(outfit: seed),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [garmentsProvider.overrideWith(() => _FakeGarments(closet))],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => popped;
  }

  testWidgets(
    'swiping between versions updates the counter and the garments to pack, '
    'and Add to Suitcase pops with the version on screen',
    (tester) async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/outfit/40')) {
          return jsonResponse(
            envelope({
              'group_id': 40,
              'outfits': [
                _outfitJson(65, 40, [1]),
                // 99 isn't in the closet, so it can't be packed.
                _outfitJson(66, 40, [2, 3, 99]),
              ],
            }),
          );
        }
        return jsonResponse(envelope({}), status: 404);
      });

      await http.runWithClient(() async {
        final popped = await pumpPage(
          tester,
          Outfit(id: 65, groupId: 40, imageUrl: '', garmentIds: const [1]),
        );

        expect(find.text('Select a Version'), findsOneWidget);
        expect(find.text('1 / 2'), findsOneWidget);
        expect(find.text('Tee'), findsOneWidget);
        expect(find.text('Garments (1)'), findsOneWidget);

        await tester.drag(find.byType(PageView), const Offset(-800, 0));
        await tester.pumpAndSettle();

        expect(find.text('2 / 2'), findsOneWidget);
        expect(find.text('Tee'), findsNothing);
        expect(find.text('Jeans'), findsOneWidget);
        expect(find.text('Sneakers'), findsOneWidget);
        expect(find.text('Garments (2)'), findsOneWidget);

        await tester.tap(find.text('Add to Suitcase'));
        await tester.pumpAndSettle();

        expect(find.byType(TripOutfitVersionPage), findsNothing);
        expect(popped()?.id, 66);
      }, () => client);
    },
  );

  testWidgets('if the versions fail to load, the tapped outfit is still '
      'offered on its own, without a counter', (tester) async {
    final client = MockClient(
      (request) async => jsonResponse(envelope({}), status: 500),
    );

    await http.runWithClient(() async {
      final popped = await pumpPage(
        tester,
        Outfit(id: 70, groupId: 41, imageUrl: '', garmentIds: const [3]),
      );

      expect(find.textContaining(' / '), findsNothing);
      expect(find.text('Sneakers'), findsOneWidget);

      await tester.tap(find.text('Add to Suitcase'));
      await tester.pumpAndSettle();

      expect(popped()?.id, 70);
    }, () => client);
  });
}
