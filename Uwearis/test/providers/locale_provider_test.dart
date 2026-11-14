import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/providers/locale_provider.dart';

import '../helpers/fake_auth.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setUpFakeAuth();
  });

  test(
    'backendSynced waits for the locale PATCH; state switches at once',
    () async {
      final reply = Completer<http.Response>();
      final requests = <http.Request>[];
      final client = MockClient((request) {
        requests.add(request);
        return reply.future;
      });

      await http.runWithClient(() async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(localeProvider.notifier);

        final done = notifier.setLocale(const Locale('zh', 'TW'));
        expect(container.read(localeProvider), const Locale('zh', 'TW'));

        var synced = false;
        unawaited(notifier.backendSynced.then((_) => synced = true));
        await pumpEventQueue();
        expect(requests.single.method, 'PATCH');
        expect(jsonDecode(requests.single.body), {'locale': 'zh-TW'});
        expect(synced, isFalse);

        reply.complete(
          http.Response(
            jsonEncode({'success': true, 'data': <String, dynamic>{}}),
            500,
          ),
        );
        await done;
        // A failed sync still completes, without throwing.
        expect(synced, isTrue);
      }, () => client);
    },
  );
}
