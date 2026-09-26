import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/utils/reference_photo_download.dart';

class _AuthExpired implements Exception {}

void main() {
  const originalUrl = 'https://storage.googleapis.com/x/original.jpg';
  const freshUrl = 'https://storage.googleapis.com/x/original.jpg?fresh=1';

  test(
    'the direct URL downloads fine — no refresh call is made, and the '
    'bytes land in a fresh local file',
    () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), originalUrl);
        return http.Response.bytes([1, 2, 3], 200);
      });

      String? refreshedTo;
      final path = await http.runWithClient(
        () => downloadReferencePhotoOriginal(
          url: originalUrl,
          fileNamePrefix: 'test_direct',
          onRefreshUrl: () async {
            fail('onRefreshUrl should not be called when the direct '
                'download already succeeds');
          },
          onUrlRefreshed: (fresh) => refreshedTo = fresh,
        ),
        () => client,
      );

      expect(path, isNotNull);
      expect(File(path!).readAsBytesSync(), [1, 2, 3]);
      expect(refreshedTo, isNull);
      File(path).deleteSync();
    },
  );

  test(
    'an expired signed URL (403) falls back to onRefreshUrl, reports the '
    'fresh URL via onUrlRefreshed, and retries the download with it',
    () async {
      final client = MockClient((request) async {
        if (request.url.toString() == originalUrl) {
          return http.Response('expired', 403);
        }
        expect(request.url.toString(), freshUrl);
        return http.Response.bytes([9, 9, 9], 200);
      });

      String? refreshedTo;
      final path = await http.runWithClient(
        () => downloadReferencePhotoOriginal(
          url: originalUrl,
          fileNamePrefix: 'test_refresh',
          onRefreshUrl: () async => freshUrl,
          onUrlRefreshed: (fresh) => refreshedTo = fresh,
        ),
        () => client,
      );

      expect(path, isNotNull);
      expect(File(path!).readAsBytesSync(), [9, 9, 9]);
      expect(refreshedTo, freshUrl);
      File(path).deleteSync();
    },
  );

  test(
    'the direct download failing and onRefreshUrl handing back null gives '
    'up — returns null, never calls onUrlRefreshed',
    () async {
      final client = MockClient((_) async => http.Response('gone', 404));

      var refreshedCalled = false;
      final path = await http.runWithClient(
        () => downloadReferencePhotoOriginal(
          url: originalUrl,
          fileNamePrefix: 'test_giveup',
          onRefreshUrl: () async => null,
          onUrlRefreshed: (_) => refreshedCalled = true,
        ),
        () => client,
      );

      expect(path, isNull);
      expect(refreshedCalled, isFalse);
    },
  );

  test(
    'the direct download failing and the refreshed URL also failing to '
    'download gives up — returns null, but onUrlRefreshed still ran (the '
    'backend really did hand back this URL as current)',
    () async {
      final client = MockClient((request) async {
        if (request.url.toString() == originalUrl) {
          return http.Response('expired', 403);
        }
        return http.Response('still broken', 500);
      });

      String? refreshedTo;
      final path = await http.runWithClient(
        () => downloadReferencePhotoOriginal(
          url: originalUrl,
          fileNamePrefix: 'test_refresh_download_fails',
          onRefreshUrl: () async => freshUrl,
          onUrlRefreshed: (fresh) => refreshedTo = fresh,
        ),
        () => client,
      );

      expect(path, isNull);
      expect(refreshedTo, freshUrl);
    },
  );

  test(
    'a network exception during the direct download is treated the same '
    'as a bad status code — falls back to onRefreshUrl',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        if (calls == 1) throw const SocketException('no route to host');
        return http.Response.bytes([7], 200);
      });

      final path = await http.runWithClient(
        () => downloadReferencePhotoOriginal(
          url: originalUrl,
          fileNamePrefix: 'test_exception',
          onRefreshUrl: () async => freshUrl,
          onUrlRefreshed: (_) {},
        ),
        () => client,
      );

      expect(path, isNotNull);
      File(path!).deleteSync();
    },
  );

  test(
    'onRefreshUrl throwing (e.g. AuthExpiredException) propagates instead '
    'of being swallowed, so the caller keeps its own auth handling in one '
    'place',
    () async {
      final client = MockClient((_) async => http.Response('expired', 403));

      await http.runWithClient(() async {
        await expectLater(
          downloadReferencePhotoOriginal(
            url: originalUrl,
            fileNamePrefix: 'test_auth',
            onRefreshUrl: () async => throw _AuthExpired(),
            onUrlRefreshed: (_) {},
          ),
          throwsA(isA<_AuthExpired>()),
        );
      }, () => client);
    },
  );

  test(
    'a refreshed URL identical to the one that just failed is treated as '
    'no real refresh — gives up rather than retrying the same broken URL',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('still broken', 403);
      });

      final path = await http.runWithClient(
        () => downloadReferencePhotoOriginal(
          url: originalUrl,
          fileNamePrefix: 'test_same_url',
          onRefreshUrl: () async => originalUrl,
          onUrlRefreshed: (_) {
            fail('a same-as-before URL is not a real refresh');
          },
        ),
        () => client,
      );

      expect(path, isNull);
      expect(calls, 1);
    },
  );
}
