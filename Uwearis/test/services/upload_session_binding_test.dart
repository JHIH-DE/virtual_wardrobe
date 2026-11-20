import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/services/base_service.dart';
import 'package:uwearis/core/services/garment_service.dart';
import 'package:uwearis/core/services/profile_service.dart';
import 'package:uwearis/data/garment.dart';

import '../helpers/mock_http.dart';
import '../helpers/scripted_auth_storage.dart';

// S1: a multi-step upload (init-upload → PUT to the signed URL → complete)
// belongs to the session it started in. Once that session has ended, no
// later step may be sent — above all not `complete` under the next
// account's token with this account's object.

const _signedUrl = 'https://storage.test/upload/obj';

/// One upload's backend. Records every request with its bearer account;
/// [onInit] / [onPut] / [onComplete] run when that step arrives, before it
/// is answered (to end the session mid-step, or answer otherwise).
class _UploadBackend {
  _UploadBackend({required this.completeData});

  final Map<String, dynamic> completeData;
  final sent = <String>[];
  Future<http.Response?> Function()? onInit;
  Future<http.Response?> Function()? onPut;
  Future<http.Response?> Function()? onComplete;

  static String _who(http.BaseRequest r) {
    final auth = r.headers['Authorization'];
    return auth == null ? '-' : auth.replaceFirst('Bearer access-', '');
  }

  List<String> get completes =>
      sent.where((s) => s.startsWith('complete')).toList();

  MockClient client() => MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (path.endsWith('/init-upload')) {
      sent.add('init as ${_who(req)}');
      final override = await onInit?.call();
      return override ??
          jsonResponse(
            envelope({
              'upload_url': _signedUrl,
              'object_name': 'uploads/1/x.jpg',
            }),
          );
    }
    if (req.method == 'PUT' && req.url.toString() == _signedUrl) {
      sent.add('put');
      return await onPut?.call() ?? http.Response('', 200);
    }
    if (path.endsWith('/complete')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      sent.add('complete as ${_who(req)} for ${body['object_name']}');
      return await onComplete?.call() ?? jsonResponse(envelope(completeData));
    }
    return jsonResponse(envelope({'items': <Object>[]}), status: 404);
  });
}

Future<void> _signInAs(String account) async {
  await AuthStorage.clear();
  await AuthStorage.startSession(
    accessToken: 'access-$account',
    refreshToken: 'refresh-$account',
  );
}

/// The flows under test, each from a local file to its result.
typedef _Upload = Future<Object?> Function(String localPath);

void main() {
  late File photo;

  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
    photo = File(
      '${Directory.systemTemp.path}/uwearis_s1_'
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() {
      if (photo.existsSync()) photo.deleteSync();
    });
  });

  final flows = <String, (_Upload, Map<String, dynamic>)>{
    'ProfileService.uploadAvatar': (
      (p) => ProfileService().uploadAvatar(p),
      {'object_url': 'https://cdn.test/avatar.jpg'},
    ),
    'ProfileService.uploadBodyRef': (
      (p) => ProfileService().uploadBodyRef(p),
      {'object_url': 'https://cdn.test/body.jpg'},
    ),
    'GarmentService.uploadNewGarment': (
      (p) => GarmentService().uploadNewGarment(
        p,
        describe: (init) => (
          Garment(
            uploadUrl: init.uploadUrl,
            objectName: init.objectName,
            category: GarmentCategory.top,
            subCategory: 'T-shirt',
            name: 'Tee',
          ),
          <String, dynamic>{'style': null},
        ),
      ),
      {
        'id': 9001,
        'name': 'Tee',
        'category': 'Top',
        'sub_category': 'T-shirt',
        'image_url': 'https://cdn.test/tee.jpg',
      },
    ),
  };

  for (final MapEntry(key: name, value: (upload, completeData))
      in flows.entries) {
    group(name, () {
      _UploadBackend backend() => _UploadBackend(completeData: completeData);

      Future<Object?> run(_UploadBackend b) =>
          http.runWithClient(() => upload(photo.path), b.client);

      test(
        'one session start to finish: init, PUT, complete, all as A',
        () async {
          final b = backend();
          await run(b);
          expect(b.sent, [
            'init as A',
            'put',
            'complete as A for uploads/1/x.jpg',
          ]);
        },
      );

      test('B signs in while the PUT is in flight: no complete is sent, '
          'least of all as B with A\'s object', () async {
        final b = backend()
          ..onPut = () async {
            await _signInAs('B');
            return null;
          };
        await expectLater(run(b), throwsA(isA<SessionChangedException>()));
        expect(b.completes, isEmpty);
        expect(b.sent, ['init as A', 'put']);
      });

      test('A only signs out while the PUT is in flight: no complete, and '
          'it ends as a session change, not an expiry', () async {
        final b = backend()
          ..onPut = () async {
            await AuthStorage.clear();
            return null;
          };
        await expectLater(run(b), throwsA(isA<SessionChangedException>()));
        expect(b.completes, isEmpty);
      });

      test("init's reply landing after the session ended: neither PUT nor "
          'complete', () async {
        final b = backend()
          ..onInit = () async {
            await _signInAs('B');
            return null;
          };
        await expectLater(run(b), throwsA(isA<SessionChangedException>()));
        expect(b.sent, ['init as A']);
      });

      test("complete's reply landing after the session ended is a session "
          'change (the withAuth contract)', () async {
        final b = backend()
          ..onComplete = () async {
            await _signInAs('B');
            return null;
          };
        await expectLater(run(b), throwsA(isA<SessionChangedException>()));
        expect(b.completes, ['complete as A for uploads/1/x.jpg']);
      });

      test('same-session failures keep their errors', () async {
        final initFails = backend()
          ..onInit = () async => jsonResponse(envelope(null), status: 500);
        await expectLater(run(initFails), throwsA(isA<ApiException>()));
        expect(initFails.sent, ['init as A']);

        final putFails = backend()..onPut = () async => http.Response('', 500);
        await expectLater(
          run(putFails),
          throwsA(
            isA<Exception>().having(
              (e) => '$e',
              'message',
              contains('PUT to signed url failed'),
            ),
          ),
        );
        expect(putFails.completes, isEmpty);

        final putTimesOut = backend()
          ..onPut = () async => throw TimeoutException('slow upload');
        await expectLater(run(putTimesOut), throwsA(isA<TimeoutException>()));
        expect(putTimesOut.completes, isEmpty);

        final completeFails = backend()
          ..onComplete = () async => jsonResponse(envelope(null), status: 500);
        await expectLater(run(completeFails), throwsA(isA<ApiException>()));
      });
    });
  }
}
