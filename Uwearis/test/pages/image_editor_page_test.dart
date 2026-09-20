import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/features/pages/image_editor_page.dart';

import '../helpers/widget_harness.dart';

// A real, valid 1x1 red PNG — precacheImage needs an actual decodable file
// to resolve.
const _onePixelPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
    '/pLvAAAAAElFTkSuQmCC';

void main() {
  // computeCropRect/computeOutputSize are the pure geometry
  // _captureFramedImage relies on to crop the *original* source bytes
  // (rather than screenshotting the live preview — see that method's own
  // doc for why) — plain unit tests, no widget pump/async image decode
  // needed, since getting this wrong would silently save the wrong region
  // rather than crash.
  group('computeCropRect', () {
    test(
      'no zoom, image and box the same aspect ratio — crop is the whole '
      'image',
      () {
        final rect = computeCropRect(
          boxSize: const Size(100, 100),
          imageSize: const Size(200, 200),
          transform: Matrix4.identity(),
        );
        expect(rect, const Rect.fromLTWH(0, 0, 200, 200));
      },
    );

    test(
      'no zoom, a wider image than the box (letterboxed) — crop is still '
      'the whole image, not the letterboxed box shape',
      () {
        final rect = computeCropRect(
          boxSize: const Size(100, 100),
          imageSize: const Size(200, 100),
          transform: Matrix4.identity(),
        );
        expect(rect, const Rect.fromLTWH(0, 0, 200, 100));
      },
    );

    test(
      'zoomed in 2x (centered on the origin) on a square image/box — crop '
      'is the top-left quarter',
      () {
        final rect = computeCropRect(
          boxSize: const Size(100, 100),
          imageSize: const Size(100, 100),
          transform: Matrix4.identity()..scaleByDouble(2.0, 2.0, 2.0, 1.0),
        );
        expect(rect, const Rect.fromLTWH(0, 0, 50, 50));
      },
    );

    test('a crop rect panned/zoomed past the source edges is clamped to '
        'the image bounds', () {
      final rect = computeCropRect(
        boxSize: const Size(100, 100),
        // Zoomed out (scale < 1) — without clamping this would ask for a
        // crop rect bigger than the source image itself.
        imageSize: const Size(100, 100),
        transform: Matrix4.identity()..scaleByDouble(0.5, 0.5, 0.5, 1.0),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 100, 100));
    });
  });

  group('computeOutputSize', () {
    test('a crop already within maxDimension is left as-is, never upscaled', () {
      expect(
        computeOutputSize(const Size(400, 300), maxDimension: 1600),
        const Size(400, 300),
      );
    });

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
    // A fresh file name per test, plus clearing the (process-wide)
    // ImageCache — FileImage keys its cache entry by path, so two tests
    // reusing the same path would let the second one see the first's
    // already-resolved (or still in-flight) image instead of a real fresh
    // decode, which is exactly the timing this file is testing.
    imageFile = File(
      '${Directory.systemTemp.path}/image_editor_page_test_'
      '${DateTime.now().microsecondsSinceEpoch}.png',
    )..writeAsBytesSync(base64Decode(_onePixelPngBase64));
    PaintingBinding.instance.imageCache.clear();
  });

  tearDown(() {
    if (imageFile.existsSync()) imageFile.deleteSync();
  });

  // Regression: _captureFramedImage rasterizes whatever's currently painted
  // via RenderRepaintBoundary.toImage() — confirming the instant a large
  // photo first appears (before precacheImage's decode/GPU-upload settles)
  // could capture a torn/partial frame, silently saving a corrupted
  // garment photo. The fix is _imageReady gating Confirm; this checks that
  // gate actually opens once precaching resolves.
  testWidgets('Confirm stays hidden until the photo finishes precaching, then '
      'becomes available', (tester) async {
    useTallSurface(tester);

    // Real image decoding happens off-isolate via the engine, so it (and
    // every pump that lets its completion actually flush through the
    // widget tree, including BottomActionButton's 200ms crossfade once
    // it starts) has to run inside runAsync — a Future created outside
    // it, under tester.pump()'s fake-async zone, never progresses.
    await tester.runAsync(() async {
      await pumpApp(
        tester,
        ImageEditorPage(initialPath: imageFile.path, showAnalysis: false),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('bottomActionButton-hidden')),
        findsOneWidget,
      );

      // Poll rather than assume a fixed number of pumps is enough — real
      // decode time has to actually elapse, and AnimatedSwitcher keeps
      // both the outgoing "hidden" child and the incoming "visible" one
      // mounted together for its whole 200ms crossfade, so this isn't
      // done until "hidden" is gone, not just once "visible" appears.
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
}
