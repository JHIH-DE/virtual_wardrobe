import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/services/outfit_service.dart';

import '../helpers/fake_auth.dart';

// Matches AppConfig.fullApiUrl's default (Env.baseUrl's defaultValue) —
// tests run without --dart-define, so this is what the service actually
// builds its request URIs against.
const _base = 'http://10.0.2.2:8000/api/v1/outfit';

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

/// Builds a minimal, valid OutfitOut JSON map (see §3 of outfits-api.md),
/// overridable per test.
Map<String, dynamic> _outfitJson({
  int outfitId = 1,
  int groupId = 1,
  String groupType = 'general',
}) => {
  'outfit_id': outfitId,
  'group_id': groupId,
  'group_type': groupType,
  'status': 'completed',
  'name': null,
  'garment_ids': [1, 2],
  'result_image_url': 'https://example.com/$outfitId.jpg',
  'season': <String>[],
  'style': <String>[],
  'is_favorite': false,
};

void main() {
  setUp(setUpFakeAuth);

  group('createGroup', () {
    test('POSTs {type} and returns the new group_id', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'group_id': 12,
            'type': 'general',
            'name': null,
            'cover_outfit_id': null,
          }),
        );
      });

      final groupId = await http.runWithClient(
        () => OutfitService().createGroup(),
        () => client,
      );

      expect(groupId, 12);
      expect(captured.method, 'POST');
      expect(captured.url.toString(), _base);
      expect(jsonDecode(captured.body), {'type': 'general'});
    });

    test('throws when the response is missing group_id', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({})),
      );

      await expectLater(
        http.runWithClient(() => OutfitService().createGroup(), () => client),
        throwsA(isA<Exception>()),
      );
    });

    // A JSON encoder can emit an integer id as a float; the `num`-based parse
    // must accept it rather than a raw `as int` cast blowing up.
    test('accepts a group_id returned as a float', () async {
      final client = MockClient(
        (request) async => _jsonResponse(_envelope({'group_id': 12.0})),
      );

      final groupId = await http.runWithClient(
        () => OutfitService().createGroup(),
        () => client,
      );

      expect(groupId, 12);
    });
  });

  group('getAllOutfits', () {
    test('builds the query string from type/page/size/sort', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope({
            'items': [],
            'total': 0,
            'page': 1,
            'size': 20,
            'sort': 'created_at_desc',
          }),
        );
      });

      await http.runWithClient(
        () => OutfitService().getAllOutfits(
          type: 'general',
          page: 2,
          size: 30,
          sort: 'created_at_asc',
        ),
        () => client,
      );

      expect(captured.method, 'GET');
      expect(captured.url.queryParameters, {
        'type': 'general',
        'page': '2',
        'size': '30',
        'sort': 'created_at_asc',
      });
    });

    test('picks the cover outfit as the representative, not the lowest id', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope({
            'items': [
              {
                'group_id': 40,
                'name': 'Weekend Look',
                'cover_outfit_id': 66,
                'outfits': [
                  _outfitJson(outfitId: 65, groupId: 40),
                  _outfitJson(outfitId: 66, groupId: 40),
                ],
              },
            ],
          }),
        ),
      );

      final outfits = await http.runWithClient(
        () => OutfitService().getAllOutfits(),
        () => client,
      );

      expect(outfits, hasLength(1));
      final rep = outfits.single;
      expect(rep.id, 66, reason: 'should show the cover, not the lowest id');
      expect(rep.versionCount, 2);
      expect(rep.coverOutfitId, 66);
      expect(rep.groupName, 'Weekend Look');
    });

    test('falls back to the lowest outfit_id when cover_outfit_id is null', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope({
            'items': [
              {
                'group_id': 40,
                'name': null,
                'cover_outfit_id': null,
                'outfits': [
                  _outfitJson(outfitId: 70, groupId: 40),
                  _outfitJson(outfitId: 65, groupId: 40),
                ],
              },
            ],
          }),
        ),
      );

      final outfits = await http.runWithClient(
        () => OutfitService().getAllOutfits(),
        () => client,
      );

      expect(outfits.single.id, 65);
      expect(outfits.single.coverOutfitId, isNull);
      expect(outfits.single.groupName, isNull);
    });

    test('skips a group whose outfits list is empty', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope({
            'items': [
              {'group_id': 1, 'cover_outfit_id': null, 'outfits': []},
            ],
          }),
        ),
      );

      final outfits = await http.runWithClient(
        () => OutfitService().getAllOutfits(),
        () => client,
      );
      expect(outfits, isEmpty);
    });
  });

  group('getGroupOutfits', () {
    test('attaches the group cover_outfit_id and name to every outfit', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope({
            'group_id': 12,
            'type': 'general',
            'name': 'My Weekend Fit',
            'cover_outfit_id': 101,
            'outfits': [
              _outfitJson(outfitId: 101, groupId: 12),
              _outfitJson(outfitId: 102, groupId: 12),
            ],
          }),
        ),
      );

      final outfits = await http.runWithClient(
        () => OutfitService().getGroupOutfits(12),
        () => client,
      );

      expect(outfits, hasLength(2));
      for (final o in outfits) {
        expect(o.coverOutfitId, 101);
        expect(o.groupName, 'My Weekend Fit');
      }
    });
  });

  group('generateOutfit', () {
    test('creates a group first when groupId is omitted, then generates into it', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/generate')) {
          return _jsonResponse(_envelope(_outfitJson(outfitId: 5, groupId: 9)));
        }
        return _jsonResponse(
          _envelope({'group_id': 9, 'type': 'general', 'name': null, 'cover_outfit_id': null}),
        );
      });

      final outfit = await http.runWithClient(
        () => OutfitService().generateOutfit(garmentIds: [1, 2, 3]),
        () => client,
      );

      expect(outfit.id, 5);
      expect(requests, hasLength(2), reason: 'createGroup then generate');
      expect(requests[0].url.toString(), _base);
      expect(requests[1].url.toString(), '$_base/9/generate');
      final payload = jsonDecode(requests[1].body) as Map<String, dynamic>;
      expect(payload['garment_ids'], [1, 2, 3]);
      expect(payload['is_favorite'], false);
      expect(payload.containsKey('background_id'), isFalse);
    });

    test('reuses an existing groupId and omits background_id when null', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_outfitJson()));
      });

      await http.runWithClient(
        () => OutfitService().generateOutfit(garmentIds: [1], groupId: 7, backgroundId: 3),
        () => client,
      );

      expect(captured.url.toString(), '$_base/7/generate');
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['background_id'], 3);
    });

    // The render POST carries a .timeout(); a stalled request must surface a
    // TimeoutException instead of hanging the caller forever. (A MockClient
    // throwing TimeoutException reproduces what .timeout() does when it fires,
    // without a real wall-clock wait.)
    test('surfaces a TimeoutException from a stalled render', () async {
      await expectLater(
        http.runWithClient(
          () => OutfitService().generateOutfit(garmentIds: [1], groupId: 7),
          () => MockClient((request) async {
            throw TimeoutException('simulated slow render');
          }),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });
  });

  group('regenerateOutfit', () {
    test('POSTs to the regenerate endpoint, omitting background_id when null', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_outfitJson(outfitId: 5, groupId: 9)));
      });

      final outfit = await http.runWithClient(
        () => OutfitService().regenerateOutfit(9, 5),
        () => client,
      );

      expect(outfit.id, 5);
      expect(captured.url.toString(), '$_base/9/5/regenerate');
      expect(jsonDecode(captured.body), {});
    });
  });

  group('copyOutfit', () {
    test('POSTs source_outfit_id to the copy endpoint', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_outfitJson(outfitId: 66, groupId: 40)));
      });

      final outfit = await http.runWithClient(
        () => OutfitService().copyOutfit(groupId: 40, sourceOutfitId: 65),
        () => client,
      );

      expect(outfit.id, 66);
      expect(captured.url.toString(), '$_base/40/copy');
      expect(jsonDecode(captured.body), {'source_outfit_id': 65});
    });
  });

  group('updateOutfit', () {
    test('only sends the fields that were actually passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_outfitJson()));
      });

      await http.runWithClient(
        () => OutfitService().updateOutfit(1, 1, isFavorite: true),
        () => client,
      );

      expect(captured.method, 'PATCH');
      expect(jsonDecode(captured.body), {'is_favorite': true});
    });

    test('sends multiple fields together when multiple are passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(_outfitJson()));
      });

      await http.runWithClient(
        () => OutfitService().updateOutfit(
          1,
          1,
          name: 'New Name',
          style: ['minimal'],
          season: ['summer'],
        ),
        () => client,
      );

      expect(jsonDecode(captured.body), {
        'name': 'New Name',
        'style': ['minimal'],
        'season': ['summer'],
      });
    });
  });

  group('updateGroup', () {
    test('sends only name when coverOutfitId is omitted', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({}));
      });

      await http.runWithClient(
        () => OutfitService().updateGroup(12, name: 'Weekend Look'),
        () => client,
      );

      expect(captured.method, 'PATCH');
      expect(captured.url.toString(), '$_base/12');
      expect(jsonDecode(captured.body), {'name': 'Weekend Look'});
    });

    test('sends cover_outfit_id when set, without touching name', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({}));
      });

      await http.runWithClient(
        () => OutfitService().updateGroup(12, coverOutfitId: 101),
        () => client,
      );

      expect(jsonDecode(captured.body), {'cover_outfit_id': 101});
    });

    test('clearCoverOutfitId explicitly sends a null cover_outfit_id', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({}));
      });

      await http.runWithClient(
        () => OutfitService().updateGroup(12, clearCoverOutfitId: true),
        () => client,
      );

      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload.containsKey('cover_outfit_id'), isTrue);
      expect(payload['cover_outfit_id'], isNull);
    });

    test('sends an empty body when nothing is passed', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope({}));
      });

      await http.runWithClient(
        () => OutfitService().updateGroup(12),
        () => client,
      );

      expect(jsonDecode(captured.body), {});
    });
  });

  group('deleteOutfit / deleteGroup', () {
    test('deleteOutfit sends DELETE to the outfit path', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => OutfitService().deleteOutfit(9, 5),
        () => client,
      );

      expect(captured.method, 'DELETE');
      expect(captured.url.toString(), '$_base/9/5');
    });

    test('deleteGroup sends DELETE to the group path', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(_envelope(null));
      });

      await http.runWithClient(
        () => OutfitService().deleteGroup(9),
        () => client,
      );

      expect(captured.method, 'DELETE');
      expect(captured.url.toString(), '$_base/9');
    });
  });

  group('getOutfitsByGarments', () {
    test('POSTs garment_ids and returns the flat outfit list', () async {
      late http.Request captured;
      final client = MockClient((request) async {
        captured = request;
        return _jsonResponse(
          _envelope([
            _outfitJson(outfitId: 101, groupId: 12, groupType: 'general'),
            _outfitJson(outfitId: 214, groupId: 40, groupType: 'daily'),
          ]),
        );
      });

      final outfits = await http.runWithClient(
        () => OutfitService().getOutfitsByGarments([12, 55]),
        () => client,
      );

      expect(captured.url.toString(), '$_base/by-garments');
      expect(jsonDecode(captured.body), {
        'garment_ids': [12, 55],
      });
      expect(outfits, hasLength(2));
      expect(outfits[1].groupType, 'daily');
    });
  });

  group('error handling', () {
    test('a non-2xx response throws, surfacing the status code', () async {
      final client = MockClient(
        (request) async => _jsonResponse(
          _envelope(null),
          status: 404,
        ),
      );

      await expectLater(
        http.runWithClient(
          () => OutfitService().getOutfit(1, 999),
          () => client,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('404'),
          ),
        ),
      );
    });

    test('a 401 with no stored refresh token throws AuthExpiredException '
        'without attempting a refresh call', () async {
      // No refresh_token key at all — AuthStorage.getRefreshToken() must
      // come back null, not empty string, to hit withAuth's early-throw
      // branch rather than actually attempting POST /auth/refresh.
      FlutterSecureStorage.setMockInitialValues({
        'access_token': 'fake-access-token',
      });
      var requestCount = 0;
      final client = MockClient((request) async {
        requestCount++;
        return _jsonResponse(_envelope(null), status: 401);
      });

      await expectLater(
        http.runWithClient(
          () => OutfitService().getOutfit(1, 1),
          () => client,
        ),
        throwsA(isA<AuthExpiredException>()),
      );
      expect(
        requestCount,
        1,
        reason: 'should not attempt POST /auth/refresh with no stored token',
      );
    });
  });
}
