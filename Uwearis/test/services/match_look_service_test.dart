import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/match_look_service.dart';

import '../helpers/fake_auth.dart';

const _base = 'http://10.0.2.2:8000/api/v1/match_look';

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

Future<File> _writeTempJpeg() async {
  final file = File(
    '${Directory.systemTemp.path}/match_look_test_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await file.writeAsBytes([0xFF, 0xD8, 0xFF, 0xD9]);
  return file;
}

void main() {
  setUp(setUpFakeAuth);

  group('uploadReference', () {
    test('inits the upload, PUTs the file, then POSTs the object_name', () async {
      final tempFile = await _writeTempJpeg();
      addTearDown(() => tempFile.delete());

      final requestedUrls = <String>[];
      final client = MockClient((request) async {
        requestedUrls.add('${request.method} ${request.url}');
        if (request.url.path.endsWith('/reference/init-upload')) {
          return _jsonResponse(
            _envelope({
              'upload_url': 'https://upload.example.com/signed',
              'object_name': 'refs/1.jpg',
            }),
          );
        }
        if (request.url.toString() == 'https://upload.example.com/signed') {
          return http.Response('', 200);
        }
        // POST /reference (the analyze call)
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => MatchLookService().uploadReference(tempFile.path),
        () => client,
      );

      expect(requestedUrls, [
        'POST $_base/reference/init-upload',
        'PUT https://upload.example.com/signed',
        'POST $_base/reference',
      ]);
    });
  });

  group('matchLook', () {
    test('POSTs with no body and parses the MatchALookResult', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'reference_id': 5,
            'roles': [
              {'role': 'top', 'match_status': 'strong_match'},
            ],
            'garments': [],
          }),
        );
      });

      final result = await http.runWithClient(
        () => MatchLookService().matchLook(),
        () => client,
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), '$_base/match');
      expect(result.referenceId, 5);
      expect(result.roles, hasLength(1));
    });

    test('throws MatchLookException carrying the backend error_code on failure', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          {
            'success': false,
            'message': 'No person detected in the photo.',
            'data': null,
            'error_code': 'NO_PERSON_DETECTED',
          },
          status: 400,
        ),
      );

      await expectLater(
        http.runWithClient(() => MatchLookService().matchLook(), () => client),
        throwsA(
          isA<MatchLookException>()
              .having((e) => e.errorCode, 'errorCode', 'NO_PERSON_DETECTED')
              .having((e) => e.message, 'message', 'No person detected in the photo.'),
        ),
      );
    });

    test('throws MatchLookException when the response body is not valid JSON', () async {
      final client = MockClient(
        (request) async => http.Response('not json', 200),
      );

      await expectLater(
        http.runWithClient(() => MatchLookService().matchLook(), () => client),
        throwsA(isA<MatchLookException>()),
      );
    });
  });

  group('removeReference', () {
    test('DELETEs the reference path', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => MatchLookService().removeReference(),
        () => client,
      );

      expect(captured.method, 'DELETE');
      expect(captured.url.toString(), '$_base/reference');
    });

    test('treats a 404 as success rather than throwing', () async {
      final client = MockClient(
        (request) async => http.Response('', 404),
      );

      await http.runWithClient(
        () => MatchLookService().removeReference(),
        () => client,
      );
      // No exception means the 404-tolerance path was taken.
    });
  });
}
