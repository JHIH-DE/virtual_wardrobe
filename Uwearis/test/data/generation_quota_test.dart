import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:uwearis/core/config/app_config.dart';
import 'package:uwearis/core/services/outfit_service.dart';
import 'package:uwearis/data/generation_quota.dart';

import '../helpers/fake_auth.dart';
import '../helpers/mock_http.dart';

Map<String, dynamic> quotaJson({
  int? limit = 10,
  int used = 3,
  int? remaining = 7,
}) => {
  'limit': limit,
  'used': used,
  'remaining': remaining,
  'resets_at': '2026-11-03T00:00:00+08:00',
};

void main() {
  setUp(setUpFakeAuth);

  test('a limited tier', () {
    final q = GenerationQuota.fromJson(quotaJson());
    expect((q.limit, q.used, q.remaining, q.isUnlimited), (10, 3, 7, false));
    expect(q.resetsAt, DateTime.utc(2026, 11, 2, 16).toLocal());
  });

  test('an unlimited tier', () {
    final q = GenerationQuota.fromJson(quotaJson(limit: null, remaining: null));
    expect(q.isUnlimited, isTrue);
    expect(q.remaining, isNull);
  });

  test('OutfitService reads GET /outfit/generation-quota', () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add('${request.method} ${request.url}');
      return jsonResponse(envelope(quotaJson()));
    });
    final quota = await http.runWithClient(
      () => OutfitService().getGenerationQuota(),
      () => client,
    );
    expect(quota.remaining, 7);
    expect(requests, ['GET ${AppConfig.fullApiUrl}/outfit/generation-quota']);
  });
}
