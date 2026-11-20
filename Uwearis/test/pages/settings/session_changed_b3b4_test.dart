import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/profile_provider.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/data/image_edit_result.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/user_profile.dart';
import 'package:uwearis/features/pages/common/image_editor_page.dart';
import 'package:uwearis/features/pages/common/login_page.dart';
import 'package:uwearis/features/pages/settings/my_outfit_profile_page.dart';
import 'package:uwearis/features/pages/settings/personal_details_page.dart';
import 'package:uwearis/features/pages/settings/reference_photos_page.dart';
import 'package:uwearis/features/widgets/common/images/app_spinner.dart';
import 'package:uwearis/features/widgets/common/overlays/app_dialog.dart';
import 'package:uwearis/features/widgets/common/profile_avatar.dart';

import '../../helpers/mock_http.dart';
import '../../helpers/scripted_auth_storage.dart';
import '../../helpers/widget_harness.dart';

// Finding #1, B3 / B4: Personal Details' onboarding save and avatar
// upload, and Reference Photos' upload and change-photo prepare. A reply
// landing after its session ended fails with SessionChangedException; each
// entry point runs the same five scenarios as the earlier batches.

class _FakeProfile extends ProfileNotifier {
  _FakeProfile(this._data);
  final ProfileData _data;

  @override
  Future<ProfileData> build() async => _data;
}

final _aboutYou = ProfileData(
  profile: UserProfile(
    name: 'Test User',
    gender: 'Female',
    location: 'Taipei',
    birthDate: DateTime(1995, 1, 1),
  ),
);

const _withBodyPhoto = ProfileData(
  profile: UserProfile(name: 'Test User'),
  bodyRefUrl: 'https://example.com/body.jpg',
);

/// A crop output the editor hands back; the upload must delete it.
late File _pendingCrop;

/// One entry point under test.
class _Entry {
  _Entry({
    required this.name,
    required this.page,
    required this.profile,
    required this.trigger,
    required this.isOwnRequest,
    required this.okReply,
    required this.failure,
    required this.unchanged,
    this.fileIo = false,
  });

  final String name;
  final Widget page;
  final ProfileData profile;
  final Future<void> Function(WidgetTester tester) trigger;
  final bool Function(http.Request request) isOwnRequest;
  final http.Response Function() okReply;

  /// The error copy a same-session failure shows.
  final Finder failure;

  /// After the session ended: nothing opened or written, previews rolled
  /// back, loading cleared, temp files gone.
  final void Function(WidgetTester tester, ProviderContainer container)
  unchanged;

  /// The flow's cleanup does real file I/O, which only completes outside
  /// the fake-async zone.
  final bool fileIo;
}

class _Backend {
  _Backend(this.entry);
  final _Entry entry;
  final _held = <Completer<http.Response>>[];
  final requests = <String>[];
  int ownSends = 0;

  int get heldCount => _held.length;

  void release(http.Response res) {
    for (final c in _held) {
      if (!c.isCompleted) c.complete(res);
    }
  }

  MockClient client() => MockClient((req) async {
    requests.add('${req.method} ${req.url}');
    if (entry.isOwnRequest(req)) {
      ownSends++;
      final c = Completer<http.Response>();
      _held.add(c);
      return c.future;
    }
    if (req.url.path.endsWith('/auth/refresh')) {
      return http.Response('{}', 401);
    }
    if (req.url.host == 'example.com') return http.Response('', 404);
    return jsonResponse(envelope({'name': 'Test User'}));
  });
}

late _Backend _backend;

final _sessionExpired = find.text('Session Expired');
final _retry = find.text('Retry');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// Hands the editor back [path], as Confirm does.
Future<void> _confirmEditor(WidgetTester tester, String path) async {
  await _settle(tester);
  Navigator.of(
    tester.element(find.byType(ImageEditorPage)),
  ).pop(ImageEditResult(imagePath: path));
  await tester.pump();
}

bool _isPatchOf(http.Request r, String field) {
  if (r.method != 'PATCH' || !r.url.path.endsWith('/users/me')) return false;
  return (jsonDecode(r.body) as Map).containsKey(field);
}

final _entries = <_Entry>[
  _Entry(
    name: 'PersonalDetailsPage._saveProfile (onboarding Continue)',
    page: const PersonalDetailsPage(completingOnboarding: true),
    profile: _aboutYou,
    trigger: (tester) async {
      await tester.enterText(find.byType(TextField).first, 'New name');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
    },
    isOwnRequest: (r) => _isPatchOf(r, 'name'),
    okReply: () => jsonResponse(envelope({'name': 'New name'})),
    failure: find.text("Couldn't save your profile. Please try again."),
    unchanged: (tester, _) {
      expect(find.byType(MyOutfitProfilePage), findsNothing, reason: 'next');
      expect(find.byType(PersonalDetailsPage), findsOneWidget);
    },
  ),
  _Entry(
    name: 'PersonalDetailsPage._uploadAvatar',
    page: const PersonalDetailsPage(),
    profile: _aboutYou,
    trigger: (tester) async {
      await tester.tap(find.byType(ProfileAvatar));
      await _confirmEditor(tester, '/tmp/uwearis_session_avatar.jpg');
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
        isNotNull,
        reason: 'the new photo shows while it uploads',
      );
    },
    isOwnRequest: (r) => r.url.path.endsWith('/users/me/avatar/init-upload'),
    okReply: () => jsonResponse(
      envelope({'upload_url': 'https://example.com/u', 'object_name': 'o'}),
    ),
    failure: find.text("Couldn't upload photo. Please try again."),
    unchanged: (tester, c) {
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
        isNull,
        reason: 'back to the saved (no) avatar',
      );
      expect(c.read(profileProvider).value!.profile.avatarObjectUrl, isNull);
    },
  ),
  _Entry(
    name: 'ReferencePhotosPage._uploadPhoto',
    page: const ReferencePhotosPage(),
    profile: const ProfileData(profile: UserProfile(name: 'Test User')),
    fileIo: true,
    trigger: (tester) async {
      await tester.tap(find.byKey(const ValueKey('updatePhotoAction-body')));
      await _confirmEditor(tester, _pendingCrop.path);
      expect(find.byType(AppSpinner), findsOneWidget, reason: 'uploading');
    },
    isOwnRequest: (r) =>
        r.url.path.endsWith('/users/me/body-reference/init-upload'),
    okReply: () => jsonResponse(
      envelope({'upload_url': 'https://example.com/u', 'object_name': 'o'}),
    ),
    failure: find.text("Couldn't upload photo. Please try again."),
    unchanged: (tester, c) {
      expect(find.byType(AppSpinner), findsNothing, reason: 'uploading');
      expect(_pendingCrop.existsSync(), isFalse, reason: 'temp file');
      expect(c.read(profileProvider).value!.bodyRefUrl, isNull);
    },
  ),
  _Entry(
    name: 'ReferencePhotosPage._changePhoto (preparing the original)',
    page: const ReferencePhotosPage(),
    profile: _withBodyPhoto,
    trigger: (tester) async {
      // The download fails, so it asks for a fresh URL: that's held.
      await tester.tap(find.byKey(const ValueKey('updatePhotoAction-body')));
      await tester.pump();
      await tester.pump();
    },
    isOwnRequest: (r) => r.method == 'GET' && r.url.path.endsWith('/users/me'),
    okReply: () => jsonResponse(
      envelope({'body_reference_object_url': 'https://example.com/fresh.jpg'}),
    ),
    failure: find.text(
      "Couldn't process this photo. Please try a different one.",
    ),
    unchanged: (tester, c) {
      expect(find.byType(ImageEditorPage), findsNothing, reason: 'next step');
      expect(
        c.read(profileProvider).value!.bodyRefUrl,
        'https://example.com/body.jpg',
      );
      expect(_backend.ownSends, 1, reason: 'not asked again');
    },
  ),
];

void main() {
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
    _pendingCrop = File(
      '${Directory.systemTemp.path}/uwearis_b3b4_'
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    addTearDown(() {
      if (_pendingCrop.existsSync()) _pendingCrop.deleteSync();
    });
  });

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> closeDialogs(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      final buttons = find.byKey(AppDialog.dismissButtonKey);
      if (buttons.evaluate().isEmpty) break;
      await tester.tap(buttons.last);
      await _settle(tester);
    }
    while (tester.takeException() != null) {}
  }

  for (final e in _entries) {
    group(e.name, () {
      late BuildContext root;
      late ProviderContainer container;

      Future<void> start(WidgetTester tester) async {
        useTallSurface(tester);
        await pumpApp(
          tester,
          Builder(
            builder: (context) {
              root = context;
              return const Scaffold(body: Text('Root'));
            },
          ),
          overrides: [
            profileProvider.overrideWith(() => _FakeProfile(e.profile)),
          ],
          retry: (_, _) => null,
        );
        container = ProviderScope.containerOf(root);
        unawaited(
          Navigator.of(root).push(MaterialPageRoute(builder: (_) => e.page)),
        );
        await _settle(tester);
        await e.trigger(tester);
        expect(
          _backend.heldCount,
          1,
          reason: 'its request is in flight: ${_backend.requests}',
        );
      }

      /// The reply lands; lets any real file I/O in its cleanup finish.
      Future<void> land(WidgetTester tester, http.Response res) async {
        _backend.release(res);
        await tester.pump();
        if (e.fileIo) {
          for (var i = 0; i < 3; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump();
          }
        }
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<void> run(
        WidgetTester tester,
        Future<void> Function() body,
      ) async {
        _backend = _Backend(e);
        await http.runWithClient(body, _backend.client);
      }

      Future<void> signOutTo(Widget page) async {
        final navigator = Navigator.of(root);
        await clearSignedInSession();
        unawaited(
          navigator.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => page),
            (_) => false,
          ),
        );
      }

      testWidgets('session expired meanwhile: no error or Retry over Session '
          'Expired; rolled back and cleaned up', (tester) async {
        await run(tester, () async {
          await start(tester);
          unawaited(AuthExpiredHandler.handle(root));
          await tester.pump();
          await tester.pump();
          expect(_sessionExpired, findsOneWidget);

          await land(tester, e.okReply());

          final shown = {
            'error': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'sessionExpired': _sessionExpired.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
          };
          try {
            e.unchanged(tester, container);
          } finally {
            await closeDialogs(tester);
          }
          expect(shown, {
            'error': 0,
            'retry': 0,
            'sessionExpired': 1,
            'login': 0,
          });
        });
      });

      testWidgets('sign-out meanwhile: no error over the login page', (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          await signOutTo(const LoginPage());
          await tester.pump();
          await land(tester, e.okReply());
          await tester.pump(const Duration(seconds: 1));
          while (tester.takeException() != null) {}

          final shown = {
            'error': e.failure.evaluate().length,
            'retry': _retry.evaluate().length,
            'login': find.byType(LoginPage).evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'retry': 0, 'login': 1});
        });
      });

      testWidgets('a reply after the page is gone touches nothing', (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          await signOutTo(const Scaffold(body: Text('Signed out')));
          await tester.pump(const Duration(seconds: 1));
          await tester.pump(const Duration(seconds: 1));
          await land(tester, e.okReply());
          await tester.pump(const Duration(seconds: 1));

          expect(tester.takeException(), isNull);
          expect(find.text('Signed out'), findsOneWidget);
          expect(find.byType(AppDialog), findsNothing);
        });
      });

      testWidgets("the same session's 500 still shows its error", (
        tester,
      ) async {
        await run(tester, () async {
          await start(tester);
          await land(tester, jsonResponse(envelope(null), status: 500));

          final shown = e.failure.evaluate().length;
          await closeDialogs(tester);
          expect(shown, 1);
        });
      });

      testWidgets("the same session's own expiry still goes to Session "
          'Expired', (tester) async {
        await run(tester, () async {
          await start(tester);
          await land(tester, http.Response('{}', 401));
          await tester.pump();

          final shown = {
            'error': e.failure.evaluate().length,
            'sessionExpired': _sessionExpired.evaluate().length,
          };
          await closeDialogs(tester);
          expect(shown, {'error': 0, 'sessionExpired': 1});
        });
      });
    });
  }
}
