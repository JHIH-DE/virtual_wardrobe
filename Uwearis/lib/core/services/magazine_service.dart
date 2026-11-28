import 'dart:async';

import 'package:http/http.dart' as http;

import '../../data/magazine.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

/// `/magazine`: Explore's published magazine, in the profile's language.
class MagazineService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/magazine';

  /// Tells the backend which story layouts this build renders, so it leaves
  /// out stories that would lose pages here (a newer layout).
  static const String layoutsHeader = 'X-Magazine-Layouts';

  Map<String, String> _headers(String token) => {
    ...authHeaders(token),
    layoutsHeader: MagazineSlide.supportedLayouts.join(','),
  };

  /// The latest published issue and its stories; [audience] `men` / `women`
  /// also keeps stories for everyone, null keeps all.
  Future<MagazineHome> getHome({MagazineAudience? audience}) async {
    debugLog('--- getHome: audience=${audience?.apiValue} ---');
    final uri = Uri.parse('$_baseUrl/home').replace(
      queryParameters: audience == null || audience == MagazineAudience.all
          ? null
          : {'audience': audience.apiValue},
    );
    final res = await withAuth(
      (token) => http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final data = decodeMap(res, op: 'getMagazineHome')['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getHome: invalid response');
    }
    return MagazineHome.fromJson(data);
  }

  Future<MagazineStory> getStory(int storyId) async {
    debugLog('--- getStory: id=$storyId ---');
    final res = await withAuth(
      (token) => http
          .get(
            Uri.parse('$_baseUrl/stories/$storyId'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15)),
      retryOnTimeout: true,
    );
    final data = decodeMap(res, op: 'getMagazineStory')['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('getStory: invalid response');
    }
    return MagazineStory.fromJson(data);
  }
}
