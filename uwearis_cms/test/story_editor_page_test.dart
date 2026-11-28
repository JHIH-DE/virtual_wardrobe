import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/features/widgets/magazine/magazine_story_view.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';
import 'package:uwearis_cms/api/api_client.dart';
import 'package:uwearis_cms/api/cms_api.dart';
import 'package:uwearis_cms/models/story_draft.dart';
import 'package:uwearis_cms/pages/story_editor_page.dart';
import 'package:uwearis_cms/widgets/cms_scope.dart';
import 'package:uwearis_cms/widgets/story_slides_preview.dart';

http.Response _ok(Object? data) => http.Response.bytes(
  utf8.encode(
    jsonEncode({
      'success': true,
      'message': 'ok',
      'error_code': null,
      'data': data,
    }),
  ),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> _story({String titleZh = '春季穿搭', List<dynamic>? blocks}) =>
    {
      'id': 7,
      'issue_id': 1,
      'slug': 'spring-edit',
      'title_zh_tw': titleZh,
      'title_en': 'Spring Edit',
      'subtitle_zh_tw': null,
      'subtitle_en': null,
      'cover_object_name': null,
      'audience': 'all',
      'status': 'draft',
      'blocks':
          blocks ??
          [
            {
              'id': 'b1',
              'type': 'paragraph',
              'text': {'zh_tw': '第一段', 'en': 'First paragraph'},
            },
          ],
      'image_urls': <String, String>{},
      'items': <Object>[],
    };

Map<String, dynamic> _storyFormat({List<dynamic>? pages}) => {
  ..._story(blocks: const []),
  'id': 8,
  'slug': 'old-money',
  'format': 'story',
  'title_zh_tw': 'Old Money Sport',
  'cover_object_name': 'dev/_global/magazine/cover.jpg',
  'pages':
      pages ??
      [
        {
          'id': 'p1',
          'layout': 'typography',
          'heading': {'zh_tw': '少，但更好。', 'en': 'Less, but better.'},
          'tone': 'light',
        },
      ],
  'image_urls': {'dev/_global/magazine/cover.jpg': 'https://signed/cover.jpg'},
};

void main() {
  late List<http.Request> requests;
  late CmsApi api;

  /// Which images have confirmed rights (by object name).
  late Set<String> usable;

  setUp(() async {
    requests = [];
    usable = {};
    final client = ApiClient(
      httpClient: MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (path.endsWith('/auth/google')) {
          return _ok({'access_token': 'a', 'refresh_token': 'r'});
        }
        if (path.endsWith('/admin/magazine/issues')) {
          return _ok([
            {
              'id': 1,
              'slug': 'issue-01',
              'title_zh_tw': '第一期',
              'status': 'draft',
              'story_count': 1,
            },
          ]);
        }
        if (path.endsWith('/admin/magazine/assets') && req.method == 'GET') {
          return _ok([
            for (final name in req.url.queryParametersAll['object_names'] ?? [])
              {
                'object_name': name,
                'exists': usable.contains(name),
                'license_type': usable.contains(name) ? 'owned' : 'unknown',
                'rights_confirmed': usable.contains(name),
                'usable': usable.contains(name),
              },
          ]);
        }
        if (path.endsWith('/admin/magazine/assets') && req.method == 'PUT') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['rights_confirmed'] == true) {
            usable.add(body['object_name'] as String);
          }
          return _ok({
            ...body,
            'exists': true,
            'usable': body['rights_confirmed'],
          });
        }
        if (path.endsWith('/admin/magazine/items/3')) {
          return _ok({'id': 3, 'name_zh_tw': '羊毛外套', 'brand': 'COMOLI'});
        }
        if (path.endsWith('/admin/magazine/stories/8') && req.method == 'GET') {
          return _ok(_storyFormat());
        }
        if (path.endsWith('/admin/magazine/stories/8') && req.method == 'PUT') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          return _ok(_storyFormat(pages: body['pages'] as List<dynamic>));
        }
        if (path.endsWith('/admin/magazine/stories/7') && req.method == 'GET') {
          return _ok(_story());
        }
        if (path.endsWith('/admin/magazine/stories/7') && req.method == 'PUT') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          return _ok(
            _story(
              titleZh: body['title_zh_tw'] as String,
              blocks: body['blocks'] as List<dynamic>,
            ),
          );
        }
        return http.Response('not found', 404);
      }),
    );
    await client.signInWithGoogle('t');
    client.confirmSession(1);
    api = CmsApi(client);
  });

  Future<void> pump(
    WidgetTester tester, {
    int? storyId = 7,
    StoryDraft? imported,
  }) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CmsScope(
        api: api,
        child: MaterialApp(
          locale: const Locale('zh', 'TW'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: StoryEditorPage(
            issueId: 1,
            storyId: storyId,
            initialDraft: imported,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inPreview(Finder finder) =>
      find.descendant(of: find.byType(MagazineStoryView), matching: finder);

  testWidgets('loads the story and previews it in either language', (
    tester,
  ) async {
    await pump(tester);
    expect(inPreview(find.text('春季穿搭')), findsOneWidget);
    expect(inPreview(find.text('第一段')), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(inPreview(find.text('Spring Edit')), findsOneWidget);
    expect(inPreview(find.text('First paragraph')), findsOneWidget);
  });

  testWidgets('edits show in the preview, then save sends the whole story', (
    tester,
  ) async {
    await pump(tester);
    expect(find.widgetWithText(FilledButton, '儲存'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '儲存'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.widgetWithText(TextField, '標題（中文）'), '夏季穿搭');
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '小標題'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '小標題'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '小標題（中文）'), '從外套開始');
    await tester.pumpAndSettle();

    expect(inPreview(find.text('夏季穿搭')), findsOneWidget);
    expect(inPreview(find.text('從外套開始')), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();

    final put = requests.lastWhere((r) => r.method == 'PUT');
    final body = jsonDecode(put.body) as Map<String, dynamic>;
    expect(body['title_zh_tw'], '夏季穿搭');
    final blocks = body['blocks'] as List;
    expect(blocks.map((b) => (b as Map)['type']), ['paragraph', 'heading']);
    expect((blocks[0] as Map)['id'], 'b1');
    expect((blocks[1] as Map)['text'], {'zh_tw': '從外套開始', 'en': ''});
    expect(find.text('已儲存'), findsOneWidget);
  });

  testWidgets('an incomplete block is caught before saving', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '圖片'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '圖片'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();

    expect(find.text('還不能儲存'), findsOneWidget);
    expect(find.textContaining('還沒上傳圖片'), findsOneWidget);
    expect(requests.where((r) => r.method == 'PUT'), isEmpty);
  });

  testWidgets('a story pages through its layouts: add one, preview it, save '
      'every page', (tester) async {
    await pump(tester, storyId: 8);
    expect(find.byType(StorySlidesPreview), findsOneWidget);
    expect(find.byType(MagazineStoryView), findsNothing);
    expect(find.text('第 2 頁 · Typography'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Feature'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Feature'));
    await tester.pumpAndSettle();
    expect(find.text('第 3 頁 · Feature'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    expect(find.text('還不能儲存'), findsOneWidget);
    expect(find.textContaining('第 3 頁（Feature）主圖還沒上傳圖片'), findsOneWidget);
    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('移除這一頁').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Typography'),
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Typography'));
    await tester.pumpAndSettle();
    final quote = find.widgetWithText(TextField, '主要文字（中文）').last;
    await tester.ensureVisible(quote);
    await tester.enterText(quote, '第二章');
    await tester.pumpAndSettle();

    // Adding a page shows it in the preview.
    final preview = find.byType(StorySlidesPreview);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('第二章')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, '儲存'));
    await tester.pumpAndSettle();
    final put = requests.lastWhere((r) => r.method == 'PUT');
    final body = jsonDecode(put.body) as Map<String, dynamic>;
    expect(body['format'], 'story');
    expect(body['blocks'], isEmpty);
    expect((body['pages'] as List).map((p) => (p as Map)['layout']), [
      'typography',
      'typography',
    ]);
    expect(((body['pages'] as List)[0] as Map)['id'], 'p1');
    expect(body.containsKey('sponsorship'), isTrue);
  });

  testWidgets('switching an article with content to a story asks first', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Story（左右翻頁）'));
    await tester.pumpAndSettle();
    expect(find.text('切換內容形式？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.byType(MagazineStoryView), findsOneWidget);

    await tester.tap(find.text('Story（左右翻頁）'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '切換'));
    await tester.pumpAndSettle();
    expect(find.byType(StorySlidesPreview), findsOneWidget);
  });

  testWidgets('images without confirmed rights are flagged, and recorded '
      'from the image', (tester) async {
    await pump(tester, storyId: 8);
    expect(find.textContaining('有 1 張讀者會看到的圖片還沒確認使用權'), findsOneWidget);
    expect(find.text('使用權：未登記'), findsOneWidget);

    await tester.tap(find.text('使用權：未登記'));
    await tester.pumpAndSettle();
    expect(find.text('圖片出處與使用權'), findsOneWidget);
    final confirm = find.widgetWithText(CheckboxListTile, '我已確認取得這張圖片的使用權');
    expect(tester.widget<CheckboxListTile>(confirm).onChanged, isNull);

    await tester.tap(find.text('未知'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('自己拍攝').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '攝影／出處署名'), 'Ken');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '儲存').last);
    await tester.pumpAndSettle();

    final put = requests.lastWhere(
      (r) => r.method == 'PUT' && r.url.path.endsWith('/assets'),
    );
    final body = jsonDecode(put.body) as Map<String, dynamic>;
    expect(body['object_name'], 'dev/_global/magazine/cover.jpg');
    expect(
      (body['license_type'], body['credit'], body['rights_confirmed']),
      ('owned', 'Ken', true),
    );
    expect(find.text('使用權：已確認'), findsOneWidget);
    expect(find.textContaining('還沒確認使用權'), findsNothing);
  });

  testWidgets('an imported draft opens ready to create, with its photo '
      'briefs and items', (tester) async {
    await pump(
      tester,
      storyId: null,
      imported: StoryDraft.fromImport({
        'format': 'story',
        'slug': 'old-money-sport',
        'title_zh_tw': '老錢運動風',
        'cover_brief': '全身街拍，直式',
        'pages': [
          {
            'layout': 'selection',
            'featured_item_ids': [3],
          },
        ],
      }, issueId: 1),
    );
    expect(find.text('新增文章'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '建立'))
          .onPressed,
      isNotNull,
    );
    expect(find.text('建議圖片：全身街拍，直式'), findsOneWidget);
    expect(find.text('羊毛外套'), findsOneWidget, reason: 'item fetched');
    expect(find.textContaining('找不到'), findsNothing);
  });

  testWidgets('an AI-generated image must name its tool', (tester) async {
    await pump(tester, storyId: 8);
    await tester.tap(find.text('使用權：未登記'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('未知'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AI 生成').last);
    await tester.pumpAndSettle();
    expect(find.text('生成工具（必填，例：Midjourney v7）'), findsOneWidget);
    expect(find.textContaining('不要用來呈現真實商品'), findsOneWidget);

    await tester.tap(find.widgetWithText(CheckboxListTile, '我已確認取得這張圖片的使用權'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '儲存').last);
    await tester.pumpAndSettle();
    expect(find.text('AI 生成的圖要填生成工具'), findsOneWidget);
    expect(
      requests.where(
        (r) => r.url.path.endsWith('/assets') && r.method == 'PUT',
      ),
      isEmpty,
    );

    await tester.enterText(
      find.widgetWithText(TextField, '生成工具（必填，例：Midjourney v7）'),
      'Midjourney v7',
    );
    await tester.tap(find.widgetWithText(FilledButton, '儲存').last);
    await tester.pumpAndSettle();
    final body =
        jsonDecode(
              requests
                  .lastWhere(
                    (r) => r.url.path.endsWith('/assets') && r.method == 'PUT',
                  )
                  .body,
            )
            as Map<String, dynamic>;
    expect(
      (body['license_type'], body['credit']),
      ('ai_generated', 'Midjourney v7'),
    );
  });

  testWidgets('a new story can be filled from a pasted draft', (tester) async {
    await pump(tester, storyId: null);
    await tester.tap(find.text('匯入草稿'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      jsonEncode({
        'format': 'story',
        'slug': 'old-money-sport',
        'title_zh_tw': '老錢運動風',
        'pages': [
          {
            'layout': 'typography',
            'heading': {'zh_tw': '少，但更好。'},
          },
        ],
      }),
    );
    await tester.tap(find.widgetWithText(FilledButton, '匯入'));
    await tester.pumpAndSettle();
    expect(find.byType(StorySlidesPreview), findsOneWidget);
    expect(find.text('第 2 頁 · Typography'), findsOneWidget);
    expect(find.widgetWithText(TextField, '老錢運動風'), findsOneWidget);
  });
}
