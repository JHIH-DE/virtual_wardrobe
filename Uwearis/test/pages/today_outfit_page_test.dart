import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/features/pages/today_outfit_page.dart';
import 'package:uwearis/features/widgets/outfit/outfit_tag_rows.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

class _FakeDailyOutfitNotifier extends DailyOutfitNotifier {
  _FakeDailyOutfitNotifier(this._outfits);
  final List<Outfit> _outfits;

  @override
  Future<List<Outfit>> build() async => _outfits;
}

class _FakeOutfitsNotifier extends OutfitsNotifier {
  _FakeOutfitsNotifier(this._outfits);
  final List<Outfit> _outfits;

  @override
  Future<List<Outfit>> build() async => _outfits;
}

// The closet cache isn't loaded on a page opened on its own, so each
// garment resolves through GET /garments/{id}.
http.Client _garmentClient() => MockClient((request) async {
  const names = {'1': ('Tee', 'Top'), '2': ('Jeans', 'Bottom')};
  final garment = names[request.url.pathSegments.last];
  if (garment == null) return jsonResponse(envelope({}), status: 404);
  return jsonResponse(
    envelope({
      'id': int.parse(request.url.pathSegments.last),
      'name': garment.$1,
      'category': garment.$2,
      'sub_category': '',
      'upload_url': '',
      'object_name': '',
      'image_url': '',
    }),
  );
});

// Empty image URLs keep the carousel off the network.
final _options = [
  Outfit(id: 10, groupId: 1, name: 'Office', imageUrl: '', garmentIds: [1]),
  Outfit(
    id: 20,
    groupId: 2,
    name: 'Weekend',
    imageUrl: '',
    garmentIds: [2],
    seasons: ['summer'],
    style: ['smart_casual', 'street'],
  ),
  Outfit(id: 30, groupId: 3, imageUrl: '', garmentIds: [1, 2]),
];

List<Override> _overrides({List<Outfit> myOutfits = const []}) => [
  dailyOutfitProvider.overrideWith(() => _FakeDailyOutfitNotifier(_options)),
  outfitsProvider.overrideWith(() => _FakeOutfitsNotifier(myOutfits)),
];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(setUpFakeAuth);

  // Tall enough for the 3:4 photo and the garment list below it to both
  // be laid out.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('opens on the tapped option and swipes between today\'s '
      'options, reporting each one back', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      final reported = <int>[];
      await pumpApp(
        tester,
        TodayOutfitPage(initialIndex: 1, onIndexChanged: reported.add),
        overrides: _overrides(),
      );
      await _settle(tester);

      expect(find.text("Today's Outfit"), findsOneWidget);
      expect(find.text('Weekend'), findsOneWidget);
      expect(find.text('Jeans'), findsOneWidget);
      expect(find.text('Tee'), findsNothing);

      await tester.drag(find.byType(PageView), const Offset(-800, 0));
      await _settle(tester);

      expect(reported, [2]);
      expect(find.text('Weekend'), findsNothing);
      expect(find.text('Garments (2)'), findsOneWidget);
      expect(find.text('Tee'), findsOneWidget);
      expect(find.text('Jeans'), findsOneWidget);

      await tester.drag(find.byType(PageView), const Offset(800, 0));
      await tester.drag(find.byType(PageView), const Offset(800, 0));
      await _settle(tester);

      expect(reported.last, 0);
      expect(find.text('Office'), findsOneWidget);
    }, _garmentClient);
  });

  testWidgets("shows a renamed group's name, which daily outfits don't "
      'carry themselves', (tester) async {
    await http.runWithClient(() async {
      await pumpApp(
        tester,
        const TodayOutfitPage(),
        overrides: _overrides(
          myOutfits: [
            Outfit(id: 10, groupId: 1, groupName: 'Monday Look', imageUrl: ''),
          ],
        ),
      );
      await _settle(tester);

      expect(find.text('Monday Look'), findsOneWidget);
      expect(find.text('Office'), findsNothing);
    }, _garmentClient);
  });

  testWidgets('offers View Full Outfit and no version or edit controls', (
    tester,
  ) async {
    await pumpApp(tester, const TodayOutfitPage(), overrides: _overrides());
    await _settle(tester);

    expect(find.text('View Full Outfit'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
  });

  testWidgets('shows season and style tags beside the edit-tags button', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await pumpApp(
        tester,
        const TodayOutfitPage(initialIndex: 1),
        overrides: _overrides(),
      );
      await _settle(tester);

      expect(find.text('Summer'), findsOneWidget);
      expect(find.text('Smart Casual'), findsOneWidget);
      expect(find.text('Street'), findsOneWidget);
      expect(find.byIcon(Icons.sell_outlined), findsOneWidget);
    }, _garmentClient);
  });

  testWidgets('an untagged option reads "My Collection"', (tester) async {
    await http.runWithClient(() async {
      await pumpApp(tester, const TodayOutfitPage(), overrides: _overrides());
      await _settle(tester);

      expect(find.text('My Collection'), findsOneWidget);
      expect(find.byType(OutfitTagRows), findsNothing);
    }, _garmentClient);
  });

  // Outfit Details opened from here reads OutfitService / outfitsProvider,
  // so an edit here must reach My Outfits as well as today's list.
  testWidgets('editing tags PATCHes them and syncs today and My Outfits', (
    tester,
  ) async {
    final patches = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        patches.add(jsonDecode(request.body) as Map<String, dynamic>);
        return jsonResponse(envelope({'outfit_id': 10, 'group_id': 1}));
      }
      return _garmentClient().send(request).then(http.Response.fromStream);
    });

    useTallSurface(tester);
    await http.runWithClient(() async {
      await pumpApp(
        tester,
        const TodayOutfitPage(),
        overrides: _overrides(myOutfits: [_options[0]]),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(TodayOutfitPage)),
      );
      container.listen(outfitsProvider, (_, _) {});
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.sell_outlined));
      await _settle(tester);
      await tester.tap(find.text('Winter'));
      await _settle(tester);
      await tester.tapAt(const Offset(10, 10));
      await _settle(tester);

      expect(patches.single['season'], ['winter']);
      expect(find.text('Winter'), findsOneWidget);
      expect(container.read(dailyOutfitProvider).value!.first.seasons, [
        'winter',
      ]);
      expect(container.read(outfitsProvider).value!.single.seasons, ['winter']);
    }, () => client);
  });
}
