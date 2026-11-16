import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/adjustment_options_provider.dart';
import 'package:uwearis/core/providers/locale_provider.dart';

import '../helpers/fake_auth.dart';

Map<String, dynamic> _def(String key, List<int> codes) => {
  'key': key,
  'label': key,
  'default_code': codes.first,
  'options': [
    for (final c in codes) {'code': c, 'label': '$key-$c'},
  ],
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth();
    LocaleNotifier.forgetBackendLocale();
  });

  test(
    'hides shirt / outer buttons "partly unbuttoned" and hem "front tuck"',
    () async {
      final client = MockClient((request) async {
        final data = request.url.path.endsWith('/adjustment-options')
            ? [
                _def('shirt_buttons', [1, 2, 3]),
                _def('outer_buttons', [1, 2, 3]),
                _def('hem', [1, 2, 3]),
                _def('zipper', [1, 3]),
              ]
            : <String, dynamic>{};
        return http.Response(
          jsonEncode({'success': true, 'message': 'ok', 'data': data}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final table = await http.runWithClient(() async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        return container.read(adjustmentOptionsProvider('en').future);
      }, () => client);

      List<int> codes(String key) =>
          table[key]!.options.map((o) => o.code).toList();
      expect(codes('shirt_buttons'), [1, 3]);
      expect(codes('outer_buttons'), [1, 3]);
      expect(codes('hem'), [1, 2]);
      expect(codes('zipper'), [1, 3]);
    },
  );
}
