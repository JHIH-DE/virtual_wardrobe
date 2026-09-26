import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/trip_suggestion_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/expandable_insight_body.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

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

void main() {
  setUp(() {
    setUpFakeAuth();
    // Needed for the AuthExpiredException test below — AuthExpiredHandler
    // .handle's clearSignedInSession() reads/writes SharedPreferences
    // (GarmentService's closet-analysis cache), which otherwise never
    // resolves in a test binding with no platform channel to answer it.
    SharedPreferences.setMockInitialValues({});
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  http.Client suitcaseClient({
    String? overallAdvice,
    List<Map<String, dynamic>> suitcaseItems = const [
      {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
      {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
    ],
    List<Map<String, dynamic>> closetGarments = const [],
    void Function()? onGenerate,
  }) {
    return MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path.endsWith('/trip_plans/7')) {
        return jsonResponse(envelope({'suitcase_items': suitcaseItems}));
      }
      if (request.method == 'GET' &&
          request.url.path.endsWith('/packing-analysis')) {
        return jsonResponse(
          envelope({'overall_advice': overallAdvice, 'categories': []}),
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/garments')) {
        return jsonResponse(
          envelope({
            'items': closetGarments,
            'total': closetGarments.length,
            'page': 1,
            'size': 100,
          }),
        );
      }
      if (request.method == 'POST' && request.url.path.endsWith('/generate')) {
        onGenerate?.call();
        return jsonResponse(
          envelope({'days': [], 'suitcase_items': suitcaseItems}),
        );
      }
      if (request.method == 'DELETE' &&
          request.url.path.contains('/suitcase-items/')) {
        return jsonResponse(envelope({'affected_options': []}));
      }
      return jsonResponse(envelope({}), status: 404);
    });
  }

  testWidgets('renders the packed suitcase items', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Tee'), findsOneWidget);
      expect(find.text('Jeans'), findsOneWidget);
    }, () => suitcaseClient());
  });

  // The outfit-advice card moved here from Trip Details — this page now
  // watches tripSuggestionProvider directly (see trip_suggestion_provider.dart).
  testWidgets('renders the outfit-advice card, collapsed by default', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Layer up for the evenings.'), findsOneWidget);
      expect(
        tester
            .widget<ExpandableInsightBody>(find.byType(ExpandableInsightBody))
            .expanded,
        isFalse,
      );
    }, () => suitcaseClient(overallAdvice: 'Layer up for the evenings.'));
  });

  // Regression: tripSuggestionProvider used to only be read via
  // `.watch(...).when(...)` here (see _buildPackingAdviceCard) — with no
  // listener of its own, an AuthExpiredException on it would just render
  // ErrorStateWidget-style nothing (that widget deliberately renders
  // nothing for AuthExpiredException, expecting some listener elsewhere to
  // own the redirect) instead of ever prompting the user to log back in.
  testWidgets(
    'an AuthExpiredException on tripSuggestionProvider shows the '
    'session-expired dialog',
    (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripSuitcasePage(trip: _trip()),
          overrides: [
            // A small delay before throwing, not an immediate one — the
            // page's AuthExpired listener is only attached inside
            // initState's addPostFrameCallback (after the first frame);
            // a real network failure always arrives well after that point,
            // but an override that throws on the very first microtask can
            // race ahead of it, which would make this test pass or fail on
            // an artifact of test timing rather than the actual page logic.
            tripSuggestionProvider(7).overrideWith((ref) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              throw AuthExpiredException();
            }),
          ],
        );
        await tester.pump();
        // Real time past the override's 50ms delay, plus AuthExpiredHandler's
        // own async chain (clearSignedInSession) before it calls showDialog —
        // pumpAndSettle alone can return between two of those async gaps
        // with nothing yet scheduled, before the dialog actually goes up.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(
          find.text(AppLocalizationsEn().sessionExpiredTitle),
          findsOneWidget,
        );
      }, () => suitcaseClient());
    },
  );

  testWidgets('justCreated opens the outfit-advice card expanded', (
    tester,
  ) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip(), justCreated: true));
      await tester.pump();
      await tester.pump();

      expect(
        tester
            .widget<ExpandableInsightBody>(find.byType(ExpandableInsightBody))
            .expanded,
        isTrue,
      );
    }, () => suitcaseClient(overallAdvice: 'Layer up for the evenings.'));
  });

  testWidgets('an empty suitcase shows the "start packing" state, and its Add '
      'Garments button opens the garment picker', (tester) async {
    await http.runWithClient(() async {
      useTallSurface(tester);
      await pumpApp(tester, TripSuitcasePage(trip: _trip()));
      await tester.pump();
      await tester.pump();

      expect(find.text('Start packing your trip'), findsOneWidget);
      expect(
        find.text(
          'Choose clothes from your closet to build your trip outfits.',
        ),
        findsOneWidget,
      );
      expect(find.text('Add Garments'), findsOneWidget);

      await tester.tap(find.byType(AccentPillButton));
      await tester.pumpAndSettle();

      expect(find.text('Select Garments'), findsOneWidget);
    }, () => suitcaseClient(suitcaseItems: const []));
  });

  testWidgets(
    'the empty-suitcase content stays put on screen whether the advice '
    'card above it is collapsed or expanded',
    (tester) async {
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          final collapsedCenter = tester.getCenter(
            find.text('Start packing your trip'),
          );

          await tester.tap(find.byType(ExpandableInsightBody));
          await tester.pumpAndSettle();

          final expandedCenter = tester.getCenter(
            find.text('Start packing your trip'),
          );

          expect(expandedCenter, collapsedCenter);
        },
        () => suitcaseClient(
          suitcaseItems: const [],
          overallAdvice: 'Layer up for the evenings.',
        ),
      );
    },
  );

  // Plan-generation moved here from Trip Details — see trip_details_page.dart
  // and its own test's "the wardrobe section offers a CTA" case.
  group('plan generation', () {
    final viableSuitcase = [
      {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
      {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
      {'garment_id': 3, 'name': 'Sneakers', 'category': 'shoes'},
    ];
    // Same minimum viable set plus one extra item that isn't load-bearing —
    // removing it leaves top+bottom+shoes intact (still viable) while still
    // changing the packed set relative to what it was on open.
    final viableSuitcaseWithExtra = [
      ...viableSuitcase,
      {'garment_id': 4, 'name': 'Cap', 'category': 'accessory'},
    ];

    /// Removes the last packed card (Accessory sorts last in
    /// [_TripSuitcasePageState._categoryOrder], so with
    /// [viableSuitcaseWithExtra] this is always "Cap") via its corner "×"
    /// badge + the REMOVE confirm — puts the suitcase in a "changed since
    /// open" state without disturbing the minimum viable top+bottom+shoes.
    Future<void> removeLastPackedCard(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.close).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('REMOVE'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'shows "Plan Trip Outfits" once the suitcase can build a complete '
      'outfit, with no plan yet',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          expect(find.text('Plan Trip Outfits'), findsOneWidget);
        }, () => suitcaseClient(suitcaseItems: viableSuitcase));
      },
    );

    testWidgets(
      'hides the plan button while the suitcase cannot build a complete '
      'outfit',
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
          expect(find.text('Plan Trip Outfits'), findsNothing);
        }, () => suitcaseClient());
      },
    );

    testWidgets(
      'a plan already existing is not enough on its own — the button stays '
      'hidden until the suitcase actually changes since opening',
      (tester) async {
        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
          );
          await tester.pump();
          await tester.pump();

          expect(
            find.byKey(const ValueKey('bottomActionButton-hidden')),
            findsOneWidget,
          );
          expect(find.text('Replan Trip Outfits'), findsNothing);
        }, () => suitcaseClient(suitcaseItems: viableSuitcase));
      },
    );

    testWidgets('shows "Replan Trip Outfits" once the packed set changes '
        'since opening (e.g. removing a packed item)', (tester) async {
      await http.runWithClient(() async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text('Replan Trip Outfits'), findsNothing);

        await removeLastPackedCard(tester);

        expect(find.text('Replan Trip Outfits'), findsOneWidget);
      }, () => suitcaseClient(suitcaseItems: viableSuitcaseWithExtra));
    });

    testWidgets(
      'tapping "Plan Trip Outfits" generates the plan and pops back',
      (tester) async {
        var generateCalls = 0;
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

            expect(generateCalls, 1);
            expect(find.byType(TripSuitcasePage), findsNothing);
            expect(find.text('Behind the Suitcase page'), findsOneWidget);
          },
          () => suitcaseClient(
            suitcaseItems: viableSuitcase,
            onGenerate: () => generateCalls++,
          ),
        );
      },
    );

    testWidgets('tapping "Replan Trip Outfits" confirms before touching an '
        'existing plan', (tester) async {
      var generateCalls = 0;
      await http.runWithClient(
        () async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
          );
          await tester.pump();
          await tester.pump();
          await removeLastPackedCard(tester); // put it in a "changed" state

          await tester.tap(find.text('Replan Trip Outfits'));
          await tester.pumpAndSettle();

          expect(find.text('Replan trip outfits?'), findsOneWidget);
          // Cancel -> no getTripPlan/generate call, still on the Suitcase page.
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();

          expect(generateCalls, 0);
          expect(find.byType(TripSuitcasePage), findsOneWidget);
        },
        () => suitcaseClient(
          suitcaseItems: viableSuitcaseWithExtra,
          onGenerate: () => generateCalls++,
        ),
      );
    });
  });

  // Replan reads the full day-by-day plan (GET /plan) after a confirmed
  // replan + committed suitcase, and only sends the backend the dates that
  // actually need regenerating (TripDayOutfit.needsReplan) — everything
  // else (manually edited, or already rendered and still fully packed)
  // stays out of the `days` filter untouched.
  group('replanning an existing trip plan', () {
    final baseSuitcase = [
      {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
      {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
      {'garment_id': 3, 'name': 'Sneakers', 'category': 'shoes'},
      {'garment_id': 4, 'name': 'Cap', 'category': 'accessory'},
    ];

    Map<String, dynamic> optionDay({
      required String date,
      required int optionId,
      required int garmentId,
      required bool isManuallyEdited,
      int? outfitId,
    }) => {
      'date': date,
      'options': [
        {
          'id': optionId,
          'order_index': 0,
          'outfit_id': outfitId,
          'is_manually_edited': isManuallyEdited,
          'items': [
            {
              'garment_id': garmentId,
              'name': 'Item $garmentId',
              'category': 'top',
            },
          ],
        },
      ],
    };

    testWidgets(
      'only regenerates days whose garment is no longer packed or that '
      "were never touched — a manually-edited day and an already-rendered "
      'day are both left out of the `days` filter',
      (tester) async {
        http.Request? capturedGenerate;
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/packing-analysis')) {
            return jsonResponse(
              envelope({'overall_advice': null, 'categories': []}),
            );
          }
          if (request.method == 'GET' &&
              request.url.path.endsWith('/trip_plans/7')) {
            // Cap (garment 4) is still packed on open — removed below via
            // the "×" badge, which both puts the suitcase in a "changed"
            // state and orphans day 2026-11-03's garment.
            return jsonResponse(envelope({'suitcase_items': baseSuitcase}));
          }
          if (request.method == 'GET' && request.url.path.endsWith('/plan')) {
            return jsonResponse(
              envelope({
                'days': [
                  // Manually edited, garment (1) still packed -> keep.
                  optionDay(
                    date: '2026-11-01',
                    optionId: 201,
                    garmentId: 1,
                    isManuallyEdited: true,
                  ),
                  // Already rendered, garment (2) still packed -> keep.
                  optionDay(
                    date: '2026-11-02',
                    optionId: 202,
                    garmentId: 2,
                    isManuallyEdited: false,
                    outfitId: 99,
                  ),
                  // Manually edited AND rendered, but garment (4) was just
                  // removed from the suitcase -> missing-garment rule wins,
                  // regenerate anyway.
                  optionDay(
                    date: '2026-11-03',
                    optionId: 203,
                    garmentId: 4,
                    isManuallyEdited: true,
                    outfitId: 55,
                  ),
                  // AI-produced, never touched, never rendered, garment (3)
                  // still packed -> nothing to lose, regenerate.
                  optionDay(
                    date: '2026-11-04',
                    optionId: 204,
                    garmentId: 3,
                    isManuallyEdited: false,
                  ),
                ],
                'suitcase_items': baseSuitcase.sublist(0, 3),
              }),
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/generate')) {
            capturedGenerate = request;
            return jsonResponse(
              envelope({'days': [], 'suitcase_items': baseSuitcase}),
            );
          }
          if (request.method == 'DELETE' &&
              request.url.path.contains('/suitcase-items/')) {
            return jsonResponse(envelope({'affected_options': []}));
          }
          return jsonResponse(envelope({}), status: 404);
        });

        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
          );
          await tester.pump();
          await tester.pump();

          // Removing Cap puts the suitcase in a "changed since open" state
          // and is exactly what orphans day 2026-11-03's garment.
          await tester.tap(find.byIcon(Icons.close).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('REMOVE'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Replan Trip Outfits'));
          await tester.pumpAndSettle();
          expect(find.text('Replan trip outfits?'), findsOneWidget);
          await tester.tap(find.text('Replan'));
          await tester.pumpAndSettle();

          expect(capturedGenerate, isNotNull);
          final body =
              jsonDecode(capturedGenerate!.body) as Map<String, dynamic>;
          expect(body['days'], [
            {'date': '2026-11-03'},
            {'date': '2026-11-04'},
          ]);
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
          if (request.method == 'GET' &&
              request.url.path.endsWith('/trip_plans/7')) {
            // Cap (garment 4) is still packed on open — removed below to
            // put the suitcase in a "changed" state, but neither day
            // references it, so nothing actually gets orphaned by that.
            return jsonResponse(envelope({'suitcase_items': baseSuitcase}));
          }
          if (request.method == 'GET' && request.url.path.endsWith('/plan')) {
            return jsonResponse(
              envelope({
                'days': [
                  // Already rendered, garment still packed -> keep.
                  optionDay(
                    date: '2026-11-01',
                    optionId: 201,
                    garmentId: 1,
                    isManuallyEdited: false,
                    outfitId: 99,
                  ),
                  // Manually edited, garment still packed -> keep.
                  optionDay(
                    date: '2026-11-02',
                    optionId: 202,
                    garmentId: 2,
                    isManuallyEdited: true,
                  ),
                ],
                'suitcase_items': baseSuitcase.sublist(0, 3),
              }),
            );
          }
          if (request.method == 'POST' &&
              request.url.path.endsWith('/generate')) {
            generateCalls++;
            return jsonResponse(
              envelope({'days': [], 'suitcase_items': baseSuitcase}),
            );
          }
          if (request.method == 'DELETE' &&
              request.url.path.contains('/suitcase-items/')) {
            return jsonResponse(envelope({'affected_options': []}));
          }
          return jsonResponse(envelope({}), status: 404);
        });

        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(
            tester,
            TripSuitcasePage(trip: _trip(), initialHasTripPlan: true),
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(find.byIcon(Icons.close).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('REMOVE'));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Replan Trip Outfits'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Replan'));
          await tester.pumpAndSettle();

          expect(generateCalls, 0);
          expect(
            find.text(
              "Nothing to replan — every outfit still fits your suitcase.",
            ),
            findsOneWidget,
          );
          expect(find.byType(TripSuitcasePage), findsOneWidget);
        }, () => client);
      },
    );
  });

  // `DELETE /suitcase-items/{garment_id}` now returns `affected_options` —
  // days/options still referencing the removed garment at the moment of
  // removal. Purely informational: removal itself always succeeds and
  // nothing about the day's outfit/render/option is touched automatically
  // (no Fix/Replan offered), so the only observable difference is whether a
  // SnackBar mentions it.
  group('removing a suitcase item affecting existing day outfits', () {
    testWidgets(
      'affected_options empty: removal behaves exactly as before, no extra '
      'notice',
      (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/trip_plans/7')) {
            return jsonResponse(
              envelope({
                'suitcase_items': [
                  {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
                  {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
                ],
              }),
            );
          }
          if (request.url.path.endsWith('/packing-analysis')) {
            return jsonResponse(
              envelope({'overall_advice': null, 'categories': []}),
            );
          }
          if (request.method == 'DELETE' &&
              request.url.path.endsWith('/suitcase-items/2')) {
            return jsonResponse(envelope({'affected_options': []}));
          }
          return jsonResponse(envelope({}), status: 404);
        });

        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          expect(find.text('Jeans'), findsOneWidget);
          await tester.tap(find.byIcon(Icons.close).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('REMOVE'));
          await tester.pumpAndSettle();

          expect(find.text('Jeans'), findsNothing);
          expect(find.byType(SnackBar), findsNothing);
        }, () => client);
      },
    );

    testWidgets(
      'affected_options non-empty: garment is still removed, and a plain '
      'SnackBar explains it is still used elsewhere in the trip',
      (tester) async {
        final client = MockClient((request) async {
          if (request.url.path.endsWith('/trip_plans/7')) {
            return jsonResponse(
              envelope({
                'suitcase_items': [
                  {'garment_id': 1, 'name': 'Tee', 'category': 'top'},
                  {'garment_id': 2, 'name': 'Jeans', 'category': 'bottom'},
                ],
              }),
            );
          }
          if (request.url.path.endsWith('/packing-analysis')) {
            return jsonResponse(
              envelope({'overall_advice': null, 'categories': []}),
            );
          }
          if (request.method == 'DELETE' &&
              request.url.path.endsWith('/suitcase-items/2')) {
            return jsonResponse(
              envelope({
                'affected_options': [
                  {
                    'day_id': 311,
                    'date': '2026-10-01',
                    'option_id': 162,
                    'is_manually_edited': true,
                    'has_rendered_outfit': true,
                  },
                  {
                    'day_id': 312,
                    'date': '2026-10-02',
                    'option_id': 163,
                    'is_manually_edited': false,
                    'has_rendered_outfit': false,
                  },
                ],
              }),
            );
          }
          return jsonResponse(envelope({}), status: 404);
        });

        await http.runWithClient(() async {
          useTallSurface(tester);
          await pumpApp(tester, TripSuitcasePage(trip: _trip()));
          await tester.pump();
          await tester.pump();

          await tester.tap(find.byIcon(Icons.close).last);
          await tester.pumpAndSettle();
          await tester.tap(find.text('REMOVE'));
          await tester.pumpAndSettle();

          // Garment removal itself is unaffected — no Fix/Replan, no undo.
          expect(find.text('Jeans'), findsNothing);
          expect(
            find.text(
              'Removed from Suitcase. This item is still used in 2 of '
              "this trip's planned outfits.",
            ),
            findsOneWidget,
          );
        }, () => client);
      },
    );
  });
}
