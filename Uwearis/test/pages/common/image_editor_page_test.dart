import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uwearis/features/pages/common/image_editor_page.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';

import 'package:uwearis/l10n/generated/app_localizations.dart';

import '../../helpers/widget_harness.dart';

typedef AppLocalizationsLookup = AppLocalizations;

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(ImageEditorPage)));

/// The album: answers each pick with [next] (null = the user cancelled),
/// or holds it until the test completes [held].
class _FakeImagePicker extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  String? next;
  bool hold = false;
  Completer<XFile?>? held;
  int picks = 0;

  /// When set, the pick fails with it (a denied photo permission, say).
  Object? error;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) {
    picks++;
    if (hold) return (held = Completer<XFile?>()).future;
    if (error != null) return Future.error(error!);
    return Future.value(next == null ? null : XFile(next!));
  }
}

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

  // P2-6: the photo source can come back after the editor is gone (the
  // session expired while the album was open, the editor's route was
  // removed under the camera).
  group('Retake / Album after an await', () {
    late _FakeImagePicker picker;
    late ImagePickerPlatform originalPicker;
    late File replacement;

    setUp(() {
      originalPicker = ImagePickerPlatform.instance;
      picker = _FakeImagePicker();
      ImagePickerPlatform.instance = picker;
      replacement = File(
        '${Directory.systemTemp.path}/image_editor_page_test_new_'
        '${DateTime.now().microsecondsSinceEpoch}.png',
      )..writeAsBytesSync(base64Decode(_onePixelPngBase64));
    });

    tearDown(() {
      ImagePickerPlatform.instance = originalPicker;
      if (replacement.existsSync()) replacement.deleteSync();
    });

    Finder shows(String path) => find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is FileImage &&
          (w.image as FileImage).file.path == path,
    );

    Future<void> openEditor(WidgetTester tester) async {
      useTallSurface(tester);
      await pumpApp(
        tester,
        ImageEditorPage(title: 'Photo', initialPath: imageFile.path),
      );
      await tester.pump();
    }

    NavigatorState navigator(WidgetTester tester) =>
        tester.state<NavigatorState>(find.byType(Navigator).first);

    // The camera page's progress indicator never settles; a route
    // transition is well under 1s.
    Future<void> settleRoute(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> openCamera(
      WidgetTester tester,
      AppLocalizationsLookup l10n,
    ) async {
      await tester.tap(find.text(l10n.retake));
      await settleRoute(tester);
    }

    testWidgets('Retake: a photo taken while the editor is open replaces it', (
      tester,
    ) async {
      await openEditor(tester);
      await openCamera(tester, _l10n(tester));

      navigator(tester).pop(replacement.path);
      await settleRoute(tester);

      expect(shows(replacement.path), findsOneWidget);
      expect(shows(imageFile.path), findsNothing);
    });

    testWidgets('Retake cancelled: the editor keeps its photo', (tester) async {
      await openEditor(tester);
      await openCamera(tester, _l10n(tester));

      navigator(tester).pop();
      await settleRoute(tester);

      expect(shows(imageFile.path), findsOneWidget);
    });

    testWidgets("Retake answering after the editor's route was removed: no "
        'error', (tester) async {
      await openEditor(tester);
      final editorRoute = ModalRoute.of(
        tester.element(find.byType(ImageEditorPage)),
      )!;
      await openCamera(tester, _l10n(tester));

      navigator(tester).removeRoute(editorRoute); // the editor is disposed
      await tester.pump();
      navigator(tester).pop(replacement.path); // the camera answers
      await settleRoute(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(ImageEditorPage), findsNothing);
    });

    testWidgets('Album: a picked photo replaces it', (tester) async {
      picker.next = replacement.path;
      await openEditor(tester);

      await tester.tap(find.text(_l10n(tester).album));
      await tester.pump();

      expect(picker.picks, 1);
      expect(shows(replacement.path), findsOneWidget);
    });

    testWidgets('Album cancelled: the editor keeps its photo', (tester) async {
      picker.next = null;
      await openEditor(tester);

      await tester.tap(find.text(_l10n(tester).album));
      await tester.pump();

      expect(shows(imageFile.path), findsOneWidget);
    });

    testWidgets('Album answering after the editor is gone: no error', (
      tester,
    ) async {
      picker.hold = true;
      await openEditor(tester);
      await tester.tap(find.text(_l10n(tester).album));
      await tester.pump();

      await tester.pumpWidget(const SizedBox()); // e.g. session expired
      picker.held!.complete(XFile(replacement.path));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Album cancelled shows no error', (tester) async {
      picker.next = null;
      await openEditor(tester);

      await tester.tap(find.text(_l10n(tester).album));
      await settleRoute(tester);

      expect(find.byType(AppDialog), findsNothing);
    });

    testWidgets('Album failing (photo access denied) shows the pick-failed '
        'dialog and keeps the photo', (tester) async {
      picker.error = PlatformException(
        code: 'photo_access_denied',
        message: 'The user did not allow photo access.',
      );
      await openEditor(tester);
      final l10n = _l10n(tester);

      await tester.tap(find.text(l10n.album));
      await settleRoute(tester);

      expect(find.text(l10n.photoPickFailed), findsOneWidget);
      await tester.tap(find.byKey(AppDialog.dismissButtonKey));
      await settleRoute(tester);
      expect(shows(imageFile.path), findsOneWidget);
    });

    testWidgets('Album failing after the editor is gone: no dialog, no error', (
      tester,
    ) async {
      picker.hold = true;
      await openEditor(tester);
      await tester.tap(find.text(_l10n(tester).album));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      picker.held!.completeError(
        PlatformException(code: 'already_active', message: 'busy'),
      );
      await settleRoute(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(AppDialog), findsNothing);
    });
  });
}
