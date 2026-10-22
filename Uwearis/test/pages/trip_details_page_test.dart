import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/features/widgets/common/cards/app_list_card.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/core/providers/trip_detail_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/data/trip_plan.dart';
import 'package:uwearis/features/pages/trip_details_page.dart';
import 'package:uwearis/features/pages/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/common/cards/generated_image_card.dart';
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

TripDetail _detail({
  Set<int> suitcaseIds = const {},
  List<TripDayOutfit> days = const [],
}) => TripDetail(
  days: days,
  suitcase: [for (final id in suitcaseIds) _garment(id)],
);

/// Pumps [TripDetailsPage] with [tripDetailProvider] already holding
/// [detail] — what `openTripDetails` guarantees before pushing it.
Future<void> pumpDetails(
  WidgetTester tester, {
  Trip? trip,
  TripDetail detail = const TripDetail(),
}) {
  return pumpApp(
    tester,
    TripDetailsPage(trip: trip ?? _trip()),
    overrides: [tripDetailProvider.overrideWithBuild((_, _) => detail)],
  );
}

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

  // Packing analysis is the only initState request while the seeded detail
  // has no stale image URLs (those trigger a background reload).
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
      await pumpDetails(tester, trip: _trip(), detail: const TripDetail());
      await tester.pump(); // let _loadPackingAnalysis resolve
      await tester.pump();

      expect(find.text('Kyoto Autumn'), findsOneWidget);
      // Destinations header + the selected day's city subtitle.
      expect(find.text('Kyoto'), findsWidgets);
      expect(find.text('Suitcase'), findsOneWidget);
      // The outfit-advice card belongs to the Suitcase page.
      expect(find.text('Layer up for the evenings.'), findsNothing);
    }, packingAdviceClient);
  });

  testWidgets('the Suitcase card shows the packed count as its status, with '
      'no recommended / selected summary', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(
        tester,
        trip: _trip(),
        detail: _detail(suitcaseIds: {1, 2, 3}),
      );
      await tester.pump();
      await tester.pump();

      final card = find.ancestor(
        of: find.text('Suitcase'),
        matching: find.byType(AppListCard),
      );
      expect(
        find.descendant(of: card, matching: find.text('3 items')),
        findsOneWidget,
      );
      expect(find.textContaining('Recommended'), findsNothing);
      expect(find.textContaining('Packed'), findsNothing);
    }, packingAdviceClient);
  });

  testWidgets('an empty suitcase keeps the packing hint and no count', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(tester, trip: _trip(), detail: const TripDetail());
      await tester.pump();
      await tester.pump();

      final card = find.ancestor(
        of: find.text('Suitcase'),
        matching: find.byType(AppListCard),
      );
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(RegExp(r'\d+ items?$')),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.text('Pack clothing for this trip'),
        ),
        findsOneWidget,
      );
    }, packingAdviceClient);
  });

  // Without a plan, the wardrobe CTA is this page's only way into planning.
  testWidgets(
    'with no plan, the wardrobe section offers a CTA that opens the Suitcase '
    'page',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(tester, trip: _trip(), detail: const TripDetail());
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
      final plan = _detail(
        suitcaseIds: {1},
        days: [
          TripDayOutfit(
            date: DateTime(2026, 11, 1),
            optionId: 10,
            garments: [_garment(1)],
          ),
        ],
      );
      await pumpDetails(tester, trip: _trip(), detail: plan);
      await tester.pump();
      await tester.pump();

      expect(find.text('Daily Outfit Plan'), findsOneWidget);
    }, packingAdviceClient);
  });

  testWidgets(
    'Change Garments sits beside OUTFIT ITEMS, and stays reachable for a '
    'planned day with no items yet',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: _detail(
            suitcaseIds: {1},
            days: [TripDayOutfit(date: DateTime(2026, 11, 1), optionId: 10)],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('OUTFIT ITEMS'), findsOneWidget);
        expect(find.text('No items planned'), findsOneWidget);
        final row = find.ancestor(
          of: find.text('OUTFIT ITEMS'),
          matching: find.byType(Row),
        );
        final edit = find.descendant(
          of: row,
          matching: find.widgetWithText(TextButton, 'Edit'),
        );
        expect(edit, findsOneWidget);
        // The pill sits flush with the row's right edge.
        expect(
          find.ancestor(of: edit, matching: find.byType(AccentPillButton)),
          findsOneWidget,
        );
        expect(tester.getRect(edit).right, tester.getRect(row.first).right);
      }, packingAdviceClient);
    },
  );

  testWidgets('with no plan the outfit image card is hidden', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(
        tester,
        trip: _trip(),
        detail: _detail(suitcaseIds: {1, 2, 3, 4, 5, 6}),
      );
      await tester.pump();
      await tester.pump();

      // No "no image / no outfit planned" empty state before a plan exists.
      expect(find.text('No outfit image yet'), findsNothing);
      expect(find.text('No outfit planned yet'), findsNothing);
      expect(find.text('Generate Outfit'), findsNothing);
    }, packingAdviceClient);
  });

  // A day with no option (e.g. a leg added after planning) shows only the
  // CTA, not also the card's own "No outfit planned yet".
  testWidgets(
    "a day with no option of its own shows only the wardrobe section's plan "
    'CTA, not a redundant "No outfit planned yet" card',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        final plan = _detail(
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
        await pumpDetails(tester, trip: _trip(), detail: plan);
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
      final plan = _detail(
        suitcaseIds: {1},
        days: [
          TripDayOutfit(
            date: DateTime(2026, 11, 1),
            optionId: 10,
            garments: [_garment(1)],
          ),
        ],
      );
      await pumpDetails(tester, trip: _trip(), detail: plan);
      await tester.pump();
      await tester.pump();

      // The per-day action is a button on the card, not on a bottom bar.
      expect(find.text('Generate Outfit'), findsOneWidget);
      expect(find.text('No outfit image yet'), findsNothing);
    }, packingAdviceClient);
  });

  testWidgets(
    'an unrendered day has no image card and no date/city header — its '
    'Generate Outfit button sits under the garment thumbnails',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: _detail(
            suitcaseIds: {1},
            days: [
              TripDayOutfit(
                date: DateTime(2026, 11, 1),
                optionId: 10,
                garments: [_garment(1)],
              ),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(GeneratedImageCard), findsNothing);
        expect(find.textContaining('Outfit for'), findsNothing);
        expect(find.byIcon(Icons.location_on_outlined), findsNothing);
        expect(
          tester.getTopLeft(find.text('Generate Outfit')).dy,
          greaterThan(tester.getBottomLeft(find.text('OUTFIT ITEMS')).dy),
        );
      }, packingAdviceClient);
    },
  );

  testWidgets('a rendered day shows its image card under the garments and no '
      'Generate button', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpDetails(
        tester,
        detail: _detail(
          suitcaseIds: {1},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [_garment(1)],
              outfitId: 5,
              resultImageUrl: 'https://example.com/outfit.jpg',
              everHadOutfit: true,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(GeneratedImageCard), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(GeneratedImageCard)).dy,
        greaterThan(tester.getBottomLeft(find.text('OUTFIT ITEMS')).dy),
        reason: 'the image sits under the garment thumbnails',
      );
      expect(find.text('Generate Outfit'), findsNothing);
      expect(find.text('Regenerate Outfit'), findsNothing);
    }, packingAdviceClient);
  });

  // Disabled (not hidden), with an explanation, when the day's garments
  // don't cover Top/Bottom/Shoes.
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
        final plan = _detail(
          suitcaseIds: {1},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [_garment(1, category: GarmentCategory.top)],
            ),
          ],
        );
        await pumpDetails(tester, trip: _trip(), detail: plan);
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
        final plan = _detail(
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
        await pumpDetails(tester, trip: _trip(), detail: plan);
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
        final plan = _detail(
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
        await pumpDetails(tester, trip: _trip(), detail: plan);
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

  // Save stays disabled until the legs differ from what the dialog opened
  // with.
  testWidgets('Edit Itinerary: Save starts disabled, enables once a leg is '
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
      await pumpDetails(tester, trip: trip, detail: const TripDetail());
      await tester.pump();
      await tester.pump();

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

      final body = jsonDecode(capturedPatch.body) as Map<String, dynamic>;
      final legs = body['legs'] as List;
      expect(legs, hasLength(1));
      expect(legs.single['location'], 'Kyoto');
    }, () => client);
  });

  // TripsPage.handleCreateTrip pushes TripSuitcasePage directly, not via
  // _openSuitcase; the plan reaches this page through tripDetailProvider.
  testWidgets(
    'a plan generated on a Suitcase page pushed directly on top of this page '
    '(the just-created-trip flow) shows up on return',
    (tester) async {
      var tripRequests = 0;
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/packing-analysis')) {
          return jsonResponse(
            envelope({'overall_advice': null, 'categories': []}),
          );
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/generate')) {
          return jsonResponse(envelope({'days': [], 'suitcase_items': []}));
        }
        if (request.method == 'GET' && request.url.path.endsWith('/plan')) {
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
              'suitcase_items': [],
            }),
          );
        }
        if (request.method == 'GET' &&
            request.url.path.endsWith('/trip_plans/7')) {
          tripRequests++;
          return jsonResponse(envelope({'suitcase_items': []}));
        }
        return jsonResponse(envelope({}), status: 404);
      });

      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(
          tester,
          detail: TripDetail(
            suitcase: [
              _garment(1, category: GarmentCategory.top),
              _garment(2, category: GarmentCategory.bottom),
              _garment(3, category: GarmentCategory.shoes),
            ],
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Let Uwearis Plan Your Trip'), findsOneWidget);

        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip())),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Plan Trip Outfits'));
        await tester.pumpAndSettle();

        expect(find.byType(TripSuitcasePage), findsNothing);
        expect(find.text('Generate Outfit'), findsOneWidget);
        expect(find.text('Let Uwearis Plan Your Trip'), findsNothing);
        expect(
          tripRequests,
          0,
          reason: 'the Suitcase page renders the cached suitcase',
        );
      }, () => client);
    },
  );

  // Nothing may be re-fetched on return: a GET /plan racing the PATCH could
  // land last and overwrite the edit.
  testWidgets(
    'changing a day\'s garments sends the update without re-fetching the plan '
    'or the suitcase',
    (tester) async {
      var planRequests = 0;
      var tripRequests = 0;
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
          tripRequests++;
          return jsonResponse(envelope({'suitcase_items': []}));
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
        final plan = _detail(
          suitcaseIds: {1, 2},
          days: [
            TripDayOutfit(
              date: DateTime(2026, 11, 1),
              optionId: 10,
              garments: [_garment(1)],
            ),
          ],
        );
        await pumpDetails(tester, trip: _trip(), detail: plan);
        await tester.pump();
        await tester.pump();

        await tester.tap(find.widgetWithText(TextButton, 'Edit'));
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        // Swap "Item 1" for "Item 2".
        await tester.tap(find.text('Item 1'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Item 2'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirm'));
        await tester.pump();
        await tester.pump();

        expect(capturedPatch.method, 'PATCH');
        expect(jsonDecode(capturedPatch.body), {
          'garment_ids': [2],
        });
        expect(planRequests, 0);
        expect(tripRequests, 0);
      }, () => client);
    },
  );

  // Unlike TripSuitcasePage's Replan, this one doesn't require a suitcase
  // change; same confirm dialog and daysToReplan policy.
  group('the Daily Outfit Plan refresh icon (Replan)', () {
    testWidgets('only shows once a trip plan actually exists', (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpDetails(tester, trip: _trip(), detail: const TripDetail());
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
          final plan = _detail(
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
          await pumpDetails(tester, trip: _trip(), detail: plan);
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
          final plan = _detail(
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
          await pumpDetails(tester, trip: _trip(), detail: plan);
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
