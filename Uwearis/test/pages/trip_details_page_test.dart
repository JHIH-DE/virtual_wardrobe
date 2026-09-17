import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/trip_plan.dart';
import 'package:uwearis/features/pages/trip_details_page.dart';
import 'package:uwearis/features/pages/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/trip/trip_day_card.dart';

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

Garment _garment(int id, {GarmentCategory category = GarmentCategory.top}) =>
    Garment(
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

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // getTripSuggestion (packing-analysis) is the only initState call as long
  // as the preloaded plan carries no stale image URLs and no push/pop
  // touches _fetchSuitcaseGarments/_refreshTripPlan (see the dedicated
  // regression test below for that pair).
  http.Client packingAdviceClient({int recommendedTotal = 6}) {
    return MockClient((request) async {
      if (request.url.path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({
            'overall_advice': 'Layer up for the evenings.',
            'categories': [
              {'category': 'Top', 'recommended_quantity': recommendedTotal},
            ],
          }),
        );
      }
      return jsonResponse(envelope({}), status: 404);
    });
  }

  testWidgets('renders the trip header and suitcase section', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
      );
      await tester.pump(); // let _loadPackingAnalysis resolve
      await tester.pump();

      expect(find.text('Kyoto Autumn'), findsOneWidget);
      // Destinations header + the selected day's city subtitle.
      expect(find.text('Kyoto'), findsWidgets);
      expect(find.text('Suitcase'), findsOneWidget);
      // The outfit-advice card lives on the Suitcase page now, not here.
      expect(find.text('Layer up for the evenings.'), findsNothing);
    }, packingAdviceClient);
  });

  // Planning/updating the trip's outfits is TripSuitcasePage's job now (see
  // trip_suitcase_page_test.dart) — without a plan yet, this page's only
  // entry point into that flow is the wardrobe section's CTA card.
  testWidgets(
    'with no plan, the wardrobe section offers a CTA that opens the Suitcase '
    'page',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);

        await tester.tap(find.text('Plan Trip Outfits'));
        await tester.pumpAndSettle();

        expect(find.byType(TripSuitcasePage), findsOneWidget);
      }, packingAdviceClient);
    },
  );

  testWidgets('a generated plan renders the Daily Outfit Plan card', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      final plan = TripPlan(
        suitcaseIds: {1},
        days: [
          TripDayOutfit(
            date: DateTime(2026, 11, 1),
            optionId: 10,
            garments: [_garment(1)],
          ),
        ],
      );
      await pumpApp(tester, TripDetailsPage(trip: _trip(), initialData: plan));
      await tester.pump();
      await tester.pump();

      expect(find.text('Daily Outfit Plan'), findsOneWidget);
    }, packingAdviceClient);
  });

  testWidgets('with no plan the outfit image card is hidden', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        TripDetailsPage(
          trip: _trip(),
          initialData: TripPlan(suitcaseIds: {1, 2, 3, 4, 5, 6}),
        ),
      );
      await tester.pump();
      await tester.pump();

      // No "no image / no outfit planned" empty state before a plan exists.
      expect(find.text('No outfit image yet'), findsNothing);
      expect(find.text('No outfit planned yet'), findsNothing);
      expect(find.text('Generate Outfit'), findsNothing);
    }, packingAdviceClient);
  });

  // Regression: a day with no option of its own (e.g. a leg added after the
  // rest of the trip already had a plan) used to show both this card's own
  // "No outfit planned yet" text AND the wardrobe section's "Let Uwearis
  // Plan Your Trip" CTA right underneath — the same message twice. Only the
  // actionable CTA should show.
  testWidgets(
    "a day with no option of its own shows only the wardrobe section's plan "
    'CTA, not a redundant "No outfit planned yet" card',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        final plan = TripPlan(
          suitcaseIds: {1},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [_garment(1)],
            ),
            TripDayOutfit(date: DateTime(2026, 11, 2)),
          ],
        );
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: plan),
        );
        await tester.pump();
        await tester.pump();

        // Still on day 1 (has an option) — the CTA shouldn't show yet.
        expect(find.text('Let Uwearis Plan Your Trip'), findsNothing);

        await tester.tap(find.byType(TripDayCard).at(1));
        await tester.pump();

        expect(find.text('No outfit planned yet'), findsNothing);
        expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);
      }, packingAdviceClient);
    },
  );

  testWidgets('a planned but unrendered day shows a Generate Outfit button', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      final plan = TripPlan(
        suitcaseIds: {1},
        days: [
          TripDayOutfit(
            date: DateTime(2026, 11, 1),
            optionId: 10,
            garments: [_garment(1)],
          ),
        ],
      );
      await pumpApp(tester, TripDetailsPage(trip: _trip(), initialData: plan));
      await tester.pump();
      await tester.pump();

      // The per-day action is a button on the card, not on a bottom bar.
      expect(find.text('Generate Outfit'), findsOneWidget);
      expect(find.text('No outfit image yet'), findsNothing);
    }, packingAdviceClient);
  });

  // Regression/new behavior: the button is now always shown once a day has
  // an option and no render yet — it's disabled (not hidden) when the day's
  // own garments don't cover Top/Bottom/Shoes, with an explanation above it.
  testWidgets(
    'a day missing a core category (only a Top here) disables Generate '
    'Outfit and explains why',
    (tester) async {
      var generateRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/packing-analysis')) {
          return jsonResponse(
            envelope({'overall_advice': null, 'categories': []}),
          );
        }
        if (request.method == 'POST' && request.url.path.endsWith('/outfits')) {
          generateRequests++;
          return jsonResponse(envelope({}));
        }
        return jsonResponse(envelope({}), status: 404);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        final plan = TripPlan(
          suitcaseIds: {1},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [_garment(1, category: GarmentCategory.top)],
            ),
          ],
        );
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: plan),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Generate Outfit'), findsOneWidget);
        expect(
          find.text(
            'This outfit is missing a Top, Bottom, or Shoes item — '
            'complete it to generate an outfit.',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Generate Outfit'));
        await tester.pump();
        expect(
          generateRequests,
          0,
          reason: 'the disabled button must ignore taps',
        );
      }, () => client);
    },
  );

  testWidgets(
    'a day covering Top, Bottom, and Shoes keeps Generate Outfit enabled, '
    'no explanation shown',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        final plan = TripPlan(
          suitcaseIds: {1, 2, 3},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [
                _garment(1, category: GarmentCategory.top),
                _garment(2, category: GarmentCategory.bottom),
                _garment(3, category: GarmentCategory.shoes),
              ],
            ),
          ],
        );
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: plan),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Generate Outfit'), findsOneWidget);
        expect(
          find.text(
            'This outfit is missing a Top, Bottom, or Shoes item — '
            'complete it to generate an outfit.',
          ),
          findsNothing,
        );
      }, packingAdviceClient);
    },
  );

  testWidgets(
    'a one-piece counts for both Top and Bottom, so Top+Shoes+one-piece is '
    'a complete core outfit',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        final plan = TripPlan(
          suitcaseIds: {1, 2},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [
                _garment(1, category: GarmentCategory.onePiece),
                _garment(2, category: GarmentCategory.shoes),
              ],
            ),
          ],
        );
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: plan),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text(
            'This outfit is missing a Top, Bottom, or Shoes item — '
            'complete it to generate an outfit.',
          ),
          findsNothing,
        );
      }, packingAdviceClient);
    },
  );

  // New behavior: Edit Destinations' Save button (AppDialog's onPrimary)
  // stays disabled until the legs actually differ from what the dialog
  // opened with — mirrors the rename dialog's "no-op has nothing to save"
  // gating (see showTextInputDialog).
  testWidgets('Edit Destinations: Save starts disabled, enables once a leg is '
      'removed, and persists the change', (tester) async {
    late http.Request capturedPatch;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({'overall_advice': null, 'categories': []}),
        );
      }
      if (request.method == 'PATCH' && request.url.path.endsWith('/7')) {
        capturedPatch = request;
        return jsonResponse(envelope({}));
      }
      return jsonResponse(envelope({}), status: 404);
    });

    await http.runWithClient(() async {
      useTallSurface(tester);
      final trip = Trip(
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
      await pumpApp(
        tester,
        TripDetailsPage(trip: trip, initialData: const TripPlan()),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      // AppPopupMenu's item Row hard-caps at ~196px (its own maxWidth:220
      // minus padding — see app_popup_menu.dart); "Edit Destinations" only
      // fits that in the app's real bundled NotoSansTC font, which
      // `flutter test` doesn't load, so its fallback-font metrics render
      // this one label a hair wider and trip a RenderFlex overflow here
      // that doesn't reproduce in the running app. Drain it so it doesn't
      // fail this test.
      while (tester.takeException() != null) {}
      await tester.tap(find.text('Edit Destinations'));
      await tester.pumpAndSettle();

      Finder saveButtonFinder() => find.byType(ElevatedButton).last;
      ElevatedButton saveButton() =>
          tester.widget<ElevatedButton>(saveButtonFinder());

      expect(saveButton().onPressed, isNull);

      // Removing the second leg (Osaka) — with 2 legs, both rows' remove
      // badges are enabled; the first leg's stays disabled only once a
      // single leg remains.
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pump();

      expect(saveButton().onPressed, isNotNull);

      await tester.tap(saveButtonFinder());
      await tester.pumpAndSettle();

      final body = jsonDecode(capturedPatch.body) as Map<String, dynamic>;
      final legs = body['legs'] as List;
      expect(legs, hasLength(1));
      expect(legs.single['location'], 'Kyoto');
    }, () => client);
  });

  // Regression test for the just-created-trip flow: TripsPage.handleCreateTrip
  // pushes TripSuitcasePage directly on top of this (already-pushed,
  // background) page — never through _openSuitcase — so only [didPopNext]
  // can catch the return. Plan generation itself now happens on that page,
  // so this exercises _refreshTripPlan (not just _fetchSuitcaseGarments,
  // covered by [_TripDetailsPageState._fetchSuitcaseGarments]'s own doc
  // comment / the suitcase-ids it feeds elsewhere).
  testWidgets(
    'popping back from a Suitcase page pushed directly on top of this page '
    '(the just-created-trip flow) refreshes the trip plan',
    (tester) async {
      // Toggled to simulate the plan having been generated while the user
      // was on the (directly-pushed) Suitcase page.
      var planGenerated = false;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/packing-analysis')) {
          return jsonResponse(
            envelope({'overall_advice': null, 'categories': []}),
          );
        }
        if (request.method == 'GET' && request.url.path.endsWith('/plan')) {
          if (!planGenerated) {
            return jsonResponse(envelope({'days': [], 'suitcase_items': []}));
          }
          return jsonResponse(
            envelope({
              'days': [
                {
                  'date': '2026-11-01',
                  'options': [
                    {
                      'id': 10,
                      'order_index': 0,
                      'items': [
                        {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
                      ],
                    },
                  ],
                },
              ],
              'suitcase_items': [
                {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
              ],
            }),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/trip_plans/7')) {
          return jsonResponse(
            envelope({
              'suitcase_items': [
                {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
              ],
            }),
          );
        }
        return jsonResponse(envelope({}), status: 404);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);

        // Mirrors TripsPage.handleCreateTrip: push the Suitcase page
        // straight onto the navigator, not via TripDetailsPage's own
        // _openSuitcase.
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip())),
        );
        await tester.pumpAndSettle();

        // As if TripSuitcasePage's own "Plan Trip Outfits" button just
        // generated the plan and popped back.
        planGenerated = true;
        navigator.pop();
        await tester.pump();
        await tester.pump();

        expect(find.text('Generate Outfit'), findsOneWidget);
        expect(find.text('Let Uwearis Plan Your Trip'), findsNothing);
      }, () => client);
    },
  );

  // Regression: didPopNext used to unconditionally call _refreshTripPlan on
  // *every* pop, including popping back from the day outfit editor —
  // exactly when _openDayOutfitEditor was about to send its own
  // updateOptionItems PATCH. Whichever response landed last won, so the
  // stale GET /plan could overwrite the just-applied edit; the edit only
  // "stuck" after leaving and re-entering the page. _skipPlanRefreshOnNextPop
  // suppresses that one refetch for this specific round trip.
  testWidgets(
    'changing a day\'s garments sends the update and does not race a stale '
    'trip-plan refetch',
    (tester) async {
      var planRequests = 0;
      late http.Request capturedPatch;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/packing-analysis')) {
          return jsonResponse(
            envelope({'overall_advice': null, 'categories': []}),
          );
        }
        if (request.method == 'GET' && request.url.path.endsWith('/plan')) {
          planRequests++;
          return jsonResponse(envelope({'days': [], 'suitcase_items': []}));
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/trip_plans/7')) {
          return jsonResponse(
            envelope({
              'suitcase_items': [
                {'garment_id': 1, 'name': 'Item 1', 'category': 'Top'},
                {'garment_id': 2, 'name': 'Item 2', 'category': 'Top'},
              ],
            }),
          );
        }
        if (request.method == 'PATCH' && request.url.path.endsWith('/items')) {
          capturedPatch = request;
          return jsonResponse(
            envelope({
              'items': [
                {'garment_id': 2, 'name': 'Item 2', 'category': 'Top'},
              ],
            }),
          );
        }
        return jsonResponse(envelope({}), status: 404);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        final plan = TripPlan(
          suitcaseIds: {1, 2},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [_garment(1)],
            ),
          ],
        );
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: plan),
        );
        await tester.pump();
        await tester.pump();

        // "Change Garments" pencil — opens OutfitEditPage.
        await tester.tap(find.byIcon(Icons.edit_outlined));
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        // Tap the existing "Item 1" card (OutfitEditPage shows names, unlike
        // TripDetailsPage's own image-only thumbnails) to swap it, then pick
        // "Item 2".
        await tester.tap(find.text('Item 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Item 2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pump();
        await tester.pump();

        // The swap actually went through with the new selection...
        expect(capturedPatch.method, 'PATCH');
        expect(jsonDecode(capturedPatch.body), {
          'garment_ids': [2],
        });
        // ...and nothing raced it: the day editor round trip must not have
        // triggered the stale-plan refetch that used to overwrite this.
        expect(
          planRequests,
          0,
          reason: 'the day editor round trip should skip _refreshTripPlan',
        );
      }, () => client);
    },
  );

  // TripDetailsPage's own Replan entry point — the Daily Outfit Plan
  // title's refresh icon. Unlike TripSuitcasePage's bottom button, this
  // doesn't require the suitcase to have changed; it shares the same
  // confirm dialog and the same TripDayOutfit.needsReplan/daysToReplan
  // policy (see _replanPlan's doc comment).
  group('the Daily Outfit Plan refresh icon (Replan)', () {
    testWidgets('only shows once a trip plan actually exists', (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripDetailsPage(trip: _trip(), initialData: const TripPlan()),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byIcon(Icons.autorenew), findsNothing);
      }, packingAdviceClient);
    });

    testWidgets(
      'confirming replans only the days that need it, then refreshes in '
      'place',
      (tester) async {
        http.Request? capturedGenerate;
        var planRefetches = 0;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/packing-analysis')) {
            return jsonResponse(
              envelope({'overall_advice': null, 'categories': []}),
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/generate')) {
            capturedGenerate = request;
            return jsonResponse(envelope({'days': [], 'suitcase_items': []}));
          }
          if (request.method == 'GET' && request.url.path.endsWith('/plan')) {
            planRefetches++;
            return jsonResponse(
              envelope({
                'days': [
                  {
                    'date': '2026-11-01',
                    'options': [
                      {
                        'id': 10,
                        'order_index': 0,
                        'is_manually_edited': true,
                        'items': [
                          {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
                        ],
                      },
                    ],
                  },
                  {
                    'date': '2026-11-02',
                    'options': [
                      {
                        'id': 11,
                        'order_index': 0,
                        'is_manually_edited': false,
                        'items': [
                          {
                            'garment_id': 2,
                            'name': 'Jeans',
                            'category': 'bottom',
                          },
                        ],
                      },
                    ],
                  },
                ],
                'suitcase_items': [
                  {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
                  {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
                ],
              }),
            );
          }
          return jsonResponse(envelope({}), status: 404);
        });

        await http.runWithClient(() async {
          useTallSurface(tester);
          final plan = TripPlan(
            suitcaseIds: {1, 2},
            days: [
              // Manually edited, garment still packed -> keep.
              TripDayOutfit(
                date: DateTime(2026, 11, 1),
                optionId: 10,
                garments: [_garment(1, category: GarmentCategory.top)],
                isManuallyEdited: true,
              ),
              // AI-generated, never touched, never rendered -> regenerate.
              TripDayOutfit(
                date: DateTime(2026, 11, 2),
                optionId: 11,
                garments: [_garment(2, category: GarmentCategory.bottom)],
              ),
            ],
          );
          await pumpApp(
            tester,
            TripDetailsPage(trip: _trip(), initialData: plan),
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(find.byIcon(Icons.autorenew));
          await tester.pumpAndSettle();
          expect(find.text('Replan trip outfits?'), findsOneWidget);
          await tester.tap(find.text('Replan'));
          await tester.pumpAndSettle();

          expect(capturedGenerate, isNotNull);
          final body =
              jsonDecode(capturedGenerate!.body) as Map<String, dynamic>;
          expect(body['days'], [
            {'date': '2026-11-02'},
          ]);
          // Refreshed in place — no navigation, no pop.
          expect(find.byType(TripDetailsPage), findsOneWidget);
          expect(planRefetches, 1);
        }, () => client);
      },
    );

    testWidgets(
      'nothing needs replanning: generate is never called, and a plain '
      'message says so',
      (tester) async {
        var generateCalls = 0;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/packing-analysis')) {
            return jsonResponse(
              envelope({'overall_advice': null, 'categories': []}),
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/generate')) {
            generateCalls++;
            return jsonResponse(envelope({'days': [], 'suitcase_items': []}));
          }
          return jsonResponse(envelope({}), status: 404);
        });

        await http.runWithClient(() async {
          useTallSurface(tester);
          final plan = TripPlan(
            suitcaseIds: {1},
            days: [
              // Manually edited, garment still packed -> keep.
              TripDayOutfit(
                date: DateTime(2026, 11, 1),
                optionId: 10,
                garments: [_garment(1, category: GarmentCategory.top)],
                isManuallyEdited: true,
              ),
            ],
          );
          await pumpApp(
            tester,
            TripDetailsPage(trip: _trip(), initialData: plan),
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(find.byIcon(Icons.autorenew));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Replan'));
          await tester.pumpAndSettle();

          expect(generateCalls, 0);
          expect(
            find.text(
              'Nothing to replan — every outfit still fits your suitcase.',
            ),
            findsOneWidget,
          );
        }, () => client);
      },
    );
  });
}
