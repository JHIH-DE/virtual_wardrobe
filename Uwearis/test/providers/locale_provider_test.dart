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
    LocaleNotifier.forgetBackendLocale();
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

  group('ensureBackendLocale', () {
    Future<List<Object?>> run(
      Future<void> Function(LocaleNotifier notifier) body, {
      List<int> statuses = const [],
    }) async {
      final bodies = <Object?>[];
      final client = MockClient((request) async {
        final status = bodies.length < statuses.length
            ? statuses[bodies.length]
            : 200;
        bodies.add(jsonDecode(request.body));
        return http.Response(
          jsonEncode({'success': true, 'data': <String, dynamic>{}}),
          status,
        );
      });
      await http.runWithClient(() async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await body(container.read(localeProvider.notifier));
      }, () => client);
      return bodies;
    }

    test('pushes a locale once the backend confirmed it', () async {
      final bodies = await run((notifier) async {
        await notifier.ensureBackendLocale('zh-TW');
        await notifier.ensureBackendLocale('zh-TW');
      });
      expect(bodies, [
        {'locale': 'zh-TW'},
      ]);
    });

    test('concurrent calls share one push', () async {
      final bodies = await run((notifier) async {
        await Future.wait([
          notifier.ensureBackendLocale('zh-TW'),
          notifier.ensureBackendLocale('zh-TW'),
        ]);
      });
      expect(bodies, hasLength(1));
    });

    test('a failed push is retried on the next call', () async {
      final bodies = await run((notifier) async {
        await notifier.ensureBackendLocale('zh-TW');
        await notifier.ensureBackendLocale('zh-TW');
        await notifier.ensureBackendLocale('zh-TW');
      }, statuses: [500]);
      expect(bodies, hasLength(2));
    });

    test('a different displayed locale pushes again', () async {
      final bodies = await run((notifier) async {
        await notifier.ensureBackendLocale('en');
        await notifier.ensureBackendLocale('zh-TW');
      });
      expect(bodies, [
        {'locale': 'en'},
        {'locale': 'zh-TW'},
      ]);
    });

    test('nothing extra after setLocale already pushed that locale', () async {
      final bodies = await run((notifier) async {
        await notifier.setLocale(const Locale('zh', 'TW'));
        await notifier.ensureBackendLocale('zh-TW');
      });
      expect(bodies, [
        {'locale': 'zh-TW'},
      ]);
    });

    test('a session end makes the next account push again', () async {
      final bodies = await run((notifier) async {
        await notifier.ensureBackendLocale('zh-TW');
        LocaleNotifier.forgetBackendLocale();
        await notifier.ensureBackendLocale('zh-TW');
      });
      expect(bodies, hasLength(2));
    });
  });
}
