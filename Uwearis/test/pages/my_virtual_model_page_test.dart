import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/image_editor_page.dart';
import 'package:uwearis/features/pages/my_virtual_model_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/cards/generated_image_card.dart';
import 'package:uwearis/features/widgets/common/images/app_image.dart';
import 'package:uwearis/features/widgets/common/images/app_spinner.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/widget_harness.dart';

final _l10n = AppLocalizationsEn();

/// A fully set-up profile (both reference photos + height/weight present)
/// by default — mirrors home_page_test.dart's `_FakeProfileNotifier`.
class _FakeProfileNotifier extends ProfileNotifier {
  _FakeProfileNotifier({ProfileData? data}) : data = data ?? _complete;

  static final _complete = ProfileData(
    profile: const UserProfile(
      name: 'Test User',
      height: 178,
      weight: 70,
      unitSystem: 'metric',
    ),
    bodyRefUrl: 'https://example.com/body.jpg',
    faceRefUrl: 'https://example.com/face.jpg',
  );

  final ProfileData data;

  @override
  Future<ProfileData> build() async => data;
}

/// Simulates `GET /users/me` itself failing (not an image load failure) —
/// the whole-page error path.
class _FailingProfileNotifier extends ProfileNotifier {
  @override
  Future<ProfileData> build() async => throw Exception('boom');
}

Future<void> _pumpMyVirtualModelPage(
  WidgetTester tester, {
  ProfileNotifier? notifier,
  Duration? Function(int retryCount, Object error)? retry,
}) {
  return pumpApp(
    tester,
    const MyVirtualModelPage(),
    overrides: [
      profileProvider.overrideWith(() => notifier ?? _FakeProfileNotifier()),
    ],
    retry: retry,
  );
}

AppImage _appImageFor(WidgetTester tester, String urlSubstring) {
  return tester
      .widgetList<AppImage>(find.byType(AppImage))
      .firstWhere((w) => (w.url ?? '').contains(urlSubstring));
}

bool _hasAppImageWithUrl(WidgetTester tester, String url) {
  return tester
      .widgetList<AppImage>(find.byType(AppImage))
      .any((w) => w.url == url);
}

Map<String, dynamic> _profileJson({String? bodyRefUrl, String? faceRefUrl}) => {
  'name': 'Test User',
  'height': 178,
  'weight': 70,
  'unit_system': 'metric',
  'body_reference_object_url': bodyRefUrl,
  'face_reference_object_url': faceRefUrl,
};

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxTries = 60,
}) async {
  for (var i = 0; i < maxTries && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    // The committed-photo card's own real CachedNetworkImage fetch (a real
    // signed URL, unrelated to whatever this poll is actually waiting on)
    // hits flutter_cache_manager's on-disk cache, which needs a sqflite
    // factory this test harness never sets up (this suite has never
    // before let a real fetch attempt run — every other test drives
    // `AppImage.onLoadError` directly instead). Drain it exactly like
    // image_editor_page_test.dart's own "pre-existing gap unrelated to the
    // fix this test is actually checking" idiom, rather than let it fail
    // tests that aren't about image-cache plumbing. Only the one group
    // below still using real http:// committed URLs needs this; the
    // fake-backed upload-flow group uses local-file committed URLs
    // specifically to avoid ever hitting this path.
    while (tester.takeException() != null) {}
  }
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A real, valid 1x1 red PNG (same one image_editor_page_test.dart uses) —
/// precacheImage needs actual decodable image bytes to resolve, both for
/// the local file ImageEditorPage previews and for the "verify the new
/// signed URL actually loads" step in the upload flow.
final _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
  '/pLvAAAAAElFTkSuQmCC',
);

/// Writes a fresh, uniquely-named, real decodable PNG to the system temp
/// dir and returns its path — used both as a "committed photo already on
/// disk" fixture (AppImage renders a bare local path via Image.file, no
/// network/cache-manager involved) and as a stand-in for whatever a fake
/// download/pick step hands back.
String _writeTempPng(String prefix) {
  final path =
      '${Directory.systemTemp.path}/'
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}.png';
  File(path).writeAsBytesSync(_tinyPngBytes);
  return path;
}

void _deleteIfExists(String path) {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
}

/// flutter_cache_manager (behind CachedNetworkImage/RefreshableNetworkImage)
/// asks the path_provider plugin for a cache directory the first time a
/// real network image load is attempted — unmocked, that throws a
/// MissingPluginException that derails the whole test (every other pending
/// image/precache future in the same run stalls with it), even though this
/// suite never previously needed a directory to actually exist (every other
/// test drives `AppImage.onLoadError` directly instead of letting a real
/// fetch attempt run). Only the "prepare fails" group below still uses a
/// real http:// committed URL, so only it needs this.
void _mockPathProviderChannel() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => Directory.systemTemp.path);
}

/// A fake [downloadReferencePhotoOriginalProvider] override for the
/// fake-backed upload-flow tests below — ignores [url] entirely (the
/// committed "URL" in those tests is already a local file path a real
/// download step would never receive) and just hands back a fresh, real,
/// decodable PNG each call, so [ImageEditorPage] still gets something it can
/// actually precache/crop. [onCalled] lets a test count/observe invocations
/// (see the re-entrancy-guard test); [onPathCreated] lets a test capture the
/// path it returned, to later assert it was cleaned up (see the temp-file
/// cleanup tests).
DownloadReferencePhotoOriginal _fakeDownload({
  void Function()? onCalled,
  void Function(String path)? onPathCreated,
}) {
  return ({
    required String url,
    required String fileNamePrefix,
    required Future<String?> Function() onRefreshUrl,
    required void Function(String freshUrl) onUrlRefreshed,
  }) async {
    onCalled?.call();
    final path = _writeTempPng('${fileNamePrefix}_fake_download');
    onPathCreated?.call(path);
    return path;
  };
}

/// Fakes image_picker's platform channel so ImageEditorPage's "Album" button
/// returns a real local file without touching a real platform implementation
/// (unmocked, `ImagePicker.pickImage` would hang/throw in a plain
/// `flutter_test` VM run — this suite has no prior precedent for it).
class _FakeImagePickerPlatform extends ImagePickerPlatform
    with MockPlatformInterfaceMixin {
  _FakeImagePickerPlatform(this.pathToReturn);
  final String pathToReturn;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async => XFile(pathToReturn);
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets(
    'a body reference image load failure switches only the body card into '
    'its re-upload state — face card and the page-level error banner are '
    'all untouched',
    (tester) async {
      await _pumpMyVirtualModelPage(tester);
      await tester.pump();

      // Sanity: everything starts normal.
      expect(find.text(_l10n.fullBodyPhotoLabel), findsOneWidget);
      expect(find.text(_l10n.facePhotoLabel), findsOneWidget);
      expect(find.byType(AppImage), findsNWidgets(2));

      _appImageFor(tester, 'body').onLoadError!();
      await tester.pump();

      // Body card flipped into its actionable re-upload state.
      expect(find.text(_l10n.fullBodyPhotoLoadFailedTitle), findsOneWidget);
      expect(find.text(_l10n.photoLoadFailedSubtitle), findsOneWidget);
      expect(find.text(_l10n.reuploadPhotoAction), findsOneWidget);
      expect(find.text(_l10n.fullBodyPhotoLabel), findsNothing);

      // Face card is completely unaffected — still its normal state.
      expect(find.text(_l10n.facePhotoLabel), findsOneWidget);
      expect(find.byType(AppImage), findsOneWidget);

      // No page-level error banner — this never became an API/provider error.
      expect(find.text(_l10n.failedToLoad), findsNothing);
    },
  );

  testWidgets(
    'a face reference image load failure switches only the face card into '
    'its re-upload state — body card and the page-level error banner are '
    'all untouched',
    (tester) async {
      await _pumpMyVirtualModelPage(tester);
      await tester.pump();

      _appImageFor(tester, 'face').onLoadError!();
      await tester.pump();

      expect(find.text(_l10n.facePhotoLoadFailedTitle), findsOneWidget);
      expect(find.text(_l10n.photoLoadFailedSubtitle), findsOneWidget);
      expect(find.text(_l10n.reuploadPhotoAction), findsOneWidget);
      expect(find.text(_l10n.facePhotoLabel), findsNothing);

      expect(find.text(_l10n.fullBodyPhotoLabel), findsOneWidget);
      expect(find.byType(AppImage), findsOneWidget);

      expect(find.text(_l10n.failedToLoad), findsNothing);
    },
  );

  testWidgets(
    'GET /users/me itself failing still shows the page-level error state '
    '(unchanged behaviour) — distinct from a per-image load failure',
    (tester) async {
      await _pumpMyVirtualModelPage(
        tester,
        notifier: _FailingProfileNotifier(),
        // The failure must be terminal for this test — Riverpod's default
        // AsyncNotifier retry-with-backoff would otherwise keep `.future`
        // pending instead of rejecting.
        retry: (_, _) => null,
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.failedToLoad), findsOneWidget);
      // Neither card's actionable re-upload copy applies here — this is the
      // whole-page fallback, not a per-photo state.
      expect(find.text(_l10n.facePhotoLoadFailedTitle), findsNothing);
      expect(find.text(_l10n.fullBodyPhotoLoadFailedTitle), findsNothing);
    },
  );

  testWidgets(
    'a self-healed signed URL (RefreshableNetworkImage refreshing on its '
    'own) is synced back into profileProvider via onUrlRefreshed, instead '
    'of only living inside the image widget — regression coverage for the '
    'card/editor desync this was fixed for',
    (tester) async {
      await _pumpMyVirtualModelPage(tester);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyVirtualModelPage)),
      );
      final initialUrl = container.read(profileProvider).value!.bodyRefUrl!;
      expect(initialUrl, 'https://example.com/body.jpg');

      _appImageFor(tester, 'body').onUrlRefreshed!(
        initialUrl,
        'https://example.com/body-refreshed.jpg',
      );
      await tester.pump();

      // profileProvider — the sole authority for the committed URL — now
      // holds the refreshed one, not just the AppImage that triggered it.
      expect(
        container.read(profileProvider).value!.bodyRefUrl,
        'https://example.com/body-refreshed.jpg',
      );
      // The card itself rebuilt from that same provider state.
      expect(
        _appImageFor(tester, 'body-refreshed').url,
        'https://example.com/body-refreshed.jpg',
      );

      // The other photo is untouched.
      expect(
        container.read(profileProvider).value!.faceRefUrl,
        'https://example.com/face.jpg',
      );
    },
  );

  testWidgets(
    'a stale self-heal that resolves AFTER a separate, newer upload already '
    'committed a different URL must not clobber that newer commit — the '
    'compare-and-set race this was fixed for',
    (tester) async {
      await _pumpMyVirtualModelPage(tester);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MyVirtualModelPage)),
      );
      final originalUrl = container.read(profileProvider).value!.bodyRefUrl!;

      // A separate, newer flow (e.g. _uploadPhoto's own unconditional
      // commit once a real upload finishes) has already moved the
      // committed URL on.
      container
          .read(profileProvider.notifier)
          .setBodyRefUrl('https://example.com/body-newly-uploaded.jpg');
      await tester.pump();

      // The card's own RefreshableNetworkImage had started a refresh
      // against the *original* URL before that upload landed — it only
      // resolves now, handing back yet another (stale) URL.
      _appImageFor(tester, 'newly-uploaded').onUrlRefreshed!(
        originalUrl,
        'https://example.com/body-STALE-refresh-result.jpg',
      );
      await tester.pump();

      // Compare-and-set: expectedCurrent (originalUrl) no longer matches
      // profileProvider's committed URL, so the stale result is ignored —
      // the newer upload's URL survives.
      expect(
        container.read(profileProvider).value!.bodyRefUrl,
        'https://example.com/body-newly-uploaded.jpg',
      );
    },
  );

  group('change photo — prepares a local original before opening the editor', () {
    const originalBodyUrl = 'https://storage.example.com/body-original.jpg';

    // NOTE on scope: this group covers the "prepare fails, editor never
    // opens" case end-to-end using the *real* download provider default and
    // a real http:// committed URL (proving that default wiring). The
    // upload commit/rollback behavior itself is covered by the fake-backed
    // group further below, which sidesteps flutter_cache_manager entirely
    // by using local-file committed URLs + provider overrides instead.
    http.Client mockBackend({required bool downloadOriginalSucceeds}) {
      return MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path.endsWith('/users/me')) {
          return jsonResponse(envelope(_profileJson(bodyRefUrl: originalBodyUrl)));
        }
        if (request.method == 'GET' &&
            request.url.toString() == originalBodyUrl) {
          return downloadOriginalSucceeds
              ? http.Response.bytes(_tinyPngBytes, 200)
              : http.Response('gone', 404);
        }
        return jsonResponse(envelope({}));
      });
    }

    testWidgets(
      "when the committed photo can't be downloaded at all, the editor "
      'never opens — the page stays put and shows one error instead',
      (tester) async {
        final client = mockBackend(downloadOriginalSucceeds: false);
        await tester.runAsync(() async {
          await http.runWithClient(() async {
            _useTallSurface(tester);
            _mockPathProviderChannel();
            await pumpApp(tester, const MyVirtualModelPage());
            await _pumpUntil(
              tester,
              () => find
                  .byKey(const ValueKey('updatePhotoAction-body'))
                  .evaluate()
                  .isNotEmpty,
            );

            await tester.tap(
              find.byKey(const ValueKey('updatePhotoAction-body')),
            );
            await _pumpUntil(
              tester,
              () => find.text(_l10n.photoProcessingFailed).evaluate().isNotEmpty,
            );

            expect(find.text(_l10n.photoProcessingFailed), findsOneWidget);
            expect(find.byType(ImageEditorPage), findsNothing);

            // The card's own guard flag reset — tappable again, not stuck
            // mid-flight.
            final inkWell = tester.widget<InkWell>(
              find.byKey(const ValueKey('updatePhotoAction-body')),
            );
            expect(inkWell.onTap, isNotNull);
          }, () => client);
        });
      },
    );
  });

  group('upload commit and rollback (fake upload/download/verify — no real '
      'network or flutter_cache_manager)', () {
    // ImageEditorPage's `requireChangeToConfirm: true` (this is always
    // "reopen an already-saved photo") means Confirm never enables unless
    // the user actually changes something — so every test below that opens
    // the editor over a *committed* photo has to pick a new source (Album)
    // before Confirm appears, exactly as a real user would after deciding
    // to replace the photo. Wire the image_picker fake for the whole group.
    late String albumPickPath;
    late ImagePickerPlatform originalPlatform;

    setUp(() {
      albumPickPath = _writeTempPng('album_pick');
      originalPlatform = ImagePickerPlatform.instance;
      ImagePickerPlatform.instance = _FakeImagePickerPlatform(albumPickPath);
    });

    tearDown(() {
      ImagePickerPlatform.instance = originalPlatform;
      _deleteIfExists(albumPickPath);
    });

    /// Pumps MyVirtualModelPage with a committed local-file body photo already
    /// on disk, and the download/upload/verify pipeline overridden. Returns
    /// the committed photo's path.
    Future<String> pumpWithCommittedBody(
      WidgetTester tester, {
      required UploadReferencePhoto upload,
      VerifyReferencePhotoLoads? verify,
      void Function()? onDownloadCalled,
      void Function(String path)? onDownloadPathCreated,
    }) async {
      final originalPath = _writeTempPng('committed_body');
      final profile = ProfileData(
        profile: const UserProfile(name: 'Test User'),
        bodyRefUrl: originalPath,
      );
      await pumpApp(
        tester,
        const MyVirtualModelPage(),
        overrides: [
          profileProvider.overrideWith(() => _FakeProfileNotifier(data: profile)),
          downloadReferencePhotoOriginalProvider.overrideWithValue(
            _fakeDownload(
              onCalled: onDownloadCalled,
              onPathCreated: onDownloadPathCreated,
            ),
          ),
          uploadReferencePhotoProvider.overrideWithValue(upload),
          verifyReferencePhotoLoadsProvider.overrideWithValue(
            verify ?? (context, url) async {},
          ),
        ],
      );
      await tester.pump();
      await tester.pump();
      return originalPath;
    }

    /// Taps the body card, waits for the editor, picks a new source via the
    /// faked Album (satisfying `requireChangeToConfirm` — reopening the
    /// existing photo unchanged never enables Confirm, by design), waits
    /// for Confirm to become available, then taps it — the shared "drive
    /// one photo through to the upload attempt" sequence every test below
    /// needs.
    Future<void> changeBodyPhotoAndConfirm(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('updatePhotoAction-body')));
      await _pumpUntil(
        tester,
        () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(_l10n.album));
      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('bottomActionButton-visible'))
            .evaluate()
            .isNotEmpty,
        maxTries: 150,
      );
      await tester.tap(find.byKey(const ValueKey('bottomActionButton-visible')));
    }

    testWidgets(
      'PUT (to the signed URL) failing keeps the original committed photo, '
      'shows one error, and still cleans up both temp files (downloaded '
      "original + pending crop output) — a failure doesn't leak them",
      (tester) async {
        await tester.runAsync(() async {
          _useTallSurface(tester);
          String? downloadedOriginalPath;
          String? pendingUploadPath;
          final originalPath = await pumpWithCommittedBody(
            tester,
            onDownloadPathCreated: (p) => downloadedOriginalPath = p,
            upload: (kind, path) async {
              pendingUploadPath = path;
              throw Exception('PUT to signed url failed (500)');
            },
          );
          addTearDown(() => _deleteIfExists(originalPath));

          await changeBodyPhotoAndConfirm(tester);
          await _pumpUntil(
            tester,
            () => find.text(_l10n.photoUploadFailed).evaluate().isNotEmpty,
            maxTries: 100,
          );
          // Let the finally-block cleanups (both _uploadPhoto's and the
          // outer _changePhoto's) actually run before checking disk state.
          await tester.pump();

          expect(find.text(_l10n.photoUploadFailed), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MyVirtualModelPage)),
          );
          expect(container.read(profileProvider).value!.bodyRefUrl, originalPath);
          expect(_appImageFor(tester, originalPath).url, originalPath);
          expect(find.byType(AppSpinner), findsNothing);

          // Neither temp file this page created for this attempt survives
          // the failure — no accumulation across repeated failed attempts.
          expect(downloadedOriginalPath, isNotNull);
          expect(
            File(downloadedOriginalPath!).existsSync(),
            isFalse,
            reason: 'downloaded original temp file should be cleaned up',
          );
          expect(pendingUploadPath, isNotNull);
          expect(
            File(pendingUploadPath!).existsSync(),
            isFalse,
            reason:
                'pending crop-output temp file should be cleaned up even '
                'after a failed upload',
          );
          // The committed photo itself is untouched, of course.
          expect(File(originalPath).existsSync(), isTrue);
        });
      },
    );

    testWidgets(
      "complete failing (backend response missing object_url) keeps the "
      "original committed photo and shows one error",
      (tester) async {
        await tester.runAsync(() async {
          _useTallSurface(tester);
          final originalPath = await pumpWithCommittedBody(
            tester,
            upload: (kind, path) async =>
                throw Exception('bodyRefComplete: response missing object_url'),
          );
          addTearDown(() => _deleteIfExists(originalPath));

          await changeBodyPhotoAndConfirm(tester);
          await _pumpUntil(
            tester,
            () => find.text(_l10n.photoUploadFailed).evaluate().isNotEmpty,
            maxTries: 100,
          );

          expect(find.text(_l10n.photoUploadFailed), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MyVirtualModelPage)),
          );
          expect(container.read(profileProvider).value!.bodyRefUrl, originalPath);
          expect(find.byType(AppSpinner), findsNothing);
        });
      },
    );

    testWidgets(
      "the new URL failing its load-verification keeps the original "
      "committed photo, even though the upload call itself 'succeeded'",
      (tester) async {
        await tester.runAsync(() async {
          _useTallSurface(tester);
          final newPath = _writeTempPng('would_be_new_body');
          final originalPath = await pumpWithCommittedBody(
            tester,
            upload: (kind, path) async => newPath,
            verify: (context, url) async =>
                throw Exception('could not load $url'),
          );
          addTearDown(() {
            _deleteIfExists(originalPath);
            _deleteIfExists(newPath);
          });

          await changeBodyPhotoAndConfirm(tester);
          await _pumpUntil(
            tester,
            () => find.text(_l10n.photoUploadFailed).evaluate().isNotEmpty,
            maxTries: 100,
          );

          expect(find.text(_l10n.photoUploadFailed), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MyVirtualModelPage)),
          );
          // Still the ORIGINAL url — never the unverified new one.
          expect(container.read(profileProvider).value!.bodyRefUrl, originalPath);
          expect(_appImageFor(tester, originalPath).url, originalPath);
        });
      },
    );

    testWidgets(
      'a fully successful upload only THEN commits the new URL to '
      'profileProvider and the card, and cleans up both its own temp files '
      '(the downloaded original and the pending crop output — neither is '
      'the new committed photo itself, which lives on the backend, not '
      'this device)',
      (tester) async {
        await tester.runAsync(() async {
          _useTallSurface(tester);
          final newPath = _writeTempPng('new_body');
          var verifiedUrl = '';
          String? downloadedOriginalPath;
          String? pendingUploadPath;
          final originalPath = await pumpWithCommittedBody(
            tester,
            onDownloadPathCreated: (p) => downloadedOriginalPath = p,
            upload: (kind, path) async {
              pendingUploadPath = path;
              return newPath;
            },
            verify: (context, url) async => verifiedUrl = url,
          );
          addTearDown(() {
            _deleteIfExists(originalPath);
            _deleteIfExists(newPath);
          });

          // Still the original, pre-upload — never optimistically swapped.
          expect(_appImageFor(tester, originalPath).url, originalPath);

          await changeBodyPhotoAndConfirm(tester);
          await _pumpUntil(
            tester,
            () => _hasAppImageWithUrl(tester, newPath),
            maxTries: 150,
          );
          await tester.pump(); // let the finally-block cleanups run.

          expect(verifiedUrl, newPath);
          expect(downloadedOriginalPath, isNotNull);
          expect(
            File(downloadedOriginalPath!).existsSync(),
            isFalse,
            reason: 'downloaded original temp file should be cleaned up',
          );
          expect(pendingUploadPath, isNotNull);
          expect(
            File(pendingUploadPath!).existsSync(),
            isFalse,
            reason: 'pending crop-output temp file should be cleaned up '
                'once the upload succeeds',
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MyVirtualModelPage)),
          );
          expect(container.read(profileProvider).value!.bodyRefUrl, newPath);
          expect(find.byType(AppSpinner), findsNothing);
        });
      },
    );

    testWidgets(
      'a slow prepare step disables the card entirely (no repeated tap '
      'possible) until the whole change-photo flow finishes',
      (tester) async {
        await tester.runAsync(() async {
          _useTallSurface(tester);
          var downloadCalls = 0;
          final gate = Completer<String?>();
          final originalPath = _writeTempPng('committed_body_guard');
          addTearDown(() => _deleteIfExists(originalPath));
          final profile = ProfileData(
            profile: const UserProfile(name: 'Test User'),
            bodyRefUrl: originalPath,
          );

          await pumpApp(
            tester,
            const MyVirtualModelPage(),
            overrides: [
              profileProvider.overrideWith(() => _FakeProfileNotifier(data: profile)),
              downloadReferencePhotoOriginalProvider.overrideWithValue(
                ({
                  required String url,
                  required String fileNamePrefix,
                  required Future<String?> Function() onRefreshUrl,
                  required void Function(String freshUrl) onUrlRefreshed,
                }) {
                  downloadCalls++;
                  return gate.future;
                },
              ),
              uploadReferencePhotoProvider.overrideWithValue(
                (kind, path) async => path,
              ),
              verifyReferencePhotoLoadsProvider.overrideWithValue(
                (context, url) async {},
              ),
            ],
          );
          await tester.pump();
          await tester.pump();

          await tester.tap(find.byKey(const ValueKey('updatePhotoAction-body')));
          await tester.pump();

          // The card's own tap target disappears entirely while busy — the
          // guard disables the trigger itself, not just an internal flag
          // (see CLAUDE.md's double-invocation guard).
          expect(find.byKey(const ValueKey('updatePhotoAction-body')), findsNothing);
          expect(downloadCalls, 1);

          gate.complete(originalPath);
          await _pumpUntil(
            tester,
            () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
          );
          // requireChangeToConfirm: true — reopening the committed photo
          // unchanged never enables Confirm, so pick a new source first.
          await tester.tap(find.text(_l10n.album));
          await _pumpUntil(
            tester,
            () => find
                .byKey(const ValueKey('bottomActionButton-visible'))
                .evaluate()
                .isNotEmpty,
            maxTries: 150,
          );
          await tester.tap(find.byKey(const ValueKey('bottomActionButton-visible')));
          await _pumpUntil(
            tester,
            () => find
                .byKey(const ValueKey('updatePhotoAction-body'))
                .evaluate()
                .isNotEmpty,
            maxTries: 150,
          );

          // Guard released once the whole flow finished — the prepare step
          // was only ever invoked once, from the one tap that was allowed
          // through.
          expect(downloadCalls, 1);
          expect(find.byKey(const ValueKey('updatePhotoAction-body')), findsOneWidget);
        });
      },
    );

    testWidgets(
      'no committed photo yet: a failed upload leaves the placeholder in '
      'place — never a pending photo, and profileProvider stays null',
      (tester) async {
        await tester.runAsync(() async {
          _useTallSurface(tester);
          const profile = ProfileData(profile: UserProfile(name: 'Test User'));
          await pumpApp(
            tester,
            const MyVirtualModelPage(),
            overrides: [
              profileProvider.overrideWith(() => _FakeProfileNotifier(data: profile)),
              uploadReferencePhotoProvider.overrideWithValue(
                (kind, path) async => throw Exception('upload failed'),
              ),
            ],
          );
          await tester.pump();
          await tester.pump();

          // No committed photo for either slot — placeholder, no AppImage.
          expect(find.byType(AppImage), findsNothing);
          expect(find.text(_l10n.addPhotoAction), findsWidgets);

          // committedUrl is null, so _changePhoto skips the download/prepare
          // step entirely and opens the editor directly for a fresh pick.
          await tester.tap(find.byKey(const ValueKey('updatePhotoAction-body')));
          await _pumpUntil(
            tester,
            () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
          );

          await tester.tap(find.text(_l10n.album));
          await _pumpUntil(
            tester,
            () => find
                .byKey(const ValueKey('bottomActionButton-visible'))
                .evaluate()
                .isNotEmpty,
            maxTries: 150,
          );
          await tester.tap(find.byKey(const ValueKey('bottomActionButton-visible')));

          await _pumpUntil(
            tester,
            () => find.text(_l10n.photoUploadFailed).evaluate().isNotEmpty,
            maxTries: 100,
          );

          expect(find.text(_l10n.photoUploadFailed), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(MyVirtualModelPage)),
          );
          expect(container.read(profileProvider).value!.bodyRefUrl, isNull);
          // Still no AppImage anywhere — the placeholder never budged.
          expect(find.byType(AppImage), findsNothing);
          expect(find.text(_l10n.addPhotoAction), findsWidgets);
        });
      },
    );
  });

  group('generate base model', () {
    testWidgets(
      'the Generate action is disabled with a hint when no body reference '
      'is set — face reference alone is not enough',
      (tester) async {
        const profile = ProfileData(
          profile: UserProfile(name: 'Test User'),
          faceRefUrl: 'https://example.com/face.jpg',
        );
        await pumpApp(
          tester,
          const MyVirtualModelPage(),
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier(data: profile)),
          ],
        );
        await tester.pump();

        expect(
          find.text(_l10n.virtualModelGenerateRequiresBodyRefHint),
          findsOneWidget,
        );
        final pill = tester.widget<AccentPillButton>(find.byType(AccentPillButton));
        expect(pill.enabled, isFalse);
      },
    );

    testWidgets(
      'tapping Generate with a body reference set confirms first, then '
      'calls ProfileService.generateBaseModel, commits its returned URL, '
      'and shows a success dialog',
      (tester) async {
        _useTallSurface(tester);
        var calls = 0;
        await pumpApp(
          tester,
          const MyVirtualModelPage(),
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
            // A real https:// URL here would make GeneratedImageCard render it
            // through a genuine RefreshableNetworkImage fetch — unlike
            // AppImage, it has no local-file branch — which needs a sqflite
            // factory this suite's harness doesn't set up; the resulting
            // background failure leaks past this test as a stray reported
            // exception no amount of draining catches. Returning '' instead
            // still exercises the exact same commit path (see
            // ProfileNotifier.setBaseModelUrl) without ever entering that
            // render branch; the URL itself is covered directly, with a
            // real-looking value, in profile_provider_test.dart.
            generateBaseModelProvider.overrideWithValue(() async {
              calls++;
              return '';
            }),
          ],
        );
        await tester.pump();

        final pill = tester.widget<AccentPillButton>(find.byType(AccentPillButton));
        expect(pill.enabled, isTrue);
        await tester.tap(find.byType(AccentPillButton));
        await tester.pumpAndSettle();

        // Confirmed first — the call hasn't happened yet.
        expect(find.text(_l10n.virtualModelGenerateConfirmTitle), findsOneWidget);
        expect(calls, 0);

        await tester.tap(find.text(_l10n.virtualModelGenerateAction).last);
        await tester.pumpAndSettle();

        expect(calls, 1);
        expect(find.text(_l10n.virtualModelGenerateSuccessBody), findsOneWidget);

        final container = ProviderScope.containerOf(
          tester.element(find.byType(MyVirtualModelPage)),
        );
        expect(container.read(profileProvider).value!.baseModelUrl, '');
      },
    );

    testWidgets(
      'a failed generation shows an error dialog instead of the success one',
      (tester) async {
        _useTallSurface(tester);
        await pumpApp(
          tester,
          const MyVirtualModelPage(),
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
            generateBaseModelProvider.overrideWithValue(
              () async => throw Exception('boom'),
            ),
          ],
        );
        await tester.pump();

        await tester.tap(find.byType(AccentPillButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_l10n.virtualModelGenerateAction).last);
        await tester.pumpAndSettle();

        expect(find.text(_l10n.virtualModelGenerateFailed), findsOneWidget);
        expect(find.text(_l10n.virtualModelGenerateSuccessBody), findsNothing);
      },
    );

    testWidgets(
      'each successful generation bumps the image cache key, so a '
      "regenerate can't keep showing flutter_cache_manager's stale cached "
      'bytes under a cache key that never changed',
      (tester) async {
        _useTallSurface(tester);
        var calls = 0;
        await pumpApp(
          tester,
          const MyVirtualModelPage(),
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
            generateBaseModelProvider.overrideWithValue(() async {
              calls++;
              return '';
            }),
          ],
        );
        await tester.pump();

        String cacheKeyOf() =>
            tester
                .widget<GeneratedImageCard>(find.byType(GeneratedImageCard))
                .cacheKey!;

        final beforeAnyGenerate = cacheKeyOf();

        await tester.tap(find.byType(AccentPillButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_l10n.virtualModelGenerateAction).last);
        await tester.pumpAndSettle();
        await tester.tap(find.text(_l10n.ok));
        await tester.pumpAndSettle();

        final afterFirstGenerate = cacheKeyOf();
        expect(afterFirstGenerate, isNot(beforeAnyGenerate));

        await tester.tap(find.byType(AccentPillButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text(_l10n.virtualModelGenerateAction).last);
        await tester.pumpAndSettle();

        expect(calls, 2);
        expect(cacheKeyOf(), isNot(afterFirstGenerate));
      },
    );
  });
}
