import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/services/base_service.dart';
import 'package:uwearis/core/services/match_look_service.dart';

import '../helpers/mock_http.dart';
import '../helpers/scripted_auth_storage.dart';

// Match a Look's reference upload (init-upload → PUT to the signed URL →
// the charged POST /reference) belongs to the session it started in. Once
// that session has ended no later step may be sent — above all not
// /reference under the next account's token with this account's object.

const _signedUrl = 'https://storage.test/upload/look.jpg';
const _objectName = 'uploads/1/look.jpg';

/// Records each step with its bearer account; [onInit] / [onPut] /
/// [onReference] run when that step arrives, before it's answered.
class _Backend {
  final sent = <String>[];
  Future<http.Response?> Function()? onInit;
  Future<http.Response?> Function()? onPut;
  Future<http.Response?> Function()? onReference;

  static String _who(http.BaseRequest r) {
    final auth = r.headers['Authorization'];
    return auth == null ? '-' : auth.replaceFirst('Bearer access-', '');
  }

  List<String> get references =>
      sent.where((s) => s.startsWith('reference')).toList();

  MockClient client() => MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (path.endsWith('/match_look/reference/init-upload')) {
      sent.add('init as ${_who(req)}');
      return await onInit?.call() ??
          jsonResponse(
            envelope({'upload_url': _signedUrl, 'object_name': _objectName}),
          );
    }
    if (req.method == 'PUT' && req.url.toString() == _signedUrl) {
      sent.add('put');
      return await onPut?.call() ?? http.Response('', 200);
    }
    if (req.method == 'POST' && path.endsWith('/match_look/reference')) {
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      sent.add('reference as ${_who(req)} for ${body['object_name']}');
      return await onReference?.call() ??
          jsonResponse(envelope(<String, dynamic>{}));
    }
    return jsonResponse(envelope(null), status: 404);
  });
}

Future<void> _signInAs(String account) async {
  await AuthStorage.clear();
  await AuthStorage.startSession(
    accessToken: 'access-$account',
    refreshToken: 'refresh-$account',
  );
}

void main() {
  late File photo;

  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
    photo = File(
      '${Directory.systemTemp.path}/uwearis_match_look_'
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    )..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() {
      if (photo.existsSync()) photo.deleteSync();
    });
  });

  Future<void> run(_Backend b) => http.runWithClient(
    () => MatchLookService().uploadReference(photo.path),
    b.client,
  );

  test('one session start to finish: init, PUT, reference, all as A', () async {
    final b = _Backend();
    await run(b);
    expect(b.sent, ['init as A', 'put', 'reference as A for $_objectName']);
  });

  test("B signs in while A's PUT is in flight: no reference is sent (or "
      "charged), least of all as B with A's object", () async {
    final b = _Backend()
      ..onPut = () async {
        await _signInAs('B');
        return null;
      };
    await expectLater(run(b), throwsA(isA<SessionChangedException>()));
    expect(b.references, isEmpty);
    expect(b.sent, ['init as A', 'put']);
  });

  test('A only signs out while the PUT is in flight: no reference, and it '
      'ends as a session change, not an expiry', () async {
    final b = _Backend()
      ..onPut = () async {
        await AuthStorage.clear();
        return null;
      };
    await expectLater(run(b), throwsA(isA<SessionChangedException>()));
    expect(b.references, isEmpty);
  });

  test("init's reply landing after the session ended: neither PUT nor "
      'reference (the withAuth contract)', () async {
    final b = _Backend()
      ..onInit = () async {
        await _signInAs('B');
        return null;
      };
    await expectLater(run(b), throwsA(isA<SessionChangedException>()));
    expect(b.sent, ['init as A']);
  });

  test("the reference's reply landing after the session ended is a session "
      'change (the withAuth contract)', () async {
    final b = _Backend()
      ..onReference = () async {
        await _signInAs('B');
        return null;
      };
    await expectLater(run(b), throwsA(isA<SessionChangedException>()));
    expect(b.references, ['reference as A for $_objectName']);
  });

  test('same-session failures keep their errors', () async {
    final initFails = _Backend()
      ..onInit = () async => jsonResponse(envelope(null), status: 500);
    await expectLater(run(initFails), throwsA(isA<MatchLookException>()));
    expect(initFails.sent, ['init as A']);

    final putFails = _Backend()..onPut = () async => http.Response('', 500);
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
    expect(putFails.references, isEmpty);

    final putTimesOut = _Backend()
      ..onPut = () async => throw TimeoutException('slow upload');
    await expectLater(run(putTimesOut), throwsA(isA<TimeoutException>()));
    expect(putTimesOut.references, isEmpty);

    final referenceFails = _Backend()
      ..onReference = () async => jsonResponse(envelope(null), status: 500);
    await expectLater(run(referenceFails), throwsA(isA<MatchLookException>()));

    final referenceTimesOut = _Backend()
      ..onReference = () async => throw TimeoutException('slow analysis');
    await expectLater(run(referenceTimesOut), throwsA(isA<TimeoutException>()));
  });
}
