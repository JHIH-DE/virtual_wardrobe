import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/services/shared_media_handler.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/features/pages/add_outfit_page.dart';

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

void main() {
  setUp(setUpFakeAuth);

  /// Captures both the [BuildContext] and [WidgetRef] `SharedMediaHandler`
  /// needs — `pumpApp` alone only gives a context.
  Future<({BuildContext context, WidgetRef ref})> pumpHarness(
    WidgetTester tester,
  ) async {
    late BuildContext capturedContext;
    late WidgetRef capturedRef;
    await pumpApp(
      tester,
      Consumer(
        builder: (context, ref, _) {
          capturedContext = context;
          capturedRef = ref;
          return const Scaffold(body: SizedBox());
        },
      ),
      overrides: [garmentsProvider.overrideWith(() => _FakeGarments(const []))],
    );
    return (context: capturedContext, ref: capturedRef);
  }

  testWidgets(
    'a photo shared in while logged in opens the Add Clothing / Match a '
    'Look chooser',
    (tester) async {
      ReceiveSharingIntent.setMockValues(
        initialMedia: [
          SharedMediaFile(
            path: '/tmp/shared.jpg',
            type: SharedMediaType.image,
          ),
        ],
        mediaStream: const Stream.empty(),
      );

      final harness = await pumpHarness(tester);
      SharedMediaHandler.listen(harness.context, harness.ref);
      await tester.pump();
      await tester.pump();

      expect(find.text('Use this Photo'), findsOneWidget);
      expect(find.text('Add Clothing'), findsOneWidget);
      expect(find.text('Match a Look'), findsOneWidget);
    },
  );

  testWidgets('a photo shared in while logged out is ignored', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues(const {});
    ReceiveSharingIntent.setMockValues(
      initialMedia: [
        SharedMediaFile(path: '/tmp/shared.jpg', type: SharedMediaType.image),
      ],
      mediaStream: const Stream.empty(),
    );

    final harness = await pumpHarness(tester);
    SharedMediaHandler.listen(harness.context, harness.ref);
    await tester.pump();
    await tester.pump();

    expect(find.text('Use this Photo'), findsNothing);
  });

  testWidgets(
    'choosing "Add Clothing" sends that exact photo to analyze-instant',
    (tester) async {
      // A real file — GarmentService.analyzeGarment reads it via
      // http.MultipartFile.fromPath, which needs an actual path on disk;
      // ImageEditorPage (and its manual crop step) no longer sits between
      // the shared photo and this call — the backend crops to the subject
      // itself now (see GarmentUploadHelper.analyzePhoto's doc).
      final sharedFile = File(
        '${Directory.systemTemp.path}/shared_media_handler_test_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      )..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
      addTearDown(() {
        if (sharedFile.existsSync()) sharedFile.deleteSync();
      });

      ReceiveSharingIntent.setMockValues(
        initialMedia: [
          SharedMediaFile(path: sharedFile.path, type: SharedMediaType.image),
        ],
        mediaStream: const Stream.empty(),
      );

      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        return jsonResponse(envelope({'metadata': <String, dynamic>{}}));
      });

      await http.runWithClient(() async {
        // analyzeGarment does real file IO (MultipartFile.fromPath reading
        // sharedFile) before it ever reaches the mocked client — real async
        // work that tester.pump()'s fake-async zone can't service on its
        // own (same reason image_editor_page_test.dart needs this).
        await tester.runAsync(() async {
          final harness = await pumpHarness(tester);
          SharedMediaHandler.listen(harness.context, harness.ref);
          await tester.pump();
          await tester.pump();

          await tester.tap(find.text('Add Clothing'));
          await tester.pump();

          for (var i = 0; i < 30 && requests.isEmpty; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            await tester.pump(const Duration(milliseconds: 20));
          }

          expect(requests, hasLength(1));
          expect(requests.single.url.path, endsWith('/analyze-instant'));
          // Sanity-checks the *right* file's bytes made it into the
          // request (not just that some request fired) without depending
          // on MultipartRequest-specific fields — MockClient rebuilds the
          // sent stream into a plain http.Request, losing those.
          expect(
            requests.single.bodyBytes,
            containsAllInOrder(sharedFile.readAsBytesSync()),
          );
        });
      }, () => client);
    },
  );

  testWidgets(
    'choosing "Match a Look" opens Add Outfit with that photo queued for '
    'the Match a Look flow',
    (tester) async {
      ReceiveSharingIntent.setMockValues(
        initialMedia: [
          SharedMediaFile(
            path: '/tmp/shared.jpg',
            type: SharedMediaType.image,
          ),
        ],
        mediaStream: const Stream.empty(),
      );

      final harness = await pumpHarness(tester);
      SharedMediaHandler.listen(harness.context, harness.ref);
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Match a Look'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final page = tester.widget<AddOutfitPage>(find.byType(AddOutfitPage));
      expect(page.initialMatchALookImagePath, '/tmp/shared.jpg');
    },
  );
}
