import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/auth_storage.dart';
import 'package:uwearis/core/services/base_service.dart';
import 'package:uwearis/core/services/garment_service.dart';

import '../helpers/mock_http.dart';
import '../helpers/scripted_auth_storage.dart';

// C4-a: reanalyzeGarment reads the garment, downloads its photo (no auth)
// and sends it to the charged analyze-instant. All of it belongs to the
// session it started in: the photo must never be analyzed — and charged —
// under the next account's token.

const _garmentId = 4321;
const _photoUrl = 'https://img.test/garment.jpg';
const _jpeg = [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10];

/// Records each step with its bearer account; [onGet] / [onDownload] /
/// [onAnalyze] run when that step arrives, before it's answered.
class _Backend {
  final sent = <String>[];
  Future<http.Response?> Function()? onGet;
  Future<http.Response?> Function()? onDownload;
  Future<http.Response?> Function()? onAnalyze;

  static String _who(http.BaseRequest r) {
    final auth = r.headers['Authorization'];
    return auth == null ? '-' : auth.replaceFirst('Bearer access-', '');
  }

  List<String> get analyses =>
      sent.where((s) => s.startsWith('analyze')).toList();

  MockClient client() => MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/auth/refresh')) return http.Response('{}', 401);
    if (req.url.toString() == _photoUrl) {
      sent.add('download as ${_who(req)}');
      return await onDownload?.call() ??
          http.Response.bytes(
            _jpeg,
            200,
            headers: {'content-type': 'image/jpeg'},
          );
    }
    if (req.method == 'GET' && path.endsWith('/garments/$_garmentId')) {
      sent.add('get as ${_who(req)}');
      return await onGet?.call() ??
          jsonResponse(
            envelope({
              'id': _garmentId,
              'name': 'Tee',
              'category': 'Top',
              'sub_category': 'T-shirt',
              'image_url': _photoUrl,
            }),
          );
    }
    if (path.endsWith('/garments/analyze-instant')) {
      sent.add('analyze as ${_who(req)}');
      return await onAnalyze?.call() ??
          jsonResponse(
            envelope({
              'metadata': {'name': 'Tee', 'color': 'White'},
            }),
          );
    }
    return jsonResponse(envelope({'items': <Object>[]}));
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
  setUp(() {
    installKeychain({'access_token': 'access-A', 'refresh_token': 'refresh-A'});
    installPrefs();
    simulateRestart();
    GarmentService().clearGarmentCache();
  });

  Future<Map<String, dynamic>> run(_Backend b) => http.runWithClient(
    () => GarmentService().reanalyzeGarment(_garmentId),
    b.client,
  );

  test('one session: read, download, analyze — all as A', () async {
    final b = _Backend();
    final metadata = await run(b);
    expect(metadata, {'name': 'Tee', 'color': 'White'});
    expect(b.sent, ['get as A', 'download as -', 'analyze as A']);
  });

  test("B signs in while A's photo downloads: nothing is analyzed (or "
      'charged) as B', () async {
    final b = _Backend()
      ..onDownload = () async {
        await _signInAs('B');
        return null;
      };
    Object? error;
    try {
      await run(b);
    } catch (e) {
      error = e;
    }
    expect(b.analyses, isEmpty);
    expect(b.sent, ['get as A', 'download as -']);
    expect(error, isA<SessionChangedException>());
  });

  test('A only signs out while the photo downloads: nothing is analyzed, '
      'and it ends as a session change', () async {
    final b = _Backend()
      ..onDownload = () async {
        await AuthStorage.clear();
        return null;
      };
    await expectLater(run(b), throwsA(isA<SessionChangedException>()));
    expect(b.analyses, isEmpty);
  });

  test("the garment read's reply landing after the session ended: neither "
      'download nor analysis (the withAuth contract)', () async {
    final b = _Backend()
      ..onGet = () async {
        await _signInAs('B');
        return null;
      };
    await expectLater(run(b), throwsA(isA<SessionChangedException>()));
    expect(b.sent, ['get as A']);
  });

  test("the analysis' reply landing after the session ended is a session "
      'change (the withAuth contract)', () async {
    final b = _Backend()
      ..onAnalyze = () async {
        await _signInAs('B');
        return null;
      };
    await expectLater(run(b), throwsA(isA<SessionChangedException>()));
    expect(b.analyses, ['analyze as A']);
  });

  test('same-session failures keep their errors', () async {
    final downloadFails = _Backend()
      ..onDownload = () async => http.Response('', 404);
    await expectLater(
      run(downloadFails),
      throwsA(
        isA<Exception>().having(
          (e) => '$e',
          'message',
          contains('image download failed (404)'),
        ),
      ),
    );
    expect(downloadFails.analyses, isEmpty);

    GarmentService().clearGarmentCache();
    final downloadTimesOut = _Backend()
      ..onDownload = () async => throw TimeoutException('slow photo');
    await expectLater(run(downloadTimesOut), throwsA(isA<TimeoutException>()));
    expect(downloadTimesOut.analyses, isEmpty);

    GarmentService().clearGarmentCache();
    final analysisFails = _Backend()
      ..onAnalyze = () async => jsonResponse(envelope(null), status: 500);
    await expectLater(run(analysisFails), throwsA(isA<ApiException>()));

    GarmentService().clearGarmentCache();
    final analysisTimesOut = _Backend()
      ..onAnalyze = () async => throw TimeoutException('slow analysis');
    await expectLater(run(analysisTimesOut), throwsA(isA<TimeoutException>()));

    GarmentService().clearGarmentCache();
    final readFails = _Backend()
      ..onGet = () async => jsonResponse(envelope(null), status: 500);
    await expectLater(run(readFails), throwsA(isA<ApiException>()));
    expect(readFails.sent, ['get as A']);
  });
}
