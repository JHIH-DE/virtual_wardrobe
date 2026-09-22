import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/widgets/garment/garment_detail_dialog.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/garments';

Garment _garment({
  required int id,
  bool isDeleted = false,
  String? brand,
  double? price,
}) {
  return Garment(
    id: id,
    name: 'Denim Jacket',
    category: GarmentCategory.outer,
    subCategory: 'Denim jacket',
    uploadUrl: '',
    objectName: '',
    imageUrl: '',
    isDeleted: isDeleted,
    brand: brand,
    price: price,
  );
}

/// Pumps a page with a button that opens [GarmentDetailDialog.show] for
/// [garment] and stashes whatever it resolves to in [onResult].
Future<void> _pumpOpener(
  WidgetTester tester,
  Garment garment,
  void Function(Garment?) onResult,
) async {
  await pumpApp(
    tester,
    Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            onResult(await GarmentDetailDialog.show(context, garment));
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(setUpFakeAuth);

  // The dialog's photo (aspect ratio 1) plus every detail row needs more
  // height than the default 800x600 test surface — same reasoning as every
  // other full-page test in this suite that calls this useTallSurface.
  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('an active garment shows no restore button or notice', (
    tester,
  ) async {
    useTallSurface(tester);
    await http.runWithClient(() async {
      await _pumpOpener(tester, _garment(id: 1), (_) {});

      expect(find.text('Add Back to Closet'), findsNothing);
      expect(
        find.text('This item has been removed from your closet.'),
        findsNothing,
      );
    }, () => MockClient((_) async => jsonResponse(envelope(null))));
  });

  testWidgets(
    'brand and price rows are hidden entirely when the garment has neither',
    (tester) async {
      useTallSurface(tester);
      await http.runWithClient(() async {
        await _pumpOpener(tester, _garment(id: 5), (_) {});

        expect(find.text('Brand'), findsNothing);
        expect(find.text('Price'), findsNothing);
        expect(find.text('--'), findsNothing);
      }, () => MockClient((_) async => jsonResponse(envelope(null))));
    },
  );

  testWidgets('only the price row shows when brand is missing', (
    tester,
  ) async {
    useTallSurface(tester);
    await http.runWithClient(() async {
      await _pumpOpener(tester, _garment(id: 6, price: 1490), (_) {});

      expect(find.text('Brand'), findsNothing);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text(r'$1490'), findsOneWidget);
    }, () => MockClient((_) async => jsonResponse(envelope(null))));
  });

  testWidgets('both rows show when brand and price are present', (
    tester,
  ) async {
    useTallSurface(tester);
    await http.runWithClient(() async {
      await _pumpOpener(
        tester,
        _garment(id: 7, brand: 'Uniqlo', price: 990),
        (_) {},
      );

      expect(find.text('Brand'), findsOneWidget);
      expect(find.text('Uniqlo'), findsOneWidget);
      expect(find.text('Price'), findsOneWidget);
      expect(find.text(r'$990'), findsOneWidget);
    }, () => MockClient((_) async => jsonResponse(envelope(null))));
  });

  testWidgets('tapping anywhere on the card pops with null', (tester) async {
    useTallSurface(tester);
    Garment? result;
    await http.runWithClient(() async {
      await _pumpOpener(tester, _garment(id: 1), (r) => result = r);

      // No dedicated Close button — the card itself is the tap target.
      // The garment name is always rendered, so it's a reliable spot to
      // tap that isn't also a competing interactive widget.
      await tester.tap(find.text('Denim Jacket'));
      await tester.pumpAndSettle();
    }, () => MockClient((_) async => jsonResponse(envelope(null))));

    expect(result, isNull);
  });

  testWidgets(
    'tapping "Add Back to Closet" restores instead of just closing the '
    'card',
    (tester) async {
      useTallSurface(tester);
      final client = MockClient(
        (_) async => jsonResponse(
          envelope({
            'id': 8,
            'name': 'Denim Jacket',
            'category': 'Outer',
            'sub_category': 'Denim jacket',
            'upload_url': '',
            'object_name': '',
            'image_url': '',
            'is_deleted': false,
          }),
        ),
      );

      Garment? result;
      await http.runWithClient(() async {
        await _pumpOpener(tester, _garment(id: 8, isDeleted: true), (r) {
          result = r;
        });

        await tester.tap(find.text('Add Back to Closet'));
        await tester.pumpAndSettle();
      }, () => client);

      // The gesture arena resolves to the button, not the card's own
      // tap-to-close — the result is the restored garment, not null.
      expect(result, isNotNull);
      expect(result!.isDeleted, isFalse);
    },
  );

  testWidgets(
    'a soft-deleted garment shows the removal notice and a restore button',
    (tester) async {
      useTallSurface(tester);
      await http.runWithClient(() async {
        await _pumpOpener(tester, _garment(id: 2, isDeleted: true), (_) {});

        expect(
          find.text('This item has been removed from your closet.'),
          findsOneWidget,
        );
        expect(find.text('Add Back to Closet'), findsOneWidget);
      }, () => MockClient((_) async => jsonResponse(envelope(null))));
    },
  );

  testWidgets(
    'tapping "Add Back to Closet" PATCHes is_deleted:false and pops with '
    'the restored garment',
    (tester) async {
      useTallSurface(tester);
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return jsonResponse(
          envelope({
            'id': 3,
            'name': 'Denim Jacket',
            'category': 'Outer',
            'sub_category': 'Denim jacket',
            'upload_url': '',
            'object_name': '',
            'image_url': '',
            'is_deleted': false,
          }),
        );
      });

      Garment? result;
      await http.runWithClient(() async {
        await _pumpOpener(tester, _garment(id: 3, isDeleted: true), (r) {
          result = r;
        });

        await tester.tap(find.text('Add Back to Closet'));
        await tester.pumpAndSettle();
      }, () => client);

      expect(captured.method, 'PATCH');
      expect(captured.url.toString(), '$_base/3');
      expect(jsonDecode(captured.body), {'is_deleted': false});
      expect(result, isNotNull);
      expect(result!.id, 3);
      expect(result!.isDeleted, isFalse);
    },
  );

  testWidgets('a failed restore shows a SnackBar and keeps the dialog open', (
    tester,
  ) async {
    useTallSurface(tester);
    final client = MockClient(
      (request) async => jsonResponse(envelope(null), status: 500),
    );

    await http.runWithClient(() async {
      await _pumpOpener(tester, _garment(id: 4, isDeleted: true), (_) {});

      await tester.tap(find.text('Add Back to Closet'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to restore this item'), findsOneWidget);
      // Dialog itself is still up — the button is still there to retry.
      expect(find.text('Add Back to Closet'), findsOneWidget);
    }, () => client);
  });
}
