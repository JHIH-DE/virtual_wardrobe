import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/data/image_edit_result.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/features/widgets/garment/garment_upload_helper.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

/// Real file I/O (the multipart upload) only advances outside fake async,
/// and each step's callback then needs a pump; a few rounds cover it.
Future<void> driveIo(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

void main() {
  setUp(setUpFakeAuth);

  late File photo;
  setUp(() {
    final dir = Directory.systemTemp.createTempSync('upload_helper');
    photo = File('${dir.path}/photo.jpg')..writeAsBytesSync([0xFF, 0xD8]);
    addTearDown(() => dir.deleteSync(recursive: true));
  });

  /// The analysis is started from a pushed page, so a stray extra pop of
  /// the overlay's navigator would show up as that page disappearing.
  Future<Future<ImageEditResult?>> Function() harness(WidgetTester tester) {
    return () async {
      late Future<ImageEditResult?> result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (pageContext) => Scaffold(
                  body: TextButton(
                    onPressed: () => result = GarmentUploadHelper.analyzePhoto(
                      pageContext,
                      photo.path,
                    ),
                    child: const Text('Analyze'),
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze'));
      await tester.pump();
      await driveIo(tester);
      return result;
    };
  }

  MockClient gatedClient(List<Completer<void>> gates) {
    return MockClient((request) async {
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
      return jsonResponse(
        envelope({
          'metadata': {'category': 'Top', 'sub_category': 'Tee'},
          'processed_image_base64': '',
        }),
      );
    });
  }

  Future<void> landReply(WidgetTester tester, Completer<void> gate) async {
    gate.complete();
    await driveIo(tester);
  }

  testWidgets('Cancel returns null at once; the late reply is ignored and '
      'pops nothing else', (tester) async {
    final gates = <Completer<void>>[];
    await http.runWithClient(() async {
      final result = await harness(tester)();
      expect(find.byType(LoadingOverlay), findsOneWidget);
      expect(gates, hasLength(1));

      ImageEditResult? value = ImageEditResult(imagePath: 'unset');
      unawaited(result.then((r) => value = r));
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      expect(find.byType(LoadingOverlay), findsNothing);
      expect(value, isNull);

      await landReply(tester, gates.single);
      expect(find.text('Analyze'), findsOneWidget);
      expect(value, isNull);
    }, () => gatedClient(gates));
  });

  testWidgets('system back cancels like the Cancel button', (tester) async {
    final gates = <Completer<void>>[];
    await http.runWithClient(() async {
      final result = await harness(tester)();

      ImageEditResult? value = ImageEditResult(imagePath: 'unset');
      unawaited(result.then((r) => value = r));
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.byType(LoadingOverlay), findsNothing);
      expect(find.text('Analyze'), findsOneWidget);
      expect(value, isNull);

      await landReply(tester, gates.single);
      expect(find.text('Analyze'), findsOneWidget);
      expect(value, isNull);
    }, () => gatedClient(gates));
  });

  testWidgets('without Cancel, the reply closes the overlay and is returned', (
    tester,
  ) async {
    final gates = <Completer<void>>[];
    await http.runWithClient(() async {
      final result = await harness(tester)();

      ImageEditResult? value;
      unawaited(result.then((r) => value = r));
      await landReply(tester, gates.single);
      expect(find.byType(LoadingOverlay), findsNothing);
      expect(find.text('Analyze'), findsOneWidget);
      expect(value?.analysisData?['sub_category'], 'Tee');
    }, () => gatedClient(gates));
  });
}
