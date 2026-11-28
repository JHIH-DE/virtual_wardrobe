import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/l10n/generated/app_localizations.dart';
import 'package:uwearis_cms/api/api_client.dart';
import 'package:uwearis_cms/api/cms_api.dart';
import 'package:uwearis_cms/models/admin_user.dart';
import 'package:uwearis_cms/pages/user_detail_page.dart';
import 'package:uwearis_cms/pages/users_page.dart';
import 'package:uwearis_cms/widgets/cms_scope.dart';

http.Response _json(int status, Object? body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

http.Response _ok(Object? data) => _json(200, {
  'success': true,
  'message': 'ok',
  'error_code': null,
  'data': data,
});

http.Response _fail(int status, String code, String message) => _json(status, {
  'success': false,
  'message': message,
  'error_code': code,
  'data': null,
});

Map<String, dynamic> _user({
  int id = 42,
  int balance = 315,
  bool isAdmin = false,
  String? name = 'Ken',
  double? offset = 0,
  String? location = 'Taipei',
}) => {
  'id': id,
  'email': 'ken@example.com',
  'name': name,
  'gender': 'Male',
  'birthday': '1990-05-01',
  'height': 175.0,
  'weight': 68.5,
  'unit_system': 'metric',
  'location': location,
  'location_latitude': location == null ? null : 25.03,
  'location_longitude': location == null ? null : 121.56,
  'temperature_offset_c': offset,
  'locale': 'zh-TW',
  'points_balance': balance,
  'subscription_expires_at': null,
  'is_admin': isAdmin,
  'auth_provider': 'google',
  'created_at': '2026-11-20T10:31:02+08:00',
  'updated_at': '2026-11-27T09:00:00+08:00',
  'welcome_starts_on': '2026-11-20',
  'points': {
    'balance': balance,
    'cap': 30000,
    'daily_grant': 75,
    'claimed_today': false,
    'subscription': {'active': false, 'expires_at': null},
  },
};

void main() {
  group('Taipei time', () {
    test('an offset time is shown as Taipei wall-clock time', () {
      final t = parseTaipei('2026-12-27T00:00:00+08:00')!;
      expect(formatTaipei(t), '2026-12-27 00:00');
      expect(
        formatTaipei(parseTaipei('2026-12-26T16:00:00Z')!),
        '2026-12-27 00:00',
      );
    });

    test('a time without an offset is already Taipei time', () {
      expect(
        formatTaipei(parseTaipei('2026-11-20T10:31:02')!),
        '2026-11-20 10:31',
      );
    });

    test('times sent to the backend carry +08:00', () {
      expect(
        toTaipeiIso(DateTime(2026, 12, 31, 23, 59, 59)),
        '2026-12-31T23:59:59+08:00',
      );
    });
  });

  test('a user detail reads its points and subscription', () {
    final user = AdminUser.fromJson(_user());
    expect(user.pointsBalance, 315);
    expect(user.dailyGrant, 75);
    expect(user.claimedToday, isFalse);
    expect(user.subscriptionActive, isFalse);
    expect(user.createdAt, DateTime(2026, 11, 20, 10, 31, 2));
  });

  test('ADMIN_REQUIRED ends the session and says why', () async {
    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/google')) {
          return _ok({'access_token': 'a', 'refresh_token': 'r'});
        }
        if (req.url.path.endsWith('/auth/logout')) return _ok(null);
        return _fail(403, 'ADMIN_REQUIRED', '需要管理員權限');
      }),
    );
    await client.signInWithGoogle('t');
    client.confirmSession(1);
    await expectLater(client.get('/admin/users'), throwsA(isA<ApiError>()));
    expect(client.isSignedIn, isFalse);
    expect(client.takeSignOutReason(), '需要管理員權限');
    expect(client.takeSignOutReason(), isNull);
  });

  testWidgets('the user list sorts by a column header', (tester) async {
    Map<String, dynamic> row(int id, String email, int points) => {
      'id': id,
      'email': email,
      'name': null,
      'auth_provider': 'google',
      'is_admin': false,
      'points_balance': points,
      'subscription_active': false,
      'subscription_expires_at': null,
      'created_at': '2026-11-2${id}T10:00:00',
    };
    final client = ApiClient(
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/google')) {
          return _ok({'access_token': 'a', 'refresh_token': 'r'});
        }
        return _ok({
          'items': [
            row(3, 'c@x.com', 10),
            row(2, 'a@x.com', 500),
            row(1, 'b@x.com', 75),
          ],
          'total': 3,
          'page': 1,
          'size': 20,
        });
      }),
    );
    await client.signInWithGoogle('t');
    client.confirmSession(1);
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      CmsScope(
        api: CmsApi(client),
        child: const MaterialApp(home: UsersPage()),
      ),
    );
    await tester.pumpAndSettle();

    List<String> emails() => ([
      for (final e in ['a@x.com', 'b@x.com', 'c@x.com'])
        (e, tester.getTopLeft(find.text(e)).dy),
    ]..sort((a, b) => a.$2.compareTo(b.$2))).map((e) => e.$1).toList();

    expect(emails(), ['b@x.com', 'a@x.com', 'c@x.com']);
    await tester.tap(find.text('點數'));
    await tester.pumpAndSettle();
    expect(emails(), ['c@x.com', 'b@x.com', 'a@x.com']);
    await tester.tap(find.text('點數'));
    await tester.pumpAndSettle();
    expect(emails(), ['a@x.com', 'b@x.com', 'c@x.com']);
    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    expect(emails(), ['a@x.com', 'b@x.com', 'c@x.com']);
  });

  group('user detail page', () {
    late List<http.Request> requests;
    late Future<http.Response> Function(http.Request) adjustHandler;
    late CmsApi api;
    late Map<String, dynamic> current;

    setUp(() async {
      requests = [];
      current = _user();
      adjustHandler = (req) async {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        current = _user(balance: 315 + (body['delta'] as int));
        return _ok(current);
      };
      final client = ApiClient(
        httpClient: MockClient((req) async {
          final path = req.url.path;
          if (path.endsWith('/auth/google')) {
            return _ok({'access_token': 'a', 'refresh_token': 'r'});
          }
          requests.add(req);
          if (path.endsWith('/admin/users/42') && req.method == 'GET') {
            return _ok(current);
          }
          if (path.endsWith('/admin/users/42') && req.method == 'PATCH') {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            current = {...current, ...body};
            return _ok(current);
          }
          if (path.endsWith('/points/transactions')) {
            return _ok({'items': [], 'total': 0, 'page': 1, 'size': 20});
          }
          if (path.endsWith('/points/adjust')) return adjustHandler(req);
          if (path.endsWith('/admin/users/42/delete')) {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            return body['confirm_user_id'] == 42
                ? _ok(null)
                : _fail(400, 'ADMIN_DELETE_CONFIRMATION_MISMATCH', 'email 不符');
          }
          return http.Response('not found', 404);
        }),
      );
      await client.signInWithGoogle('t');
      client.confirmSession(1);
      api = CmsApi(client);
    });

    Future<void> pump(WidgetTester tester, {bool fromList = false}) async {
      tester.view.physicalSize = const Size(1600, 2400);
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
            home: fromList
                ? Builder(
                    builder: (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const UserDetailPage(userId: 42),
                          ),
                        ),
                        child: const Text('列表'),
                      ),
                    ),
                  )
                : const UserDetailPage(userId: 42),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (fromList) {
        await tester.tap(find.text('列表'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('deleting asks for DELETE, then returns to the list', (
      tester,
    ) async {
      await pump(tester, fromList: true);
      await tester.ensureVisible(find.widgetWithText(OutlinedButton, '刪除使用者'));
      await tester.tap(find.widgetWithText(OutlinedButton, '刪除使用者'));
      await tester.pumpAndSettle();

      FilledButton deleteButton() =>
          tester.widget<FilledButton>(find.widgetWithText(FilledButton, '刪除'));
      expect(deleteButton().onPressed, isNull);
      expect(find.text('ID：42'), findsOneWidget);
      expect(find.text('登入方式：Google'), findsOneWidget);
      final field = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'delete');
      await tester.pump();
      expect(deleteButton().onPressed, isNull);
      await tester.enterText(field, 'DELETE');
      await tester.pump();
      expect(deleteButton().onPressed, isNotNull);
      await tester.tap(find.widgetWithText(FilledButton, '刪除'));
      await tester.pumpAndSettle();

      final delete = requests.singleWhere(
        (r) => r.url.path.endsWith('/admin/users/42/delete'),
      );
      expect(delete.method, 'POST');
      expect(jsonDecode(delete.body), {'confirm_user_id': 42});
      expect(find.byType(UserDetailPage), findsNothing);
      expect(find.text('已刪除 ken@example.com'), findsOneWidget);
    });

    testWidgets('your own account cannot be deleted here', (tester) async {
      api.client.confirmSession(42);
      await pump(tester);
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, '刪除使用者'),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining('請從 App 刪除'), findsOneWidget);
    });

    testWidgets('saving the profile sends only the changed fields', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.widgetWithText(TextField, '名稱'), 'Kenny');
      await tester.pump();
      await tester.tap(find.text('儲存基本資料'));
      await tester.pumpAndSettle();

      final patch = requests.singleWhere((r) => r.method == 'PATCH');
      expect(jsonDecode(patch.body), {'name': 'Kenny'});
      expect(find.text('Kenny'), findsWidgets);
    });

    testWidgets('changing the location warns that coordinates are cleared', (
      tester,
    ) async {
      await pump(tester);
      expect(find.textContaining('座標：25.03'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, '所在地'), 'Tainan');
      await tester.pump();
      expect(find.textContaining('座標會被清空'), findsOneWidget);
    });

    Future<void> openAdjust(
      WidgetTester tester, {
      required String amount,
      required String note,
    }) async {
      await tester.tap(find.text('扣點'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, '扣幾點'), amount);
      await tester.enterText(
        find.widgetWithText(TextField, '原因（會顯示在使用者的點數紀錄）'),
        note,
      );
    }

    Future<void> send(WidgetTester tester) async {
      await tester.tap(find.widgetWithText(FilledButton, '扣點'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('確定扣點'));
      await tester.pumpAndSettle();
    }

    testWidgets('removing points asks first, then sends a negative delta', (
      tester,
    ) async {
      await pump(tester);
      await openAdjust(tester, amount: '50', note: '重複儲值退回');
      await tester.tap(find.widgetWithText(FilledButton, '扣點'));
      await tester.pumpAndSettle();
      expect(find.text('確定替 ken@example.com 扣 50 點？'), findsOneWidget);
      await tester.tap(find.text('確定扣點'));
      await tester.pumpAndSettle();

      final adjust = requests.singleWhere(
        (r) => r.url.path.endsWith('/points/adjust'),
      );
      expect(jsonDecode(adjust.body), {'delta': -50, 'note': '重複儲值退回'});
      expect(adjust.headers['Idempotency-Key'], hasLength(32));
      expect(find.text('265'), findsOneWidget);
    });

    testWidgets('a resend after a timeout reuses the key; a backend answer '
        'does not', (tester) async {
      var calls = 0;
      adjustHandler = (req) async {
        calls++;
        if (calls == 1) throw TimeoutException('slow');
        return _fail(400, 'POINTS_ADJUST_BELOW_ZERO', '餘額只有 315 點');
      };
      await pump(tester);
      await openAdjust(tester, amount: '500', note: '測試');
      await send(tester);
      expect(find.textContaining('不會重複調整'), findsOneWidget);
      await send(tester);
      expect(find.text('餘額只有 315 點'), findsOneWidget);
      await send(tester);

      final keys = [
        for (final r in requests)
          if (r.url.path.endsWith('/points/adjust'))
            r.headers['Idempotency-Key'],
      ];
      expect(keys, hasLength(3));
      expect(keys[1], keys[0]);
      expect(keys[2], isNot(keys[1]));
    });

    testWidgets('your own admin switch is locked', (tester) async {
      current = _user(id: 42, isAdmin: true);
      final client = api.client;
      client.confirmSession(42);
      await pump(tester);
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isTrue);
      expect(tile.onChanged, isNull);
      expect(find.textContaining('不能移除自己的權限'), findsOneWidget);
    });
  });
}
