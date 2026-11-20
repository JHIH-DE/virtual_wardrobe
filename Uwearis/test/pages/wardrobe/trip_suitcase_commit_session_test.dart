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
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/location_result.dart';
import 'package:uwearis/data/trip.dart';
import 'package:uwearis/features/pages/wardrobe/trip_suitcase_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/garment/garment_card.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';
import '../../helpers/seeded_notifiers.dart';

// Trip Suitcase commits staged picks one request at a time (one batched
// add, then one DELETE per removal) before planning. Every request belongs
// to the session the commit started in: once it has ended, no further add /
// remove may go out — least of all under the next account's token — and no
// plan is generated.

Garment _garment(int id, String name, GarmentCategory category) => Garment(
  id: id,
  garmentId: id,
  name: name,
  category: category,
  subCategory: '',
  uploadUrl: '',
  objectName: '',
);

final _closet = [
  _garment(1, 'Tee', GarmentCategory.top),
  _garment(6, 'Shirt', GarmentCategory.top),
  _garment(5, 'Polo', GarmentCategory.top),
  _garment(2, 'Jeans', GarmentCategory.bottom),
  _garment(3, 'Sneakers', GarmentCategory.shoes),
];

Map<String, dynamic> _item(int id, String name, String category) => {
  'garment_id': id,
  'name': name,
  'category': category,
};

final _packedOnServer = [
  _item(1, 'Tee', 'top'),
  _item(6, 'Shirt', 'top'),
  _item(2, 'Jeans', 'bottom'),
  _item(3, 'Sneakers', 'shoes'),
];

Map<String, dynamic> _collection({
  required List<Map<String, dynamic>> suitcase,
  List<Object?> outfits = const [],
}) => {
  'trip_id': 7,
  'total_days': 4,
  'suggested_outfit_count': {'min': 4, 'max': 6},
  'suitcase_items': suitcase,
  'outfits': outfits,
  'refresh_batch_size': 0,
  'ai_added_count': outfits.length,
  'ai_status': outfits.isEmpty ? 'no_new' : 'ok',
};

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

/// A stateful suitcase backend. Records each add / remove / generate with
/// its bearer account; [onAdd] / [onRemove] run when that request arrives,
/// before it's answered.
class _Backend {
  final sent = <String>[];
  final packed = List.of(_packedOnServer);
  Future<http.Response?> Function()? onAdd;
  Future<http.Response?> Function(int garmentId)? onRemove;

  static String _who(http.BaseRequest r) {
    final auth = r.headers['Authorization'];
    return auth == null ? '-' : auth.replaceFirst('Bearer access-', '');
  }

  List<String> get writes => sent
      .where((s) => !s.startsWith('reload') && !s.startsWith('advice'))
      .toList();

  MockClient client() => MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (path.endsWith('/trip_plans/7/outfits') ||
        path.endsWith('/trip_plans/7/outfits/sync')) {
      sent.add('reload as ${_who(req)}');
      return jsonResponse(envelope(_collection(suitcase: packed)));
    }
    if (path.endsWith('/packing-analysis')) {
      sent.add('advice');
      return jsonResponse(
        envelope({'overall_advice': null, 'categories': <Object>[]}),
      );
    }
    if (req.method == 'POST' && path.endsWith('/trip_plans/7/suitcase-items')) {
      final ids = (jsonDecode(req.body)['garment_ids'] as List).cast<int>();
      sent.add('add $ids as ${_who(req)}');
      final override = await onAdd?.call();
      if (override != null) return override;
      for (final id in ids) {
        final g = _closet.firstWhere((g) => g.id == id);
        packed.add(_item(id, g.name, g.category.apiValue.toLowerCase()));
      }
      return jsonResponse(envelope({'suitcase_items': packed}));
    }
    if (req.method == 'DELETE' && path.contains('/suitcase-items/')) {
      final id = int.parse(path.split('/').last);
      sent.add('remove $id as ${_who(req)}');
      final override = await onRemove?.call(id);
      if (override != null) return override;
      packed.removeWhere((g) => g['garment_id'] == id);
      return jsonResponse(envelope({'affected_options': <Object>[]}));
    }
    if (req.method == 'POST' && path.endsWith('/outfits/generate')) {
      sent.add('generate as ${_who(req)}');
      return jsonResponse(
        envelope(
          _collection(
            suitcase: packed,
            outfits: [
              {'id': 1, 'source': 'suggested', 'garments': packed},
            ],
          ),
        ),
      );
    }
    return jsonResponse(envelope(null), status: 404);
  });
}

Future<void> _signInAs(String account) async {
  await AuthStorage.clear();
  await AuthStorage.startSession(
    accessToken: 'access-$account',
    refreshToken: 'refresh-$account',
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// The commit (add Polo; remove Tee, then Shirt), the plan after it.
const _fullRun = [
  'add [5] as A',
  'remove 1 as A',
  'remove 6 as A',
  'generate as A',
];

void main() {
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
  });

  late BuildContext root;
  late _Backend backend;

  Future<void> run(Future<void> Function() body) {
    backend = _Backend();
    return http.runWithClient(body, backend.client);
  }

  /// Opens the suitcase, stages "Polo in, Tee and Shirt out" through the
  /// picker, and taps Plan Trip Outfits — which commits them first.
  Future<void> stageAndPlan(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(
      tester,
      Builder(
        builder: (context) {
          root = context;
          return const Scaffold(body: Text('Root'));
        },
      ),
      overrides: [
        garmentsProvider.overrideWith(
          () => SeededGarmentsNotifier(_closet, refreshReseeds: true),
        ),
        outfitsProvider.overrideWith(
          () => SeededOutfitsNotifier(const [], refreshReseeds: true),
        ),
      ],
      retry: (_, _) => null,
    );
    unawaited(
      Navigator.of(root).push(
        MaterialPageRoute(builder: (_) => TripSuitcasePage(trip: _trip())),
      ),
    );
    await _settle(tester);

    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName == 'assets/images/plus.png',
      ),
    );
    await _settle(tester);
    for (final id in [1, 6, 5]) {
      await tester.tap(
        find.byWidgetPredicate((w) => w is GarmentCard && w.garment.id == id),
      );
      await tester.pump();
    }
    await tester.binding.handlePopRoute();
    await _settle(tester);
    expect(find.byType(TripSuitcasePage), findsOneWidget);

    await tester.tap(find.text('Plan Trip Outfits'));
    await tester.pump();
  }

  TripOutfitCollectionView detail(WidgetTester tester) {
    final c = ProviderScope.containerOf(root).read(tripDetailProvider(7));
    return TripOutfitCollectionView(c.value);
  }

  /// What the suitcase page shows as packed (staged or committed).
  Set<int> shownPacked(WidgetTester tester) => {
    for (final card in tester.widgetList<GarmentCard>(find.byType(GarmentCard)))
      if (card.garment.id != null) card.garment.id!,
  };

  Future<void> closeDialogs(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      final buttons = find.byKey(AppDialog.dismissButtonKey);
      if (buttons.evaluate().isEmpty) break;
      await tester.tap(buttons.last);
      await _settle(tester);
    }
    while (tester.takeException() != null) {}
  }

  testWidgets('one session: the add, both removals and the plan all go out '
      'as A, then the page pops', (tester) async {
    await run(() async {
      await stageAndPlan(tester);
      await _settle(tester);

      expect(backend.writes, _fullRun);
      expect(find.byType(TripSuitcasePage), findsNothing);
      expect(detail(tester).suitcaseIds, {5, 2, 3});
      expect(detail(tester).outfitCount, 1);
    });
  });

  testWidgets("B signs in while the add is in flight: no removal (as B or "
      'anyone) and no plan; the staging stays', (tester) async {
    await run(() async {
      backend.onAdd = () async {
        await _signInAs('B');
        return null;
      };
      await stageAndPlan(tester);
      await _settle(tester);

      final shown = {
        'writes': backend.writes,
        'page': find.byType(TripSuitcasePage).evaluate().length,
        'dialogs': find.byType(AppDialog).evaluate().length,
        'packed': shownPacked(tester),
      };
      await closeDialogs(tester);
      expect(shown, {
        'writes': ['add [5] as A'],
        'page': 1,
        'dialogs': 0,
        'packed': {5, 2, 3},
      });
      expect(find.text('Plan Trip Outfits'), findsOneWidget);
    });
  });

  testWidgets('A only signs out while the add is in flight: it stops there', (
    tester,
  ) async {
    await run(() async {
      backend.onAdd = () async {
        await AuthStorage.clear();
        return null;
      };
      await stageAndPlan(tester);
      await _settle(tester);

      final shown = {
        'writes': backend.writes,
        'dialogs': find.byType(AppDialog).evaluate().length,
      };
      await closeDialogs(tester);
      expect(shown, {
        'writes': ['add [5] as A'],
        'dialogs': 0,
      });
    });
  });

  testWidgets('the session changes after the add has landed, while the '
      'first removal is out: the next removal and the plan never go out', (
    tester,
  ) async {
    await run(() async {
      final switched = Completer<void>();
      backend.onAdd = () async {
        // After this reply has been handled, like a tap on Sign Out would.
        Timer.run(() async {
          await _signInAs('B');
          switched.complete();
        });
        return null;
      };
      backend.onRemove = (id) async {
        if (id == 1) await switched.future;
        return null;
      };
      await stageAndPlan(tester);
      await _settle(tester);

      final shown = {
        'writes': backend.writes,
        'dialogs': find.byType(AppDialog).evaluate().length,
        'page': find.byType(TripSuitcasePage).evaluate().length,
      };
      await closeDialogs(tester);
      expect(shown, {
        'writes': ['add [5] as A', 'remove 1 as A'],
        'dialogs': 0,
        'page': 1,
      });
    });
  });

  testWidgets("the last removal's reply landing after the session ended: no "
      'plan (the withAuth contract)', (tester) async {
    await run(() async {
      backend.onRemove = (id) async {
        if (id == 6) await _signInAs('B');
        return null;
      };
      await stageAndPlan(tester);
      await _settle(tester);

      final shown = {
        'writes': backend.writes,
        'dialogs': find.byType(AppDialog).evaluate().length,
        'page': find.byType(TripSuitcasePage).evaluate().length,
      };
      await closeDialogs(tester);
      expect(shown, {
        'writes': ['add [5] as A', 'remove 1 as A', 'remove 6 as A'],
        'dialogs': 0,
        'page': 1,
      });
    });
  });

  testWidgets('one session, a removal fails with a 500: the error shows, no '
      'plan; Plan again resends only what is left', (tester) async {
    await run(() async {
      var failOnce = true;
      backend.onRemove = (id) async {
        if (id == 1 && failOnce) {
          failOnce = false;
          return jsonResponse(envelope(null), status: 500);
        }
        return null;
      };
      await stageAndPlan(tester);
      await _settle(tester);

      expect(find.text('Failed to update suitcase'), findsOneWidget);
      expect(backend.writes, ['add [5] as A', 'remove 1 as A']);
      expect(detail(tester).suitcaseIds, containsAll([5]));
      await closeDialogs(tester);

      await tester.tap(find.text('Plan Trip Outfits'));
      await _settle(tester);
      expect(backend.writes, [
        'add [5] as A',
        'remove 1 as A',
        // The landed add isn't resent.
        'remove 1 as A',
        'remove 6 as A',
        'generate as A',
      ]);
      expect(find.byType(TripSuitcasePage), findsNothing);
    });
  });

  testWidgets("one session, the add's unrecoverable 401: Session Expired, "
      'nothing more sent', (tester) async {
    await run(() async {
      backend.onAdd = () async => http.Response('{}', 401);
      await stageAndPlan(tester);
      await _settle(tester);

      final shown = {
        'writes': backend.writes,
        'sessionExpired': find.text('Session Expired').evaluate().length,
        'failed': find.text('Failed to update suitcase').evaluate().length,
      };
      await closeDialogs(tester);
      expect(shown, {
        'writes': ['add [5] as A'],
        'sessionExpired': 1,
        'failed': 0,
      });
    });
  });
}

/// The bits of the cached collection these tests read.
class TripOutfitCollectionView {
  TripOutfitCollectionView(this._value);
  final dynamic _value;

  Set<int> get suitcaseIds => _value == null
      ? const {}
      : {for (final g in _value.suitcase as List<Garment>) g.id!};

  int get outfitCount => _value == null ? 0 : (_value.outfits as List).length;
}
