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
}
