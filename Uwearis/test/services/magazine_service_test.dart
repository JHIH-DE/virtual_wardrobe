import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/api_exception.dart';
import 'package:uwearis/core/services/magazine_service.dart';
import 'package:uwearis/data/magazine.dart';

import '../helpers/fake_auth.dart';

const _base = '${AppConfig.baseUrl}${AppConfig.apiPath}/magazine';

http.Response _jsonResponse(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> _envelope(Object? data) => {
  'success': true,
  'message': 'ok',
  'data': data,
  'error_code': null,
};

void main() {
  setUp(setUpFakeAuth);

  test('home sends the audience only when filtering', () async {
    final urls = <String>[];
    final client = MockClient((request) async {
      urls.add(request.url.toString());
      return _jsonResponse(
        _envelope({
          'issue': {'id': 1, 'slug': 'issue-14', 'issue_number': 14},
          'stories': [
            {'id': 5, 'issue_id': 1, 'slug': 's', 'audience': 'men'},
          ],
        }),
      );
    });

    final home = await http.runWithClient(() async {
      await MagazineService().getHome();
      await MagazineService().getHome(audience: MagazineAudience.all);
      return MagazineService().getHome(audience: MagazineAudience.women);
    }, () => client);

    expect(urls, ['$_base/home', '$_base/home', '$_base/home?audience=women']);
    expect(home.issue?.issueNumber, 14);
    expect(home.stories.single.audience, MagazineAudience.men);
  });

  test('a story GETs /magazine/stories/{id}', () async {
    late Uri url;
    final client = MockClient((request) async {
      url = request.url;
      return _jsonResponse(
        _envelope({
          'id': 5,
          'issue_id': 1,
          'slug': 's',
          'title': 'Layers',
          'blocks': [
            {'type': 'paragraph', 'text': 'Hello'},
          ],
        }),
      );
    });

    final story = await http.runWithClient(
      () => MagazineService().getStory(5),
      () => client,
    );
    expect(url.toString(), '$_base/stories/5');
    expect(story.summary.title, 'Layers');
    expect((story.blocks.single as MagazineParagraphBlock).text, 'Hello');
  });

  test('an unpublished story is a 404 ApiException', () async {
    final client = MockClient(
      (_) async => _jsonResponse({
        'success': false,
        'message': 'Story not found',
        'error_code': 'MAGAZINE_STORY_NOT_FOUND',
        'data': null,
      }, status: 404),
    );
    await expectLater(
      http.runWithClient(() => MagazineService().getStory(9), () => client),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'status', 404)
            .having((e) => e.errorCode, 'code', 'MAGAZINE_STORY_NOT_FOUND'),
      ),
    );
  });

  test('every request says which story layouts this build renders', () async {
    final headers = <String?>[];
    final client = MockClient((request) async {
      headers.add(request.headers[MagazineService.layoutsHeader]);
      return _jsonResponse(
        _envelope(
          request.url.path.endsWith('/home')
              ? {'issue': null, 'stories': []}
              : {'id': 4, 'issue_id': 1, 'slug': 's'},
        ),
      );
    });
    await http.runWithClient(() async {
      await MagazineService().getHome();
      await MagazineService().getStory(4);
    }, () => client);
    expect(headers, [
      for (var i = 0; i < 2; i++) MagazineSlide.supportedLayouts.join(','),
    ]);
    expect(MagazineSlide.supportedLayouts, hasLength(8));
  });
}
