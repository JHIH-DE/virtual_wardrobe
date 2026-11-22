import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/backgrounds_provider.dart';
import 'package:uwearis/core/providers/locale_provider.dart';

import '../helpers/fake_auth.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth();
    LocaleNotifier.forgetBackendLocale();
  });

  test('pushes the locale to the profile before fetching, so labels come '
      'back in it', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      calls.add('${request.method} ${request.url.path}');
      final data = request.url.path.endsWith('/backgrounds')
          ? [
              {
                'id': 0,
                'name': 'default_fitting_room',
                'label': '試衣間',
                'category': 'indoor',
              },
            ]
          : <String, dynamic>{};
      return http.Response(
        jsonEncode({'success': true, 'message': 'ok', 'data': data}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final backgrounds = await http.runWithClient(() async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container.read(backgroundsProvider('zh-TW').future);
    }, () => client);

    expect(backgrounds.single.label, '試衣間');
    expect(calls, hasLength(2));
    expect(calls.first, startsWith('PATCH '));
    expect(calls.first, endsWith('/users/me'));
    expect(calls.last, endsWith('/backgrounds'));
  });
}
