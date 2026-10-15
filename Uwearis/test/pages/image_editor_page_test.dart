import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/image_editor_page.dart';

import '../helpers/widget_harness.dart';

// A real 1x1 PNG — precacheImage needs a decodable file to resolve.
const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
    '/pLvAAAAAElFTkSuQmCC';

void main() {
  // Getting this geometry wrong silently saves the wrong region rather than
  // crashing.
  group('computeCropRect', () {
    test('no zoom, image and box the same aspect ratio — crop is the whole '
        'image', () {
      final rect = computeCropRect(
        boxSize: const Size(100, 100),
        imageSize: const Size(200, 200),
        transform: Matrix4.identity(),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 200, 200));
    });

    test('no zoom, a wider image than the box (letterboxed) — crop is still '
        'the whole image, not the letterboxed box shape', () {
      final rect = computeCropRect(
        boxSize: const Size(100, 100),
        imageSize: const Size(200, 100),
        transform: Matrix4.identity(),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 200, 100));
    });

    test('zoomed in 2x (centered on the origin) on a square image/box — crop '
        'is the top-left quarter', () {
      final rect = computeCropRect(
        boxSize: const Size(100, 100),
        imageSize: const Size(100, 100),
        transform: Matrix4.identity()..scaleByDouble(2.0, 2.0, 2.0, 1.0),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 50, 50));
    });

    test('a crop rect panned/zoomed past the source edges is clamped to '
        'the image bounds', () {
      final rect = computeCropRect(
        boxSize: const Size(100, 100),
        // Zoomed out: without clamping the crop exceeds the source image.
        imageSize: const Size(100, 100),
        transform: Matrix4.identity()..scaleByDouble(0.5, 0.5, 0.5, 1.0),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 100, 100));
    });
  });

  group('computeOutputSize', () {
    test(
      'a crop already within maxDimension is left as-is, never upscaled',
      () {
        expect(
          computeOutputSize(const Size(400, 300), maxDimension: 1600),
          const Size(400, 300),
        );
      },
    );

    test('a crop larger than maxDimension scales down, preserving aspect '
        'ratio', () {
      expect(
        computeOutputSize(const Size(3200, 1600), maxDimension: 1600),
        const Size(1600, 800),
      );
    });
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  late File imageFile;

  setUp(() {
    // FileImage caches by path; a reused path would skip the real decode
    // whose timing these tests depend on.
    imageFile = File(
      '${Directory.systemTemp.path}/image_editor_page_test_'
      '${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(base64Decode(_onePixelPngBase64));
    PaintingBinding.instance.imageCache.clear();
  });

  tearDown(() {
    if (imageFile.existsSync()) imageFile.deleteSync();
  });

  // _imageReady gates Confirm until the photo has been shown; this checks
  // the gate opens once precaching resolves.
  testWidgets('Confirm stays hidden until the photo finishes precaching, then '
      'becomes available', (tester) async {
    useTallSurface(tester);

    // Real decoding never progresses under pump()'s fake-async zone.
    await tester.runAsync(() async {
      await pumpApp(
        tester,
        ImageEditorPage(title: 'Photo', initialPath: imageFile.path),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('bottomActionButton-hidden')),
        findsOneWidget,
      );

      // Poll until "hidden" is gone — the crossfade keeps both children
      // mounted for 200ms.
      var stillHidden = true;
      for (var i = 0; i < 30 && stillHidden; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 20));
        stillHidden = find
            .byKey(const ValueKey('bottomActionButton-hidden'))
            .evaluate()
            .isNotEmpty;
      }

      expect(stillHidden, isFalse, reason: 'Confirm never became available');
      expect(
        find.byKey(const ValueKey('bottomActionButton-visible')),
        findsOneWidget,
      );
    });
  });

  // Both decoders fail here. HEIF's platform-codec success path can't be
  // reproduced on the test host.
  testWidgets(
    'confirming an undecodable photo shows a friendly error instead of '
    'crashing, and Confirm becomes available again',
    (tester) async {
      useTallSurface(tester);
      final garbageFile = File(
        '${Directory.systemTemp.path}/image_editor_page_test_garbage_'
        '${DateTime.now().microsecondsSinceEpoch}.jpg',
      )..writeAsBytesSync(const [1, 2, 3, 4, 5]);
      addTearDown(() {
        if (garbageFile.existsSync()) garbageFile.deleteSync();
      });

      await tester.runAsync(() async {
        await pumpApp(
          tester,
          ImageEditorPage(title: 'Photo', initialPath: garbageFile.path),
        );
        await tester.pump();

        var stillHidden = true;
        for (var i = 0; i < 30 && stillHidden; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump(const Duration(milliseconds: 20));
          stillHidden = find
              .byKey(const ValueKey('bottomActionButton-hidden'))
              .evaluate()
              .isNotEmpty;
        }
        expect(stillHidden, isFalse, reason: 'Confirm never became available');

        await tester.tap(
          find.byKey(const ValueKey('bottomActionButton-visible')),
        );
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();

        // The preview's Image.file (no errorBuilder) also throws on these
        // bytes; not what this test checks.
        while (tester.takeException() != null) {}

        expect(
          find.text("Couldn't process this photo. Please try a different one."),
          findsOneWidget,
        );
        // Guard reset; wait out the 200ms crossfade first.
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          find.byKey(const ValueKey('bottomActionButton-visible')),
          findsOneWidget,
        );
      });
    },
  );
}
