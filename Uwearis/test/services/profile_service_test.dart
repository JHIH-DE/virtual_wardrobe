import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/profile_service.dart';

import '../helpers/fake_auth.dart';

const _base = 'http://10.0.2.2:8000/api/v1/users/me';

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
    test('GETs the profile root and returns data', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'name': 'Jason', 'email': 'j@example.com'}));
      });

      final profile = await http.runWithClient(
        () => ProfileService().getMyProfile(),
        () => client,
      );

      expect(captured.url.toString(), _base);
      expect(profile['name'], 'Jason');
    });
  });

  group('avatar upload flow', () {
    test('avatarInitUpload POSTs a content_type and returns upload details', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'upload_url': 'https://upload.example.com/x',
            'object_name': 'avatars/1.jpg',
          }),
        );
      });

      final result = await http.runWithClient(
        () => ProfileService().avatarInitUpload(),
        () => client,
      );

      expect(captured.url.toString(), '$_base/avatar/init-upload');
      expect(jsonDecode(captured.body), {'content_type': 'image/jpeg'});
      expect(result.uploadUrl, 'https://upload.example.com/x');
      expect(result.objectName, 'avatars/1.jpg');
    });

    test('avatarComplete POSTs the object_name and returns the final url', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({'object_url': 'https://cdn.example.com/1.jpg'}));
      });

      final url = await http.runWithClient(
        () => ProfileService().avatarComplete(objectName: 'avatars/1.jpg'),
        () => client,
      );

      expect(captured.url.toString(), '$_base/avatar/complete');
      expect(jsonDecode(captured.body), {'object_name': 'avatars/1.jpg'});
      expect(url, 'https://cdn.example.com/1.jpg');
    });

    test('avatarComplete throws when object_url is missing', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({})),
      );

      await expectLater(
        http.runWithClient(
          () => ProfileService().avatarComplete(objectName: 'x'),
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

    test('returns an empty list rather than throwing when items is missing', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({})),
      );

      final items = await http.runWithClient(
        () => ProfileService().getMyStyleProfile(),
        () => client,
      );
      expect(items, isEmpty);
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

    test('sends weeklySchedule and temperatureOffsetC under their wire keys', () async {
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
    });
  });
}
