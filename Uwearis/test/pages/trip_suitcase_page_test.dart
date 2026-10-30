import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/trip_detail_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/trip_outfit.dart';
import 'package:uwearis/features/pages/trip_outfit_selection_page.dart';
import 'package:uwearis/features/pages/trip_outfit_version_page.dart';
import 'package:uwearis/features/pages/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/buttons/action_disc_button.dart';
import 'package:uwearis/features/widgets/common/images/app_spinner.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/outfit/outfit_card.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

Trip _trip() => Trip(
  id: '7',
  name: 'Kyoto Autumn',
  activities: const ['sightseeing'],
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
  ],
);

class _FakeOutfits extends OutfitsNotifier {
  _FakeOutfits(this._items);
  final List<Outfit> _items;

  @override
  Future<List<Outfit>> build() async => _items;

  @override
  Future<void> refresh() async => state = AsyncData(_items);
}

class _FakeGarments extends GarmentsNotifier {
  _FakeGarments(this._items);
  final List<Garment> _items;

  @override
  Future<List<Garment>> build() async => _items;

  @override
  Future<void> refresh() async => state = AsyncData(_items);
}

const _tee = {'garment_id': 1, 'name': 'Tee', 'category': 'top'};
const _jeans = {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'};
const _sneakers = {'garment_id': 3, 'name': 'Sneakers', 'category': 'shoes'};
const _cap = {'garment_id': 4, 'name': 'Cap', 'category': 'accessory'};

Map<String, dynamic> _collection({
  List<Map<String, dynamic>> suitcase = const [],
  List<Map<String, dynamic>> outfits = const [],
  int generatedCount = 0,
}) => {
  'trip_id': 7,
  'total_days': 4,
  'suggested_outfit_count': {'min': 4, 'max': 6},
  'suitcase_items': suitcase,
  'outfits': outfits,
  'saved_candidates': [],
  'generated_count': generatedCount,
};

Map<String, dynamic> _tripOutfit(
  int id,
  List<Map<String, dynamic>> garments, {
  String source = 'suggested',
  int? sourceOutfitId,
}) => {
  'id': id,
  'source': source,
  'source_outfit_id': ?sourceOutfitId,
  'garments': garments,
};

Garment _closetGarment(int id, String name, GarmentCategory category) =>
    Garment(
      id: id,
      garmentId: id,
      name: name,
      category: category,
      subCategory: '',
      uploadUrl: '',
      objectName: '',
    );

void main() {
  setUp(setUpFakeAuth);

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Every trip-outfit endpoint answers with the whole collection. Returns
  /// a factory for `runWithClient`, which calls it per request — the one
  /// client keeps its state across them.
  http.Client Function() suitcaseClient({
    List<Map<String, dynamic>> suitcaseItems = const [_tee, _jeans],
    List<Map<String, dynamic>> outfits = const [],
    Future<void>? tripLoaded,
    List<String>? requestLog,
    Map<String, dynamic> Function(Map<String, dynamic> body)? onGenerate,
    Future<http.Response> Function(Map<String, dynamic> body)? onFromSaved,
  }) {
    // Stateful like the server: a reload after a removal no longer has it.
    final packed = List.of(suitcaseItems);
    final client = MockClient((request) async {
      final path = request.url.path;
      requestLog?.add('${request.method} ${path.split('/trip_plans/7').last}');
      if (request.method == 'GET' && path.endsWith('/trip_plans/7/outfits')) {
        await tripLoaded;
        return jsonResponse(
          envelope(_collection(suitcase: packed, outfits: outfits)),
        );
      }
      if (request.method == 'GET' && path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({'overall_advice': null, 'categories': []}),
        );
      }
      if (request.method == 'POST' && path.endsWith('/outfits/generate')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse(
          envelope(
            onGenerate?.call(body) ??
                _collection(suitcase: suitcaseItems, outfits: outfits),
          ),
        );
      }
      if (request.method == 'POST' && path.endsWith('/outfits/from-saved')) {
        return onFromSaved!(jsonDecode(request.body) as Map<String, dynamic>);
      }
      if (request.method == 'POST' && path.endsWith('/suitcase-items')) {
        return jsonResponse(envelope({'suitcase_items': packed}));
      }
      if (request.method == 'DELETE' && path.contains('/suitcase-items/')) {
        final id = int.parse(path.split('/').last);
        packed.removeWhere((g) => g['garment_id'] == id);
        return jsonResponse(envelope({'affected_options': []}));
      }
      return jsonResponse(envelope({}), status: 404);
    });
    return () => client;
  }

  Future<void> removePackedCard(WidgetTester tester, {required int at}) async {
    await tester.tap(find.byIcon(Icons.close).at(at));
    await tester.pumpAndSettle();
    await tester.tap(find.text('REMOVE'));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the packed suitcase items', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Tee'), findsOneWidget);
      expect(find.text('Jeans'), findsOneWidget);
    }, suitcaseClient());
  });

  testWidgets('while the suitcase loads it shows an in-place spinner, not a '
      'full-screen blur over the toolbar\'s back button', (tester) async {
    final tripLoaded = Completer<void>();
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => TripSuitcasePage(trip: _trip()),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // Not pumpAndSettle: the spinner never settles, and settling would
      // run the fake clock into the fetch's 15s timeout.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.byType(LoadingOverlay), findsNothing);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.arrow_back_ios_new_rounded),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );

      tripLoaded.complete();
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AppSpinner), findsNothing);
      expect(find.text('Tee'), findsOneWidget);
    }, suitcaseClient(tripLoaded: tripLoaded.future));
  });

  testWidgets(
    'with the trip detail already cached (opened from Trip Details) it '
    'renders at once without fetching, and writes a removal back to the cache',
    (tester) async {
      final requests = <String>[];
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripSuitcasePage(trip: _trip()),
          overrides: [
            tripDetailProvider.overrideWithBuild(
              (_, _) => TripOutfitCollection(
                suitcase: [
                  _closetGarment(1, 'Tee', GarmentCategory.top),
                  _closetGarment(2, 'Jeans', GarmentCategory.bottom),
                ],
              ),
            ),
          ],
        );
        await tester.pump();

        expect(find.byType(AppSpinner), findsNothing);
        expect(find.text('Tee'), findsOneWidget);
        expect(requests.where((r) => r == 'GET /outfits'), isEmpty);

        await removePackedCard(tester, at: 1);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(TripSuitcasePage)),
        );
        expect(container.read(tripDetailProvider(7)).value!.suitcaseIds, {1});
        expect(requests, contains('DELETE /suitcase-items/2'));
      }, suitcaseClient(suitcaseItems: const [_tee], requestLog: requests));
    },
  );

  testWidgets('an empty suitcase shows the "start packing" state, and its Add '
      'Garments button opens the garment picker', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Start packing your trip'), findsOneWidget);
      expect(find.text('Add Garments'), findsOneWidget);

      await tester.tap(find.byType(AccentPillButton));
      await tester.pumpAndSettle();

      expect(find.text('Select Garments'), findsOneWidget);
    }, suitcaseClient(suitcaseItems: const []));
  });

  group('Add from a Saved Outfit', () {
    final closet = [
      _closetGarment(1, 'Tee', GarmentCategory.top),
      _closetGarment(3, 'Sneakers', GarmentCategory.shoes),
    ];

    Future<void> pumpWithOutfit(WidgetTester tester, Outfit outfit) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        TripSuitcasePage(trip: _trip()),
        overrides: [
          outfitsProvider.overrideWith(() => _FakeOutfits([outfit])),
          garmentsProvider.overrideWith(() => _FakeGarments(closet)),
        ],
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> pickTheOutfit(WidgetTester tester) async {
      await tester.tap(find.text('Add from a Saved Outfit'));
      await tester.pumpAndSettle();
      expect(find.byType(TripOutfitSelectionPage), findsOneWidget);
      await tester.tap(find.byType(OutfitCard));
      await tester.pumpAndSettle();
      expect(find.byType(TripOutfitVersionPage), findsOneWidget);
      await tester.tap(find.text('Add to Trip'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'adds the whole outfit to the trip and packs its missing garments in '
      'one request',
      (tester) async {
        Map<String, dynamic>? sent;
        await http.runWithClient(
          () async {
            await pumpWithOutfit(
              tester,
              Outfit(id: 50, imageUrl: '', garmentIds: const [1, 3]),
            );
            expect(find.text('Add from a Saved Outfit'), findsOneWidget);
            expect(find.text('Sneakers'), findsNothing);

            await pickTheOutfit(tester);

            expect(sent, {'outfit_id': 50});
            expect(find.byType(TripOutfitSelectionPage), findsNothing);
            expect(find.text('Sneakers'), findsOneWidget);
            expect(
              find.text('Added to this trip and packed 1 garments.'),
              findsOneWidget,
            );
            expect(find.text('1 in trip'), findsOneWidget);

            final detail = ProviderScope.containerOf(
              tester.element(find.byType(TripSuitcasePage)),
            ).read(tripDetailProvider(7)).value!;
            expect(detail.outfits.single.sourceOutfitId, 50);
            expect(detail.suitcaseIds, {1, 3});
          },
          suitcaseClient(
            suitcaseItems: const [_tee],
            onFromSaved: (body) async {
              sent = body;
              return jsonResponse(
                envelope(
                  _collection(
                    suitcase: const [_tee, _sneakers],
                    outfits: [
                      _tripOutfit(
                        1,
                        const [_tee, _sneakers],
                        source: 'saved_outfit',
                        sourceOutfitId: 50,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    testWidgets('an outfit whose garments are all packed can still be added', (
      tester,
    ) async {
      var calls = 0;
      await http.runWithClient(
        () async {
          await pumpWithOutfit(
            tester,
            Outfit(id: 51, imageUrl: '', garmentIds: const [1]),
          );
          expect(find.text('Add from a Saved Outfit'), findsOneWidget);

          await pickTheOutfit(tester);

          expect(calls, 1);
          expect(find.text('Added to this trip.'), findsOneWidget);
        },
        suitcaseClient(
          suitcaseItems: const [_tee],
          onFromSaved: (_) async {
            calls++;
            return jsonResponse(
              envelope(
                _collection(
                  suitcase: const [_tee],
                  outfits: [
                    _tripOutfit(
                      1,
                      const [_tee],
                      source: 'saved_outfit',
                      sourceOutfitId: 51,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    });

    testWidgets(
      'the same version already in the trip is reported, not duplicated',
      (tester) async {
        await http.runWithClient(
          () async {
            await pumpWithOutfit(
              tester,
              Outfit(id: 52, imageUrl: '', garmentIds: const [1]),
            );

            await pickTheOutfit(tester);

            expect(find.text('Already added to this trip'), findsOneWidget);
            final detail = ProviderScope.containerOf(
              tester.element(find.byType(TripSuitcasePage)),
            ).read(tripDetailProvider(7)).value!;
            expect(detail.outfits, isEmpty);
          },
          suitcaseClient(
            suitcaseItems: const [_tee],
            onFromSaved: (_) async => jsonResponse({
              'success': false,
              'message': 'dup',
              'data': null,
              'error_code': 'TRIP_OUTFIT_ALREADY_ADDED',
            }, status: 409),
          ),
        );
      },
    );

    testWidgets(
      'staged picks are committed before the outfit is added, so the server '
      'merges into the suitcase the user sees',
      (tester) async {
        final requests = <String>[];
        await http.runWithClient(
          () async {
            useTallSurface(tester);
            await pumpApp(
              tester,
              TripSuitcasePage(trip: _trip()),
              overrides: [
                outfitsProvider.overrideWith(
                  () => _FakeOutfits([
                    Outfit(id: 53, imageUrl: '', garmentIds: const [3]),
                  ]),
                ),
                garmentsProvider.overrideWith(
                  () => _FakeGarments([
                    ...closet,
                    _closetGarment(2, 'Jeans', GarmentCategory.bottom),
                  ]),
                ),
              ],
            );
            await tester.pump();
            await tester.pump();

            // Stage Jeans through the picker.
            await tester.tap(find.byType(ActionDiscButton).last);
            await tester.pumpAndSettle();
            await tester.tap(find.text('Bottom'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Jeans'));
            await tester.pump();
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();

            await pickTheOutfit(tester);

            final posts = requests.where((r) => r.startsWith('POST')).toList();
            expect(posts, ['POST /suitcase-items', 'POST /outfits/from-saved']);
          },
          suitcaseClient(
            suitcaseItems: const [_tee],
            requestLog: requests,
            onFromSaved: (_) async => jsonResponse(
              envelope(_collection(suitcase: const [_tee, _jeans, _sneakers])),
            ),
          ),
        );
      },
    );
  });

  group('plan / find more', () {
    const viableSuitcase = [_tee, _jeans, _sneakers];
    // Removing the extra item changes the packed set but stays viable.
    const viableSuitcaseWithExtra = [...viableSuitcase, _cap];
    final existingOutfits = [
      _tripOutfit(1, const [_tee, _jeans, _sneakers]),
    ];

    testWidgets(
      'shows "Plan Trip Outfits" once the suitcase can build a complete '
      'outfit, with no outfits yet',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          expect(find.text('Plan Trip Outfits'), findsOneWidget);
        }, suitcaseClient(suitcaseItems: viableSuitcase));
      },
    );

    testWidgets(
      'hides the button while the suitcase cannot build a complete outfit',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          // Default suitcaseItems: top + bottom, no shoes -> not viable.
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          expect(
            find.byKey(const ValueKey('bottomActionButton-hidden')),
            findsOneWidget,
          );
        }, suitcaseClient());
      },
    );

    testWidgets(
      'with outfits already planned, the button stays hidden until the '
      'suitcase changes, then offers "Add AI Outfits"',
      (tester) async {
        await http.runWithClient(
          () async {
            useTallSurface(tester);
            await pumpApp(tester, TripSuitcasePage(trip: _trip()));
            await tester.pump();
            await tester.pump();
            expect(
              find.byKey(const ValueKey('bottomActionButton-hidden')),
              findsOneWidget,
            );

            await removePackedCard(tester, at: 3); // Cap sorts last

            expect(find.text('Add AI Outfits'), findsOneWidget);
          },
          suitcaseClient(
            suitcaseItems: viableSuitcaseWithExtra,
            outfits: existingOutfits,
          ),
        );
      },
    );

    testWidgets(
      'tapping "Plan Trip Outfits" asks for a plan, applies the collection '
      'and pops back',
      (tester) async {
        final modes = <Object?>[];
        await http.runWithClient(
          () async {
            useTallSurface(tester);
            await pumpApp(
              tester,
              Scaffold(body: const Text('Behind the Suitcase page')),
            );
            final navigator = tester.state<NavigatorState>(
              find.byType(Navigator),
            );
            navigator.push(
              MaterialPageRoute(
                builder: (_) => TripSuitcasePage(trip: _trip()),
              ),
            );
            await tester.pumpAndSettle();

            await tester.tap(find.text('Plan Trip Outfits'));
            await tester.pumpAndSettle();

            expect(modes, ['plan']);
            expect(find.byType(TripSuitcasePage), findsNothing);
            expect(find.text('Behind the Suitcase page'), findsOneWidget);
            expect(find.text('Added 2 new outfits.'), findsOneWidget);
            final detail = ProviderScope.containerOf(
              tester.element(find.text('Behind the Suitcase page')),
            ).read(tripDetailProvider(7)).value!;
            expect(detail.outfits, hasLength(2));
          },
          suitcaseClient(
            suitcaseItems: viableSuitcase,
            onGenerate: (body) {
              modes.add(body['mode']);
              return _collection(
                suitcase: viableSuitcase,
                outfits: [
                  _tripOutfit(1, const [_tee, _jeans, _sneakers]),
                  _tripOutfit(2, const [_tee, _jeans]),
                ],
                generatedCount: 2,
              );
            },
          ),
        );
      },
    );

    testWidgets('"Add AI Outfits" asks for more without a confirm (nothing is '
        'replaced), and says so when nothing new fits', (tester) async {
      final modes = <Object?>[];
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpApp(tester, const Scaffold(body: Text('Trip Details')));
          tester
              .state<NavigatorState>(find.byType(Navigator))
              .push(
                MaterialPageRoute(
                  builder: (_) => TripSuitcasePage(trip: _trip()),
                ),
              );
          await tester.pumpAndSettle();
          await removePackedCard(tester, at: 3);

          await tester.tap(find.text('Add AI Outfits'));
          await tester.pumpAndSettle();

          expect(modes, ['more']);
          expect(
            find.text(
              'No more suitable combinations found with your current '
              'suitcase.',
            ),
            findsOneWidget,
          );
        },
        suitcaseClient(
          suitcaseItems: viableSuitcaseWithExtra,
          outfits: existingOutfits,
          onGenerate: (body) {
            modes.add(body['mode']);
            return _collection(
              suitcase: viableSuitcase,
              outfits: existingOutfits,
            );
          },
        ),
      );
    });
  });

  testWidgets(
    'removing a garment two outfits use keeps both outfits (marked missing) '
    'and never asks the AI for anything',
    (tester) async {
      final requests = <String>[];
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          await removePackedCard(tester, at: 0); // Tee

          final detail = ProviderScope.containerOf(
            tester.element(find.byType(TripSuitcasePage)),
          ).read(tripDetailProvider(7)).value!;
          expect(detail.outfits, hasLength(2));
          for (final o in detail.outfits) {
            expect(o.missingGarments(detail.suitcaseIds).map((g) => g.id), [1]);
          }
          expect(requests.where((r) => r.contains('/generate')), isEmpty);
        },
        suitcaseClient(
          suitcaseItems: const [_tee, _jeans, _sneakers],
          requestLog: requests,
          outfits: [
            _tripOutfit(1, const [_tee, _jeans, _sneakers]),
            _tripOutfit(2, const [_tee, _sneakers]),
          ],
        ),
      );
    },
  );

  group('state stays in step with the server after a failure', () {
    Future<http.Response> commonResponse(http.Request request) async {
      if (request.url.path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({'overall_advice': null, 'categories': []}),
        );
      }
      return jsonResponse(envelope({}), status: 404);
    }

    testWidgets('a failed removal puts back only that garment, not one '
        'removed successfully meanwhile', (tester) async {
      final jeansDelete = Completer<http.Response>();
      final packed = [_tee, _jeans, _sneakers];
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/trip_plans/7/outfits')) {
          return jsonResponse(envelope(_collection(suitcase: packed)));
        }
        if (request.method == 'DELETE' &&
            request.url.path.endsWith('/suitcase-items/2')) {
          return jeansDelete.future;
        }
        if (request.method == 'DELETE' &&
            request.url.path.endsWith('/suitcase-items/1')) {
          packed.remove(_tee);
          return jsonResponse(envelope({'affected_options': []}));
        }
        return commonResponse(request);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(tester, TripSuitcasePage(trip: _trip()));
        await tester.pump();
        await tester.pump();

        // Jeans first (left in flight), then Tee (succeeds).
        await removePackedCard(tester, at: 1);
        expect(find.text('Jeans'), findsNothing);
        await removePackedCard(tester, at: 0);
        expect(find.text('Tee'), findsNothing);

        jeansDelete.complete(jsonResponse(envelope(null), status: 500));
        await tester.pumpAndSettle();

        expect(find.text('Jeans'), findsOneWidget);
        expect(find.text('Tee'), findsNothing);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TripSuitcasePage)),
        );
        expect(container.read(tripDetailProvider(7)).value!.suitcaseIds, {
          2,
          3,
        });
      }, () => client);
    });

    testWidgets('a failed commit keeps every staged garment, and the retry '
        'sends them again in one request', (tester) async {
      final posted = <List<int>>[];
      var failNext = true;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path.endsWith('/trip_plans/7/outfits')) {
          return jsonResponse(envelope(_collection(suitcase: const [_tee])));
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/suitcase-items')) {
          final ids = ((jsonDecode(request.body) as Map)['garment_ids'] as List)
              .cast<int>();
          posted.add(ids);
          if (failNext) {
            failNext = false;
            return jsonResponse(envelope(null), status: 500);
          }
          return jsonResponse(
            envelope({
              'suitcase_items': [_tee, _jeans, _sneakers],
            }),
          );
        }
        return commonResponse(request);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripSuitcasePage(trip: _trip()),
          overrides: [
            garmentsProvider.overrideWith(
              () => _FakeGarments([
                _closetGarment(1, 'Tee', GarmentCategory.top),
                _closetGarment(2, 'Jeans', GarmentCategory.bottom),
                _closetGarment(3, 'Sneakers', GarmentCategory.shoes),
              ]),
            ),
          ],
        );
        await tester.pump();
        await tester.pump();

        // Stage Jeans + Sneakers through the picker.
        await tester.tap(find.byType(ActionDiscButton).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Bottom'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jeans'));
        await tester.pump();
        await tester.tap(find.text('Shoes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sneakers'));
        await tester.pump();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        // Leaving commits; the request fails and nothing is recorded.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TripSuitcasePage)),
        );
        expect(container.read(tripDetailProvider(7)).value!.suitcaseIds, {1});
        expect(find.text('Jeans'), findsOneWidget);
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(posted, hasLength(2));
        expect(posted.last.toSet(), {2, 3});
        expect(find.byType(TripSuitcasePage), findsNothing);
      }, () => client);
    });
  });
}
