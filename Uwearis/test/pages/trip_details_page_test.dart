import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/trip_detail_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/trip_outfit.dart';
import 'package:uwearis/features/pages/trip_details_page.dart';
import 'package:uwearis/features/pages/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/action_button.dart';
import 'package:uwearis/features/widgets/common/cards/app_card_shell.dart';
import 'package:uwearis/features/widgets/common/cards/app_list_card.dart';
import 'package:uwearis/features/widgets/common/cards/generated_image_card.dart';
import 'package:uwearis/features/widgets/common/overlays/empty_state_placeholder.dart';
import 'package:uwearis/features/pages/trip_outfit_detail_page.dart';
import 'package:uwearis/features/widgets/trip/trip_outfit_tile.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

Trip _trip({List<TripLeg>? legs}) => Trip(
  id: '7',
  name: 'Kyoto Autumn',
  activities: const ['sightseeing'],
  legs:
      legs ??
      [
        TripLeg(
          location: LocationResult(
            name: 'Kyoto',
            latitude: 35,
            longitude: 135,
            timezone: 'Asia/Tokyo',
          ),
          dateRange: DateTimeRange(
            start: DateTime(2026, 11, 1),
            end: DateTime(2026, 11, 4),
          ),
        ),
      ],
);

Garment _garment(
  int id, {
  GarmentCategory category = GarmentCategory.top,
  bool deleted = false,
}) => Garment(
  id: id,
  garmentId: id,
  name: 'Item $id',
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
  isDeleted: deleted,
);

final _top = _garment(1);
final _bottom = _garment(2, category: GarmentCategory.bottom);
final _shoes = _garment(3, category: GarmentCategory.shoes);
final _viableSuitcase = [_top, _bottom, _shoes];

Map<String, dynamic> _garmentJson(Garment g) => {
  'garment_id': g.id,
  'name': g.name,
  'category': g.category.name,
};

Map<String, dynamic> _outfitJson(
  int id, {
  String source = 'suggested',
  String? name,
  List<Garment>? garments,
  bool replaceable = false,
  String? imageUrl,
}) => {
  'id': id,
  'source': source,
  'name': ?name,
  'is_replaceable': replaceable,
  'result_image_url': ?imageUrl,
  'image_outfit_id': imageUrl == null ? null : 900 + id,
  'garments': [for (final g in garments ?? _viableSuitcase) _garmentJson(g)],
};

Map<String, dynamic> _collectionJson({
  List<Garment>? suitcase,
  List<Map<String, dynamic>> outfits = const [],
  List<Map<String, dynamic>> candidates = const [],
  int generatedCount = 0,
}) => {
  'trip_id': 7,
  'total_days': 4,
  'suggested_outfit_count': {'min': 4, 'max': 6},
  'suitcase_items': [
    for (final g in suitcase ?? _viableSuitcase) _garmentJson(g),
  ],
  'outfits': outfits,
  'saved_candidates': candidates,
  'generated_count': generatedCount,
};

TripOutfitCollection _collection({
  List<Garment>? suitcase,
  List<Map<String, dynamic>> outfits = const [],
  List<Map<String, dynamic>> candidates = const [],
}) {
  final parsed = TripOutfitCollection.fromJson(
    _collectionJson(outfits: outfits, candidates: candidates),
  );
  // Keep the given Garment objects (isDeleted etc.) for the suitcase.
  return parsed.copyWith(suitcase: suitcase ?? _viableSuitcase);
}

/// Pumps [TripDetailsPage] with [tripDetailProvider] already holding
/// [detail] — what `openTripDetails` guarantees before pushing it.
Future<void> pumpDetails(
  WidgetTester tester, {
  Trip? trip,
  TripOutfitCollection detail = const TripOutfitCollection(),
}) {
  return pumpApp(
    tester,
    TripDetailsPage(trip: trip ?? _trip()),
    overrides: [tripDetailProvider.overrideWithBuild((_, _) => detail)],
  );
}

class _Recorded {
  final String method;
  final String path;
  final Object? body;
  const _Recorded(this.method, this.path, this.body);
  @override
  String toString() => '$method $path';
}

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// One client for every request of a test (`runWithClient` asks for one
  /// per request). [respond] answers trip calls not handled by default.
  http.Client Function() tripClient(
    List<_Recorded> log, {
    Map<String, dynamic>? Function(_Recorded request)? respond,
  }) {
    final client = MockClient((request) async {
      final path = request.url.path.split('/trip_plans/7').last;
      final recorded = _Recorded(
        request.method,
        path,
        request.body.isEmpty ? null : jsonDecode(request.body),
      );
      if (path == '/packing-analysis') {
        return jsonResponse(
          envelope({'overall_advice': null, 'categories': []}),
        );
      }
      log.add(recorded);
      final data = respond?.call(recorded);
      if (data != null) return jsonResponse(envelope(data));
      return jsonResponse(envelope({}), status: 404);
    });
    return () => client;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  Future<void> openTile(WidgetTester tester) async {
    await tester.tap(find.byType(TripOutfitTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(TripOutfitDetailPage), findsOneWidget);
  }

  testWidgets('tapping a grid tile opens that outfit with its garments', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(
        tester,
        detail: _collection(
          outfits: [
            _outfitJson(1, name: 'Airport Layers'),
            _outfitJson(2, name: 'Museum Day'),
          ],
        ),
      );
      await settle(tester);

      expect(find.text('Item 1'), findsNothing);
      await tester.tap(find.text('Museum Day'));
      await tester.pumpAndSettle();

      expect(find.byType(TripOutfitDetailPage), findsOneWidget);
      // Like Outfit Details: the toolbar title is only announced; the name
      // heads the body.
      expect(find.text('Outfit Details'), findsNothing);
      expect(find.bySemanticsLabel('Outfit Details'), findsOneWidget);
      expect(find.text('Museum Day'), findsOneWidget);
      expect(find.text('AI Pick'), findsNothing);
      expect(find.text('Garments (3)'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    }, tripClient([]));
  });

  testWidgets('renders the trip header, suitcase card and outfits section', (
    tester,
  ) async {
    final log = <_Recorded>[];
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(tester);
      await settle(tester);

      expect(find.text('Kyoto Autumn'), findsOneWidget);
      expect(find.text('Itinerary'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Kyoto'),
          matching: find.byType(AppCardShell),
        ),
        findsOneWidget,
      );
      expect(find.text('Suitcase'), findsOneWidget);
      expect(find.text('Outfit Planner'), findsOneWidget);
      expect(find.text('Daily Outfit Plan'), findsNothing);
      expect(log, isEmpty, reason: 'the cached collection is not re-fetched');
    }, tripClient(log));
  });

  testWidgets('the Suitcase card shows the packed count as its status', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(tester, detail: _collection());
      await settle(tester);

      final card = find.ancestor(
        of: find.text('Suitcase'),
        matching: find.byType(AppListCard),
      );
      expect(
        find.descendant(of: card, matching: find.text('3 items')),
        findsOneWidget,
      );
      expect(find.text('About 4–6 outfits suit a 4-day trip'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    }, tripClient([]));
  });

  testWidgets(
    'with nothing usable packed, the empty state points to the suitcase',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(tester);
        await settle(tester);

        expect(
          find.text(
            'Start by adding garments or your saved outfits to the suitcase.',
          ),
          findsOneWidget,
        );
        expect(find.text('Let Uwearis Plan Your Trip'), findsNothing);

        // Same shape as the Outfits tab's empty state, straight on the page
        // under "Outfits (0)": icon, title, hint, action — no card.
        expect(find.text('Outfits (0)'), findsOneWidget);
        expect(find.text('No trip outfits yet'), findsOneWidget);
        final empty = tester.widget<EmptyStatePlaceholder>(
          find.byType(EmptyStatePlaceholder),
        );
        expect(empty.decoration, isNull);
        expect(empty.icon, Icons.style_outlined);

        await tester.tap(find.text('Open Suitcase'));
        await tester.pumpAndSettle();
        expect(find.byType(TripSuitcasePage), findsOneWidget);
      }, tripClient([]));
    },
  );

  testWidgets(
    'a viable suitcase with no outfits offers Plan Trip Outfits, which '
    'plans and renders the collection here',
    (tester) async {
      final log = <_Recorded>[];
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpDetails(tester, detail: _collection());
          await settle(tester);

          expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);
          await tester.tap(find.text('Plan Trip Outfits'));
          await tester.pumpAndSettle();

          expect(log.single.toString(), 'POST /outfits/generate');
          expect(log.single.body, {'mode': 'plan'});
          expect(find.byType(TripOutfitTile), findsNWidgets(2));
          expect(find.text('Added 2 new outfits.'), findsOneWidget);
        },
        tripClient(
          log,
          respond: (r) => _collectionJson(
            outfits: [
              _outfitJson(1, name: 'Airport Layers', replaceable: true),
              _outfitJson(2, replaceable: true),
            ],
            generatedCount: 2,
          ),
        ),
      );
    },
  );

  testWidgets('grid tiles show the name and one tag — Edited over Kept over '
      'the source — and Refresh shows only while there is a replaceable '
      'suggestion', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(
        tester,
        detail: _collection(
          outfits: [
            _outfitJson(1, source: 'saved_outfit', name: 'Weekend'),
            _outfitJson(2, source: 'manual'),
            {..._outfitJson(3), 'is_pinned': true},
            _outfitJson(4),
            {
              ..._outfitJson(5, source: 'saved_outfit'),
              'is_manually_edited': true,
            },
            {..._outfitJson(6), 'is_pinned': true, 'is_manually_edited': true},
          ],
        ),
      );
      await settle(tester);

      expect(find.byType(TripOutfitTile), findsNWidgets(6));
      expect(find.text('Outfits (6)'), findsOneWidget);
      // 6 outfits reach the 4-day trip's suggested minimum of 4.
      expect(find.text('Good outfit variety for 4 days'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(find.textContaining('outfits suit a'), findsNothing);
      expect(
        find.ancestor(
          of: find.text('Outfit Planner'),
          matching: find.byType(AppCardShell),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.byType(TripOutfitTile).first,
          matching: find.byType(AppCardShell),
        ),
        findsNothing,
        reason: 'the grid sits under the card, not inside it',
      );
      expect(
        find.ancestor(
          of: find.text('Add AI Outfits'),
          matching: find.byType(AppCardShell),
        ),
        findsOneWidget,
      );
      expect(find.text('Weekend'), findsOneWidget);
      // Unnamed outfits fall back to their position.
      expect(find.text('Outfit 2'), findsOneWidget);
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('AI Pick'), findsOneWidget);
      expect(find.text('Kept'), findsOneWidget);
      expect(find.text('Edited'), findsNWidgets(2));
      expect(find.text('Refresh AI Outfits'), findsNothing);
      expect(find.text('Add AI Outfits'), findsOneWidget);
      expect(find.text('Add Manually'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Add AI Outfits'),
          matching: find.byType(ActionButton),
        ),
        findsOneWidget,
      );
    }, tripClient([]));
  });

  testWidgets(
    'Refresh confirms with the number of suggestions it replaces, and does '
    'nothing on Cancel',
    (tester) async {
      final log = <_Recorded>[];
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpDetails(
            tester,
            detail: _collection(
              outfits: [
                _outfitJson(1, source: 'saved_outfit'),
                _outfitJson(2, replaceable: true),
                _outfitJson(3, replaceable: true),
              ],
            ),
          );
          await settle(tester);

          await tester.tap(find.text('Refresh AI Outfits'));
          await tester.pumpAndSettle();
          expect(find.textContaining('replace 2 AI picks'), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
          expect(log, isEmpty);

          await tester.tap(find.text('Refresh AI Outfits'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Refresh'));
          await tester.pumpAndSettle();
          expect(log.single.body, {'mode': 'refresh'});
        },
        tripClient(
          log,
          respond: (_) => _collectionJson(
            outfits: [
              _outfitJson(1, source: 'saved_outfit'),
              _outfitJson(4, replaceable: true),
              _outfitJson(5, replaceable: true),
            ],
            generatedCount: 2,
          ),
        ),
      );
    },
  );

  testWidgets(
    'Add AI Outfits with nothing new says so and leaves the collection as it was',
    (tester) async {
      final log = <_Recorded>[];
      final outfits = [_outfitJson(1, source: 'saved_outfit')];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(tester, detail: _collection(outfits: outfits));
        await settle(tester);

        await tester.tap(find.text('Add AI Outfits'));
        await tester.pumpAndSettle();

        expect(log.single.body, {'mode': 'more'});
        expect(
          find.text(
            'No more suitable combinations found with your current suitcase.',
          ),
          findsOneWidget,
        );
        expect(find.byType(TripOutfitTile), findsOneWidget);
      }, tripClient(log, respond: (_) => _collectionJson(outfits: outfits)));
    },
  );

  testWidgets(
    'an outfit whose garment left the suitcase stays, marked missing, with '
    'try-on disabled; Add to Suitcase re-packs just that garment',
    (tester) async {
      final log = <_Recorded>[];
      final away = _garment(9, category: GarmentCategory.outer);
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpDetails(
            tester,
            detail: _collection(
              outfits: [
                _outfitJson(1, garments: [..._viableSuitcase, away]),
              ],
            ),
          );
          await settle(tester);
          expect(
            find.descendant(
              of: find.byType(TripOutfitTile),
              matching: find.byIcon(Icons.error),
            ),
            findsOneWidget,
          );

          await openTile(tester);
          expect(find.text('Missing 1 garment'), findsOneWidget);
          final generate = tester.widget<AccentPillButton>(
            find.widgetWithText(AccentPillButton, 'Generate Outfit'),
          );
          expect(generate.enabled, isFalse);

          await tester.tap(find.text('Add to Suitcase'));
          await tester.pumpAndSettle();

          final add = log.firstWhere((r) => r.path == '/suitcase-items');
          expect(add.body, {
            'garment_ids': [9],
          });
          expect(find.text('Missing 1 garment'), findsNothing);
        },
        tripClient(
          log,
          respond: (r) {
            if (r.path == '/suitcase-items') {
              return {
                'suitcase_items': [
                  for (final g in [..._viableSuitcase, away]) _garmentJson(g),
                ],
              };
            }
            if (r.method == 'GET' && r.path == '/outfits') {
              return _collectionJson(
                suitcase: [..._viableSuitcase, away],
                outfits: [
                  _outfitJson(1, garments: [..._viableSuitcase, away]),
                ],
              );
            }
            return null;
          },
        ),
      );
    },
  );

  testWidgets(
    'a garment deleted from the closet can only be replaced by editing',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: _collection(
            outfits: [
              {
                ..._outfitJson(1),
                'garments': [
                  _garmentJson(_top),
                  {..._garmentJson(_bottom), 'is_deleted': true},
                  _garmentJson(_shoes),
                ],
              },
            ],
          ),
        );
        await settle(tester);
        await openTile(tester);

        expect(find.text('Missing 1 garment'), findsOneWidget);
        expect(
          find.text(
            'A garment was deleted from your closet — edit this outfit to '
            'replace it.',
          ),
          findsOneWidget,
        );
        expect(find.text('Add to Suitcase'), findsNothing);
        expect(
          find.widgetWithText(AccentPillButton, 'Edit Outfit'),
          findsOneWidget,
        );
      }, tripClient([]));
    },
  );

  testWidgets('a saved outfit that fits the suitcase is suggested, and Add to '
      'Trip adds that version', (tester) async {
    final log = <_Recorded>[];
    final candidate = {
      'outfit_id': 77,
      'group_id': 7,
      'group_type': 'general',
      'status': 'completed',
      'name': 'City Walk',
      'garment_ids': [1, 2, 3],
      'result_image_url': '',
    };
    await http.runWithClient(
      () async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: _collection(
            outfits: [_outfitJson(1, replaceable: true)],
            candidates: [candidate],
          ),
        );
        await settle(tester);

        expect(find.text('From Your Outfits'), findsOneWidget);
        await tester.tap(find.text('Add to Trip'));
        await tester.pumpAndSettle();

        expect(log.single.toString(), 'POST /outfits/from-saved');
        expect(log.single.body, {'outfit_id': 77});
        expect(find.text('From Your Outfits'), findsNothing);
        expect(find.byType(TripOutfitTile), findsNWidgets(2));
        expect(find.text('Added to this trip.'), findsOneWidget);
      },
      tripClient(
        log,
        respond: (_) => _collectionJson(
          outfits: [
            _outfitJson(1, replaceable: true),
            _outfitJson(2, source: 'saved_outfit', name: 'City Walk'),
          ],
        ),
      ),
    );
  });

  testWidgets('Keep and Remove from Trip go through the outfit page menu, '
      'and removing returns to the grid', (tester) async {
    final log = <_Recorded>[];
    await http.runWithClient(
      () async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: _collection(outfits: [_outfitJson(1, replaceable: true)]),
        );
        await settle(tester);
        await openTile(tester);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Keep Outfit'));
        await tester.pumpAndSettle();
        expect(log.last.toString(), 'PATCH /outfits/1');
        expect(log.last.body, {'is_pinned': true});
        // No tags on this page; the menu reflects the kept state instead.
        expect(find.text('Kept'), findsNothing);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        expect(find.text("Don't Keep"), findsOneWidget);
        await tester.tap(find.text('Remove from Trip'));
        await tester.pumpAndSettle();
        expect(find.text('Remove from trip?'), findsOneWidget);
        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(log.last.toString(), 'DELETE /outfits/1');
        expect(find.byType(TripOutfitDetailPage), findsNothing);
        expect(find.byType(TripOutfitTile), findsNothing);
      },
      tripClient(
        log,
        respond: (r) => switch (r.method) {
          'PATCH' => _collectionJson(
            outfits: [
              {..._outfitJson(1), 'is_pinned': true},
            ],
          ),
          'DELETE' => _collectionJson(),
          _ => null,
        },
      ),
    );
  });

  testWidgets('Generate Outfit on the outfit page renders its try-on', (
    tester,
  ) async {
    final log = <_Recorded>[];
    await http.runWithClient(
      () async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: _collection(outfits: [_outfitJson(1, replaceable: true)]),
        );
        await settle(tester);
        await openTile(tester);
        expect(find.text('Generate Outfit'), findsOneWidget);

        await tester.tap(find.text('Generate Outfit'));
        // Not pumpAndSettle: the network image placeholder never settles.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(log.single.toString(), 'POST /outfits/1/try-on');
        expect(find.byType(GeneratedImageCard), findsOneWidget);
        expect(find.text('Generate Outfit'), findsNothing);
      },
      tripClient(
        log,
        respond: (_) => _collectionJson(
          outfits: [_outfitJson(1, imageUrl: 'https://example.com/outfit.jpg')],
        ),
      ),
    );
  });

  testWidgets('Edit Itinerary: Save starts disabled, enables once a leg is '
      'removed, persists the change and re-reads the collection', (
    tester,
  ) async {
    final log = <_Recorded>[];
    await http.runWithClient(
      () async {
        useTallSurface(tester);
        final trip = _trip(
          legs: [
            TripLeg(
              location: LocationResult(
                name: 'Kyoto',
                latitude: 35,
                longitude: 135,
                timezone: 'Asia/Tokyo',
              ),
              dateRange: DateTimeRange(
                start: DateTime(2026, 11, 1),
                end: DateTime(2026, 11, 4),
              ),
            ),
            TripLeg(
              location: LocationResult(
                name: 'Osaka',
                latitude: 34,
                longitude: 135,
                timezone: 'Asia/Tokyo',
              ),
              dateRange: DateTimeRange(
                start: DateTime(2026, 11, 4),
                end: DateTime(2026, 11, 6),
              ),
            ),
          ],
        );
        await pumpDetails(tester, trip: trip);
        await settle(tester);

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit Itinerary'));
        await tester.pumpAndSettle();

        Finder saveButtonFinder() => find.byType(ElevatedButton).last;
        ElevatedButton saveButton() =>
            tester.widget<ElevatedButton>(saveButtonFinder());

        expect(saveButton().onPressed, isNull);

        // Remove Osaka; remove badges are disabled only for a single leg.
        await tester.tap(find.byIcon(Icons.close).last);
        await tester.pump();
        expect(saveButton().onPressed, isNotNull);

        await tester.tap(saveButtonFinder());
        await tester.pumpAndSettle();

        final patch = log.firstWhere((r) => r.method == 'PATCH');
        final legs = (patch.body as Map)['legs'] as List;
        expect(legs, hasLength(1));
        expect(legs.single['location'], 'Kyoto');
        expect(log.map((r) => r.toString()), contains('GET /outfits'));
      },
      tripClient(
        log,
        respond: (r) => switch ((r.method, r.path)) {
          ('PATCH', '') => {},
          ('GET', '/outfits') => _collectionJson(),
          _ => null,
        },
      ),
    );
  });

  // TripsPage.handleCreateTrip pushes TripSuitcasePage directly, not via
  // _openSuitcase; the plan reaches this page through tripDetailProvider.
  testWidgets(
    'outfits planned on a Suitcase page pushed directly on top of this page '
    '(the just-created-trip flow) show up on return',
    (tester) async {
      final log = <_Recorded>[];
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpDetails(tester, detail: _collection());
          await settle(tester);
          expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);

          final navigator = tester.state<NavigatorState>(
            find.byType(Navigator),
          );
          navigator.push(
            MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip())),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.text('Plan Trip Outfits'));
          await tester.pumpAndSettle();

          expect(find.byType(TripSuitcasePage), findsNothing);
          expect(find.byType(TripOutfitTile), findsOneWidget);
          expect(find.text('Let Uwearis Plan Your Trip'), findsNothing);
          expect(
            log.where((r) => r.method == 'GET' && r.path == '/outfits'),
            isEmpty,
            reason: 'both pages render from the cached collection',
          );
        },
        tripClient(
          log,
          respond: (r) => r.path == '/outfits/generate'
              ? _collectionJson(
                  outfits: [_outfitJson(1, replaceable: true)],
                  generatedCount: 1,
                )
              : null,
        ),
      );
    },
  );

  testWidgets('expired signed image URLs trigger one background reload', (
    tester,
  ) async {
    final log = <_Recorded>[];
    // An already-expired GCS signed URL.
    const stale =
        'https://storage.googleapis.com/b/o.jpg?X-Goog-Date=20200101T000000Z'
        '&X-Goog-Expires=60';
    await http.runWithClient(
      () async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: _collection(outfits: [_outfitJson(1, imageUrl: stale)]),
        );
        await tester.pumpAndSettle();

        expect(log.map((r) => r.toString()), ['GET /outfits']);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TripDetailsPage)),
        );
        expect(
          container.read(tripDetailProvider(7)).value!.outfits.single.name,
          'Fresh',
        );
      },
      tripClient(
        log,
        respond: (_) =>
            _collectionJson(outfits: [_outfitJson(1, name: 'Fresh')]),
      ),
    );
  });
}
