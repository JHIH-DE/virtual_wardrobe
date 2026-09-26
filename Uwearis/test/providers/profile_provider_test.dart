import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/providers/profile_provider.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> _profile({String? bodyRefUrl, String? faceRefUrl}) => {
  'name': 'Test User',
  'body_reference_object_url': bodyRefUrl,
  'face_reference_object_url': faceRefUrl,
};

/// Runs [body] with profileProvider seeded from one `GET /users/me`
/// response — getMyProfile/getBodyRef/getFaceReference all hit that same
/// endpoint (see profile_service.dart's own doc), so one handler covers
/// every call `build()` makes.
Future<void> withProfile(
  Map<String, dynamic> profileJson,
  Future<void> Function(ProviderContainer container) body,
) {
  final client = MockClient((_) async => jsonResponse(envelope(profileJson)));
  return http.runWithClient(() async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(profileProvider.future);
    await body(container);
  }, () => client);
}

void main() {
  setUp(setUpFakeAuth);

  test('build() issues exactly one GET /users/me request, not one per '
      'field (profile / body ref / face ref used to be 3 separate '
      'Future.wait calls to this same endpoint)', () async {
    var requestCount = 0;
    final client = MockClient((_) async {
      requestCount++;
      return jsonResponse(envelope(_profile()));
    });

    await http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(profileProvider.future);
      expect(requestCount, 1);
    }, () => client);
  });

  group('optimistic mutations', () {
    // Regression: uploading a reference photo used to call refresh()
    // (a fresh GET /users/me) right after the upload completed — but the
    // backend's `complete` endpoint can kick off async server-side
    // processing (see ProfileService._completeTimeout's doc), so that
    // immediate re-fetch could race it and read back a still-null
    // body_reference_object_url, leaving Home's Getting Started checklist
    // showing the photo as missing until the next full sign-in re-fetched
    // it correctly. setBodyRefUrl/setFaceRefUrl apply the URL the upload's
    // own response already returned, instead of asking the backend again.
    test('setBodyRefUrl reflects the upload result in place, without a '
        're-fetch', () {
      return withProfile(_profile(), (c) async {
        expect(c.read(profileProvider).value!.bodyRefUrl, isNull);
        c
            .read(profileProvider.notifier)
            .setBodyRefUrl('https://example.com/body-new.jpg');
        expect(
          c.read(profileProvider).value!.bodyRefUrl,
          'https://example.com/body-new.jpg',
        );
      });
    });

    test('setFaceRefUrl reflects the upload result in place, without a '
        're-fetch', () {
      return withProfile(_profile(), (c) async {
        expect(c.read(profileProvider).value!.faceRefUrl, isNull);
        c
            .read(profileProvider.notifier)
            .setFaceRefUrl('https://example.com/face-new.jpg');
        expect(
          c.read(profileProvider).value!.faceRefUrl,
          'https://example.com/face-new.jpg',
        );
      });
    });

    test('setBaseModelUrl reflects a just-completed generateBaseModel '
        'result in place — there is no GET for this value, so this is the '
        'only way it ever reaches state', () {
      return withProfile(_profile(), (c) async {
        expect(c.read(profileProvider).value!.baseModelUrl, isNull);
        c
            .read(profileProvider.notifier)
            .setBaseModelUrl('https://example.com/base-model.jpg');
        expect(
          c.read(profileProvider).value!.baseModelUrl,
          'https://example.com/base-model.jpg',
        );
      });
    });

    test('setBodyRefUrl leaves the profile and faceRefUrl untouched', () {
      return withProfile(
        _profile(faceRefUrl: 'https://example.com/face-old.jpg'),
        (c) async {
          c
              .read(profileProvider.notifier)
              .setBodyRefUrl('https://example.com/body-new.jpg');
          final data = c.read(profileProvider).value!;
          expect(data.faceRefUrl, 'https://example.com/face-old.jpg');
          expect(data.profile.name, 'Test User');
        },
      );
    });
  });

  group('compare-and-set (signed-URL self-heal race guard)', () {
    // A signed-URL self-heal (RefreshableNetworkImage.onUrlRefreshed /
    // downloadReferencePhotoOriginal's own refresh-and-retry) can resolve
    // after a separate, newer upload has already committed its own URL for
    // the same photo — setBodyRefUrlIfCurrent/setFaceRefUrlIfCurrent must
    // apply the refreshed URL only if nothing else has moved the committed
    // URL on in the meantime.
    test(
      'setBodyRefUrlIfCurrent applies the fresh URL when the committed URL '
      'still matches what the refresh started from',
      () {
        return withProfile(_profile(bodyRefUrl: 'https://example.com/body-a.jpg'), (
          c,
        ) async {
          c
              .read(profileProvider.notifier)
              .setBodyRefUrlIfCurrent(
                'https://example.com/body-a.jpg',
                'https://example.com/body-a-refreshed.jpg',
              );
          expect(
            c.read(profileProvider).value!.bodyRefUrl,
            'https://example.com/body-a-refreshed.jpg',
          );
        });
      },
    );

    test(
      'setBodyRefUrlIfCurrent is a no-op when the committed URL has already '
      'moved on (a newer upload committed in the meantime) — the stale '
      'refresh result is discarded, not applied',
      () {
        return withProfile(_profile(bodyRefUrl: 'https://example.com/body-a.jpg'), (
          c,
        ) async {
          // A separate, newer flow already committed a different URL.
          c
              .read(profileProvider.notifier)
              .setBodyRefUrl('https://example.com/body-b-newly-uploaded.jpg');

          // A stale refresh, started against the *original* URL, resolves
          // only now.
          c
              .read(profileProvider.notifier)
              .setBodyRefUrlIfCurrent(
                'https://example.com/body-a.jpg',
                'https://example.com/body-a-STALE-refresh.jpg',
              );

          expect(
            c.read(profileProvider).value!.bodyRefUrl,
            'https://example.com/body-b-newly-uploaded.jpg',
          );
        });
      },
    );

    test(
      'setFaceRefUrlIfCurrent applies/ignores the same way, independently '
      'of bodyRefUrl',
      () {
        return withProfile(_profile(faceRefUrl: 'https://example.com/face-a.jpg'), (
          c,
        ) async {
          c
              .read(profileProvider.notifier)
              .setFaceRefUrlIfCurrent(
                'https://example.com/face-a.jpg',
                'https://example.com/face-a-refreshed.jpg',
              );
          expect(
            c.read(profileProvider).value!.faceRefUrl,
            'https://example.com/face-a-refreshed.jpg',
          );

          // Now a newer commit lands, then a second stale refresh resolves.
          c
              .read(profileProvider.notifier)
              .setFaceRefUrl('https://example.com/face-b-newly-uploaded.jpg');
          c
              .read(profileProvider.notifier)
              .setFaceRefUrlIfCurrent(
                'https://example.com/face-a-refreshed.jpg',
                'https://example.com/face-a-STALE-refresh.jpg',
              );
          expect(
            c.read(profileProvider).value!.faceRefUrl,
            'https://example.com/face-b-newly-uploaded.jpg',
          );
        });
      },
    );
  });
}
