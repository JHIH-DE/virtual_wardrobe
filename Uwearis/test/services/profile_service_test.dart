import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/profile_service.dart';

import '../helpers/fake_auth.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/users/me';

http.Response _jsonResponse(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> _envelope(Object? data) => {
  'success': true,
  'message': 'ok',
  'data': data,
  'error_code': null,
};

void main() {
  setUp(setUpFakeAuth);

  group('getMyProfile', () {
    test('GETs the profile root and parses a typed UserProfile', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'name': 'Jason',
            'email': 'j@example.com',
            'gender': 'male',
            'location': 'Taipei',
            'avatar_object_url': 'https://img/a.png',
            'birthday': '1996-03-11',
            'height': 178,
            'weight': 70.5,
            'unit_system': 'metric',
          }),
        );
      });

      final profile = await http.runWithClient(
        () => ProfileService().getMyProfile(),
        () => client,
      );

      expect(captured.url.toString(), _base);
      expect(profile.name, 'Jason');
      expect(profile.email, 'j@example.com');
      expect(profile.gender, 'male');
      expect(profile.location, 'Taipei');
      expect(profile.avatarObjectUrl, 'https://img/a.png');
      expect(profile.birthDate, DateTime(1996, 3, 11));
      expect(profile.height, 178);
      expect(profile.weight, 70.5);
      expect(profile.unitSystem, 'metric');
    });

    test('tolerates a missing/blank birthday and absent fields', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({'name': 'Jason'})),
      );

      final profile = await http.runWithClient(
        () => ProfileService().getMyProfile(),
        () => client,
      );

      expect(profile.birthDate, isNull);
      expect(profile.height, isNull);
      expect(profile.gender, isNull);
    });
  });

  group('avatar upload flow', () {
    test(
      'uploadAvatar runs init-upload -> PUT -> complete and returns the final url',
      () async {
        final tempFile = await _writeTempJpeg();
        addTearDown(() => tempFile.delete());

        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          if (request.url.toString() == '$_base/avatar/init-upload') {
            return _jsonResponse(
              _envelope({
                'upload_url': 'https://upload.example.com/x',
                'object_name': 'avatars/1.jpg',
              }),
            );
          }
          if (request.url.toString() == 'https://upload.example.com/x') {
            return http.Response('', 200);
          }
          return _jsonResponse(
            _envelope({'object_url': 'https://cdn.example.com/1.jpg'}),
          );
        });

        final url = await http.runWithClient(
          () => ProfileService().uploadAvatar(tempFile.path),
          () => client,
        );

        expect(url, 'https://cdn.example.com/1.jpg');
        expect(requests[0].url.toString(), '$_base/avatar/init-upload');
        expect(jsonDecode(requests[0].body), {'content_type': 'image/jpeg'});
        expect(requests[1].method, 'PUT');
        expect(requests[1].url.toString(), 'https://upload.example.com/x');
        expect(requests[2].url.toString(), '$_base/avatar/complete');
        expect(jsonDecode(requests[2].body), {'object_name': 'avatars/1.jpg'});
      },
    );

    test('uploadAvatar throws when complete is missing object_url', () async {
      final tempFile = await _writeTempJpeg();
      addTearDown(() => tempFile.delete());

      final client = MockClient((request) async {
        if (request.url.toString() == '$_base/avatar/init-upload') {
          return _jsonResponse(
            _envelope({
              'upload_url': 'https://upload.example.com/x',
              'object_name': 'avatars/1.jpg',
            }),
          );
        }
        if (request.url.toString() == 'https://upload.example.com/x') {
          return http.Response('', 200);
        }
        return _jsonResponse(_envelope({}));
      });

      await expectLater(
        http.runWithClient(
          () => ProfileService().uploadAvatar(tempFile.path),
          () => client,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('getMyAvatar returns null on a 404 instead of throwing', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope(null), status: 404),
      );

      final url = await http.runWithClient(
        () => ProfileService().getMyAvatar(),
        () => client,
      );
      expect(url, isNull);
    });

    // avatar / body-ref / face-ref completes share one helper — body-ref and
    // face-ref must reject a missing object_url just like avatar does.
    test('uploadBodyRef and uploadFaceRef throw when complete is missing '
        'object_url', () async {
      final tempFile = await _writeTempJpeg();
      addTearDown(() => tempFile.delete());

      Future<void> expectThrowsFor(
        Future<String> Function(String) upload,
        String segment,
      ) {
        final client = MockClient((request) async {
          if (request.url.toString() == '$_base/$segment/init-upload') {
            return _jsonResponse(
              _envelope({
                'upload_url': 'https://upload.example.com/x',
                'object_name': 'x',
              }),
            );
          }
          if (request.url.toString() == 'https://upload.example.com/x') {
            return http.Response('', 200);
          }
          return _jsonResponse(_envelope({}));
        });
        return expectLater(
          http.runWithClient(() => upload(tempFile.path), () => client),
          throwsA(isA<Exception>()),
        );
      }

      await expectThrowsFor(
        (p) => ProfileService().uploadBodyRef(p),
        'body-reference',
      );
      await expectThrowsFor(
        (p) => ProfileService().uploadFaceRef(p),
        'face-reference',
      );
    });

    test('a stalled complete step surfaces a TimeoutException', () async {
      final tempFile = await _writeTempJpeg();
      addTearDown(() => tempFile.delete());

      await expectLater(
        http.runWithClient(
          () => ProfileService().uploadAvatar(tempFile.path),
          () => MockClient((request) async {
            if (request.url.toString() == '$_base/avatar/init-upload') {
              return _jsonResponse(
                _envelope({
                  'upload_url': 'https://upload.example.com/x',
                  'object_name': 'avatars/1.jpg',
                }),
              );
            }
            if (request.url.toString() == 'https://upload.example.com/x') {
              return http.Response('', 200);
            }
            throw TimeoutException('simulated slow complete');
          }),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('getMyProfileData', () {
    test('one GET to the profile root parses profile fields + both '
        'reference URLs together', () async {
      final urls = <String>[];
      final client = MockClient((request) async {
        urls.add(request.url.toString());
        return _jsonResponse(
          _envelope({
            'name': 'Jason',
            'height': 178,
            'weight': 70.5,
            'body_reference_object_url': 'https://cdn.example.com/body.jpg',
            'face_reference_object_url': 'https://cdn.example.com/face.jpg',
          }),
        );
      });

      final data = await http.runWithClient(
        () => ProfileService().getMyProfileData(),
        () => client,
      );

      expect(urls, [_base]);
      expect(data.profile.name, 'Jason');
      expect(data.profile.height, 178);
      expect(data.bodyRefUrl, 'https://cdn.example.com/body.jpg');
      expect(data.faceRefUrl, 'https://cdn.example.com/face.jpg');
    });

    test('tolerates missing reference urls (both null)', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({'name': 'Jason'})),
      );

      final data = await http.runWithClient(
        () => ProfileService().getMyProfileData(),
        () => client,
      );

      expect(data.bodyRefUrl, isNull);
      expect(data.faceRefUrl, isNull);
    });
  });

  group('body/face reference reads', () {
    test('getBodyRef and getFaceReference both read from the profile root, '
        'not their own dedicated URLs', () async {
      final urls = <String>[];
      final client = MockClient((request) async {
        urls.add(request.url.toString());
        return _jsonResponse(
          _envelope({
            'body_reference_object_url': 'https://cdn.example.com/body.jpg',
            'face_reference_object_url': 'https://cdn.example.com/face.jpg',
          }),
        );
      });

      final bodyUrl = await http.runWithClient(
        () => ProfileService().getBodyRef(),
        () => client,
      );
      final faceUrl = await http.runWithClient(
        () => ProfileService().getFaceReference(),
        () => client,
      );

      expect(bodyUrl, 'https://cdn.example.com/body.jpg');
      expect(faceUrl, 'https://cdn.example.com/face.jpg');
      expect(urls, [_base, _base]);
    });

    test('getBodyRef returns null on a 404', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope(null), status: 404),
      );
      final url = await http.runWithClient(
        () => ProfileService().getBodyRef(),
        () => client,
      );
      expect(url, isNull);
    });
  });

  group('getMyStyleProfile', () {
    test('parses the items list into StyleProfileItems', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope({
            'items': [
              {'style': 'minimal', 'count': 5},
              {'style': 'streetwear', 'count': 2},
            ],
          }),
        ),
      );

      final items = await http.runWithClient(
        () => ProfileService().getMyStyleProfile(),
        () => client,
      );

      expect(items, hasLength(2));
      expect(items[0].count, 5);
    });

    test(
      'returns an empty list rather than throwing when items is missing',
      () async {
        final client = MockClient(
          (request) async => _jsonResponse(_envelope({})),
        );

        final items = await http.runWithClient(
          () => ProfileService().getMyStyleProfile(),
          () => client,
        );
        expect(items, isEmpty);
      },
    );
  });

  group('getMyStyleTaste', () {
    test('GETs style_taste and parses a typed StyleTasteProfile', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'status': 'ready',
            'summary': 'Balanced, colour-confident.',
            'style_balance': {'score': 0.7, 'confidence': 0.9, 'insight': 'x'},
            'color_pairing': {'score': 0.4, 'confidence': 0.6},
          }),
        );
      });

      final profile = await http.runWithClient(
        () => ProfileService().getMyStyleTaste(),
        () => client,
      );

      expect(captured.url.toString(), '$_base/style_taste');
      expect(profile.status, 'ready');
      expect(profile.summary, 'Balanced, colour-confident.');
      expect(profile.preferences, hasLength(2));
      expect(profile.preferences.first.score, 0.7);
    });

    test('defaults status to "learning" on an empty response', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({})),
      );

      final profile = await http.runWithClient(
        () => ProfileService().getMyStyleTaste(),
        () => client,
      );
      expect(profile.status, 'learning');
      expect(profile.preferences, isEmpty);
    });
  });

  group('updateMyProfile', () {
    test('only sends the fields that were actually passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({}));
      });

      await http.runWithClient(
        () => ProfileService().updateMyProfile(name: 'Jason', locale: 'zh-TW'),
        () => client,
      );

      expect(captured.method, 'PATCH');
      expect(captured.url.toString(), _base);
      expect(jsonDecode(captured.body), {'name': 'Jason', 'locale': 'zh-TW'});
    });

    test('sends an empty body when nothing is passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({}));
      });

      await http.runWithClient(
        () => ProfileService().updateMyProfile(),
        () => client,
      );

      expect(jsonDecode(captured.body), {});
    });

    test(
      'sends weeklySchedule and temperatureOffsetC under their wire keys',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return _jsonResponse(_envelope({}));
        });

        await http.runWithClient(
          () => ProfileService().updateMyProfile(
            weeklySchedule: {'mon': 'work', 'sun': 'casual'},
            temperatureOffsetC: -2,
          ),
          () => client,
        );

        expect(jsonDecode(captured.body), {
          'weekly_schedule': {'mon': 'work', 'sun': 'casual'},
          'temperature_offset_c': -2,
        });
      },
    );
  });
}

Future<File> _writeTempJpeg() async {
  final file = File(
    '${Directory.systemTemp.path}/profile_service_test_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  return file;
}
