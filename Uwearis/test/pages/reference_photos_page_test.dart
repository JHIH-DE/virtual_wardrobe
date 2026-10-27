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
import 'package:uwearis/core/utils/base_model_generation_mixin.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/image_editor_page.dart';
import 'package:uwearis/features/pages/reference_photos_page.dart';
import 'package:uwearis/features/widgets/common/buttons/accent_pill_button.dart';
import 'package:uwearis/features/widgets/common/images/app_image.dart';
import 'package:uwearis/features/widgets/common/images/app_spinner.dart';
import 'package:uwearis/features/widgets/common/overlays/loading_overlay.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';
import '../helpers/text_scale_harness.dart';
import '../helpers/widget_harness.dart';

final _l10n = AppLocalizationsEn();

/// A fully set-up profile (both reference photos + height/weight) by default.
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

/// `GET /users/me` itself failing — the whole-page error path.
class _FailingProfileNotifier extends ProfileNotifier {
  @override
  Future<ProfileData> build() async => throw Exception('boom');
}

Future<void> _pumpReferencePhotosPage(
  WidgetTester tester, {
  ProfileNotifier? notifier,
  Duration? Function(int retryCount, Object error)? retry,
}) {
  return pumpApp(
    tester,
    const ReferencePhotosPage(),
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

/// Whether a change-photo attempt has fully wound down: the uploading
/// spinner is gone and both temp files it created are deleted.
bool _cleanupFinished(String? downloadedOriginalPath, String? pendingPath) =>
    find.byType(AppSpinner).evaluate().isEmpty &&
    (downloadedOriginalPath == null ||
        !File(downloadedOriginalPath).existsSync()) &&
    (pendingPath == null || !File(pendingPath).existsSync());

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  int maxTries = 60,
}) async {
  for (var i = 0; i < maxTries && !condition(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));
    // Drain the http:// committed photo's real CachedNetworkImage fetch
    // failure (no sqflite factory in tests); unrelated to what's polled.
    while (tester.takeException() != null) {}
  }
}

void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A real 1x1 PNG — precacheImage needs decodable bytes to resolve.
final _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4z8AAAAMBAQDJ'
  '/pLvAAAAAElFTkSuQmCC',
);

/// Local-file fixtures avoid the cache manager: AppImage renders a bare
/// local path via Image.file.
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

/// flutter_cache_manager asks path_provider for a cache dir on the first
/// real network image load; unmocked, the MissingPluginException stalls every
/// other pending image future. Only the http:// "prepare fails" group needs it.
void _mockPathProviderChannel() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        channel,
        (call) async => Directory.systemTemp.path,
      );
}

/// Ignores the URL and returns a fresh decodable PNG each call.
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

/// Makes ImageEditorPage's "Album" return a real local file; unmocked,
/// `ImagePicker.pickImage` hangs/throws in a flutter_test VM run.
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

/// The image editor's own Confirm — the photos page has a bottom button too.
final _editorConfirm = find.descendant(
  of: find.byType(ImageEditorPage),
  matching: find.byKey(const ValueKey('bottomActionButton-visible')),
);

/// The full-body card's pill is shown (disabled) while the page is busy, so
/// waiting for it means waiting for it to be enabled.
bool _bodyActionEnabled(WidgetTester tester) {
  final pill = find.byKey(const ValueKey('updatePhotoAction-body'));
  return pill.evaluate().isNotEmpty &&
      tester.widget<AccentPillButton>(pill).enabled;
}

void main() {
  setUp(setUpFakeAuth);

  testWidgets(
    'a body reference image load failure switches only the body card into '
    'its re-upload state — face card and the page-level error banner are '
    'all untouched',
    (tester) async {
      await _pumpReferencePhotosPage(tester);
      await tester.pump();

      expect(find.text(_l10n.fullBodyPhotoLabel), findsOneWidget);
      expect(find.text(_l10n.facePhotoLabel), findsOneWidget);
      expect(find.byType(AppImage), findsNWidgets(2));

      _appImageFor(tester, 'body').onLoadError!();
      await tester.pump();

      expect(find.text(_l10n.fullBodyPhotoLoadFailedTitle), findsOneWidget);
      expect(find.text(_l10n.photoLoadFailedSubtitle), findsOneWidget);
      expect(find.text(_l10n.reuploadPhotoAction), findsOneWidget);
      expect(find.text(_l10n.fullBodyPhotoLabel), findsNothing);

      expect(find.text(_l10n.facePhotoLabel), findsOneWidget);
      expect(find.byType(AppImage), findsOneWidget);

      expect(find.text(_l10n.failedToLoad), findsNothing);
    },
  );

  testWidgets(
    'a face reference image load failure switches only the face card into '
    'its re-upload state — body card and the page-level error banner are '
    'all untouched',
    (tester) async {
      await _pumpReferencePhotosPage(tester);
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
      await _pumpReferencePhotosPage(
        tester,
        notifier: _FailingProfileNotifier(),
        // Belt-and-braces: appRetryPolicy already doesn't retry a plain
        // Exception; this keeps the failure terminal regardless.
        retry: (_, _) => null,
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.failedToLoad), findsOneWidget);
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
      await _pumpReferencePhotosPage(tester);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReferencePhotosPage)),
      );
      final initialUrl = container.read(profileProvider).value!.bodyRefUrl!;
      expect(initialUrl, 'https://example.com/body.jpg');

      _appImageFor(tester, 'body').onUrlRefreshed!(
        initialUrl,
        'https://example.com/body-refreshed.jpg',
      );
      await tester.pump();

      expect(
        container.read(profileProvider).value!.bodyRefUrl,
        'https://example.com/body-refreshed.jpg',
      );
      expect(
        _appImageFor(tester, 'body-refreshed').url,
        'https://example.com/body-refreshed.jpg',
      );

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
      await _pumpReferencePhotosPage(tester);
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReferencePhotosPage)),
      );
      final originalUrl = container.read(profileProvider).value!.bodyRefUrl!;

      // A newer upload has already committed a different URL.
      container
          .read(profileProvider.notifier)
          .setBodyRefUrl('https://example.com/body-newly-uploaded.jpg');
      await tester.pump();

      // A refresh started against the original URL resolves only now.
      _appImageFor(tester, 'newly-uploaded').onUrlRefreshed!(
        originalUrl,
        'https://example.com/body-STALE-refresh-result.jpg',
      );
      await tester.pump();

      expect(
        container.read(profileProvider).value!.bodyRefUrl,
        'https://example.com/body-newly-uploaded.jpg',
      );
    },
  );

  group(
    'change photo — prepares a local original before opening the editor',
    () {
      const originalBodyUrl = 'https://storage.example.com/body-original.jpg';

      // Uses the real download provider and a real http:// URL; upload
      // commit/rollback is covered by the fake-backed group below.
      http.Client mockBackend({required bool downloadOriginalSucceeds}) {
        return MockClient((request) async {
          final path = request.url.path;
          if (request.method == 'GET' && path.endsWith('/users/me')) {
            return jsonResponse(
              envelope(_profileJson(bodyRefUrl: originalBodyUrl)),
            );
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
              await pumpApp(tester, const ReferencePhotosPage());
              await _pumpUntil(tester, () => _bodyActionEnabled(tester));

              await tester.tap(
                find.byKey(const ValueKey('updatePhotoAction-body')),
              );
              await _pumpUntil(
                tester,
                () => find
                    .text(_l10n.photoProcessingFailed)
                    .evaluate()
                    .isNotEmpty,
              );

              expect(find.text(_l10n.photoProcessingFailed), findsOneWidget);
              expect(find.byType(ImageEditorPage), findsNothing);

              final pill = tester.widget<AccentPillButton>(
                find.byKey(const ValueKey('updatePhotoAction-body')),
              );
              expect(pill.enabled, isTrue);
            }, () => client);
          });
        },
      );
    },
  );

  group('upload commit and rollback (fake upload/download/verify — no real '
      'network or flutter_cache_manager)', () {
    // `requireChangeToConfirm: true` — Confirm only enables after picking a
    // new source (Album), so the image_picker fake is wired for the group.
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

    /// Returns the committed local-file body photo's path.
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
        const ReferencePhotosPage(),
        overrides: [
          profileProvider.overrideWith(
            () => _FakeProfileNotifier(data: profile),
          ),
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

    /// Drives the body photo through editor → Album pick → Confirm.
    Future<void> changeBodyPhotoAndConfirm(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('updatePhotoAction-body')));
      await _pumpUntil(
        tester,
        () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
      );
      await tester.tap(find.text(_l10n.album));
      await _pumpUntil(
        tester,
        () => _editorConfirm.evaluate().isNotEmpty,
        maxTries: 150,
      );
      await tester.tap(_editorConfirm);
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
          // The dialog shows before the finally-block cleanups' real file
          // I/O; a single pump loses that race on a loaded machine.
          await _pumpUntil(
            tester,
            () => _cleanupFinished(downloadedOriginalPath, pendingUploadPath),
            maxTries: 100,
          );

          expect(find.text(_l10n.photoUploadFailed), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ReferencePhotosPage)),
          );
          expect(
            container.read(profileProvider).value!.bodyRefUrl,
            originalPath,
          );
          expect(_appImageFor(tester, originalPath).url, originalPath);
          expect(find.byType(AppSpinner), findsNothing);

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

          await _pumpUntil(
            tester,
            () => find.byType(AppSpinner).evaluate().isEmpty,
            maxTries: 100,
          );

          expect(find.text(_l10n.photoUploadFailed), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ReferencePhotosPage)),
          );
          expect(
            container.read(profileProvider).value!.bodyRefUrl,
            originalPath,
          );
          expect(find.byType(AppSpinner), findsNothing);
        });
      },
    );

    testWidgets("the new URL failing its load-verification keeps the original "
        "committed photo, even though the upload call itself 'succeeded'", (
      tester,
    ) async {
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
          tester.element(find.byType(ReferencePhotosPage)),
        );
        expect(container.read(profileProvider).value!.bodyRefUrl, originalPath);
        expect(_appImageFor(tester, originalPath).url, originalPath);
      });
    });

    testWidgets('a fully successful upload only THEN commits the new URL to '
        'profileProvider and the card, and cleans up both its own temp files '
        '(the downloaded original and the pending crop output — neither is '
        'the new committed photo itself, which lives on the backend, not '
        'this device)', (tester) async {
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

        expect(_appImageFor(tester, originalPath).url, originalPath);

        await changeBodyPhotoAndConfirm(tester);
        await _pumpUntil(
          tester,
          () => _hasAppImageWithUrl(tester, newPath),
          maxTries: 150,
        );
        await _pumpUntil(
          tester,
          () => _cleanupFinished(downloadedOriginalPath, pendingUploadPath),
          maxTries: 100,
        );

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
          reason:
              'pending crop-output temp file should be cleaned up '
              'once the upload succeeds',
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(ReferencePhotosPage)),
        );
        expect(container.read(profileProvider).value!.bodyRefUrl, newPath);
        expect(find.byType(AppSpinner), findsNothing);
      });
    });

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
            const ReferencePhotosPage(),
            overrides: [
              profileProvider.overrideWith(
                () => _FakeProfileNotifier(data: profile),
              ),
              downloadReferencePhotoOriginalProvider.overrideWithValue(({
                required String url,
                required String fileNamePrefix,
                required Future<String?> Function() onRefreshUrl,
                required void Function(String freshUrl) onUrlRefreshed,
              }) {
                downloadCalls++;
                return gate.future;
              }),
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

          await tester.tap(
            find.byKey(const ValueKey('updatePhotoAction-body')),
          );
          await tester.pump();

          expect(
            tester
                .widget<AccentPillButton>(
                  find.byKey(const ValueKey('updatePhotoAction-body')),
                )
                .enabled,
            isFalse,
          );
          expect(downloadCalls, 1);

          gate.complete(originalPath);
          await _pumpUntil(
            tester,
            () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
          );
          await tester.tap(find.text(_l10n.album));
          await _pumpUntil(
            tester,
            () => _editorConfirm.evaluate().isNotEmpty,
            maxTries: 150,
          );
          await tester.tap(_editorConfirm);
          await _pumpUntil(
            tester,
            () => _bodyActionEnabled(tester),
            maxTries: 150,
          );

          expect(downloadCalls, 1);
          expect(
            find.byKey(const ValueKey('updatePhotoAction-body')),
            findsOneWidget,
          );
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
            const ReferencePhotosPage(),
            overrides: [
              profileProvider.overrideWith(
                () => _FakeProfileNotifier(data: profile),
              ),
              uploadReferencePhotoProvider.overrideWithValue(
                (kind, path) async => throw Exception('upload failed'),
              ),
            ],
          );
          await tester.pump();
          await tester.pump();

          expect(find.byType(AppImage), findsNothing);
          expect(find.text(_l10n.addPhotoAction), findsWidgets);

          // No committed URL: the editor opens without a download step.
          await tester.tap(
            find.byKey(const ValueKey('updatePhotoAction-body')),
          );
          await _pumpUntil(
            tester,
            () => find.byType(ImageEditorPage).evaluate().isNotEmpty,
          );

          await tester.tap(find.text(_l10n.album));
          await _pumpUntil(
            tester,
            () => _editorConfirm.evaluate().isNotEmpty,
            maxTries: 150,
          );
          await tester.tap(_editorConfirm);

          await _pumpUntil(
            tester,
            () => find.text(_l10n.photoUploadFailed).evaluate().isNotEmpty,
            maxTries: 100,
          );

          expect(find.text(_l10n.photoUploadFailed), findsOneWidget);
          final container = ProviderScope.containerOf(
            tester.element(find.byType(ReferencePhotosPage)),
          );
          expect(container.read(profileProvider).value!.bodyRefUrl, isNull);
          expect(find.byType(AppImage), findsNothing);
          expect(find.text(_l10n.addPhotoAction), findsWidgets);
        });
      },
    );
  });

  group('generate new model (bottom button)', () {
    final generateButton = find.byKey(
      const ValueKey('bottomActionButton-visible'),
    );

    /// Over a placeholder route, so going back is observable.
    Future<void> pushPage(
      WidgetTester tester, {
      ProfileData? data,
      required GenerateBaseModel generate,
    }) async {
      _useTallSurface(tester);
      await pumpApp(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReferencePhotosPage()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        overrides: [
          profileProvider.overrideWith(() => _FakeProfileNotifier(data: data)),
          generateBaseModelProvider.overrideWithValue(generate),
        ],
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('hidden until there is a full-body photo', (tester) async {
      await pushPage(
        tester,
        data: const ProfileData(
          profile: UserProfile(name: 'Test User'),
          faceRefUrl: 'https://example.com/face.jpg',
        ),
        generate: () async => fail('must not generate'),
      );
      expect(generateButton, findsNothing);
      expect(find.text(_l10n.virtualModelGenerateNewAction), findsNothing);
    });

    testWidgets('generates right away without a confirmation, commits the '
        'new model, then returns to the previous page with no success '
        'dialog', (tester) async {
      var calls = 0;
      await pushPage(
        tester,
        // '' not a real URL: a real fetch needs a sqflite factory.
        generate: () async {
          calls++;
          return '';
        },
      );
      expect(find.text(_l10n.virtualModelGenerateNewAction), findsOneWidget);

      await tester.tap(find.text(_l10n.virtualModelGenerateNewAction));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.virtualModelGenerateConfirmTitle), findsNothing);
      expect(calls, 1);
      // No "Done" dialog: straight back to the previous page.
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(ReferencePhotosPage), findsNothing);
      final container = ProviderScope.containerOf(
        tester.element(find.text('open')),
      );
      expect(container.read(profileProvider).value!.baseModelUrl, '');
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a double tap still generates only once', (tester) async {
      var calls = 0;
      final pending = Completer<String>();
      await pushPage(
        tester,
        generate: () {
          calls++;
          return pending.future;
        },
      );

      final button = find.text(_l10n.virtualModelGenerateNewAction);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(LoadingOverlay), findsOneWidget);

      pending.complete('');
      await tester.pumpAndSettle();
      expect(calls, 1);
    });

    testWidgets('a failed generation shows an error and stays on the page', (
      tester,
    ) async {
      await pushPage(tester, generate: () async => throw Exception('boom'));

      await tester.tap(find.text(_l10n.virtualModelGenerateNewAction));
      await tester.pumpAndSettle();

      expect(find.text(_l10n.virtualModelGenerateFailed), findsOneWidget);
      await tester.tap(find.text(_l10n.ok));
      await tester.pumpAndSettle();
      expect(find.byType(ReferencePhotosPage), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ReferencePhotosPage)),
      );
      expect(container.read(profileProvider).value!.baseModelUrl, isNull);
    });
  });

  group('layout with the bottom button', () {
    setUpAll(loadAppFont);

    for (final c in layoutCases) {
      testWidgets('${describeCase(c)}: the button label is whole and the '
          'last card scrolls clear of it', (tester) async {
        applyLayoutCase(tester, c);
        await pumpApp(
          tester,
          const ReferencePhotosPage(),
          overrides: [
            profileProvider.overrideWith(() => _FakeProfileNotifier()),
          ],
        );
        await tester.pump();
        await tester.pump();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(ReferencePhotosPage)),
        );
        final label = find.text(l10n.virtualModelGenerateNewAction);
        expect(label, findsOneWidget);
        expect(isTruncated(tester, label), isFalse);
        expectNoBrokenWords(tester, label);

        final scrollable = find.byType(Scrollable);
        await tester.drag(scrollable, const Offset(0, -2000));
        await tester.pump();
        final lastPill = find.byKey(const ValueKey('updatePhotoAction-body'));
        final button = find.byKey(const ValueKey('bottomActionButton-visible'));
        expect(
          tester.getRect(lastPill).bottom,
          lessThanOrEqualTo(tester.getRect(button).top),
        );
      });
    }
  });
}
