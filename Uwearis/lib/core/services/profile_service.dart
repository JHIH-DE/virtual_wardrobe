import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/style_profile.dart';
import '../../data/style_taste.dart';
import '../../data/user_profile.dart';
import '../config/app_config.dart';
import '../utils/debug_log.dart';
import 'base_service.dart';

class ProfileService with BaseService {
  static final String _baseUrl = '${AppConfig.fullApiUrl}/users/me';
  static final String _avatarUrl = '$_baseUrl/avatar';
  static final String _bodyRefUrl = '$_baseUrl/body-reference';
  static final String _faceRefUrl = '$_baseUrl/face-reference';
  static final String _styleTasteUrl = '$_baseUrl/style_taste';
  static final String _styleProfileUrl = '$_baseUrl/style_profile';

  static const _quick = Duration(seconds: 15);
  // `complete` can kick off server-side base-model / face generation.
  static const _completeTimeout = Duration(seconds: 60);

  /// `data` out of a decoded envelope, falling back to the whole envelope for
  /// a bare (un-enveloped) response — the shape every method here expects.
  Map<String, dynamic> _data(Map<String, dynamic> envelope) =>
      (envelope['data'] as Map<String, dynamic>?) ?? envelope;

  Future<UserProfile> getMyProfile() async {
    debugLog('--- getMyProfile ---');
    final res = await withAuth(
      (token) => http
          .get(Uri.parse(_baseUrl), headers: authHeaders(token))
          .timeout(_quick),
    );
    return UserProfile.fromJson(_data(decodeMap(res, op: 'getMyProfile')));
  }

  // ---- signed-URL upload flow, shared by avatar / body-ref / face-ref ----

  Future<InitUploadResult> _refInitUpload(
    String baseUrl, {
    required String op,
  }) async {
    debugLog('--- $op ---');
    final res = await withAuth(
      (token) => http
          .post(
            Uri.parse('$baseUrl/init-upload'),
            headers: authHeaders(token),
            body: jsonEncode({'content_type': 'image/jpeg'}),
          )
          .timeout(_quick),
    );
    return InitUploadResult.fromJson(_data(decodeMap(res, op: op)));
  }

  Future<String> _refComplete(
    String baseUrl,
    String objectName, {
    required String op,
  }) async {
    debugLog('--- $op ---');
    final res = await withAuth(
      (token) => http
          .post(
            Uri.parse('$baseUrl/complete'),
            headers: authHeaders(token),
            body: jsonEncode({'object_name': objectName}),
          )
          .timeout(_completeTimeout),
    );
    final url = _data(decodeMap(res, op: op))['object_url']?.toString();
    if (url == null) {
      throw Exception('$op: response missing object_url');
    }
    return url;
  }

  Future<InitUploadResult> avatarInitUpload() =>
      _refInitUpload(_avatarUrl, op: 'avatarInitUpload');

  Future<String> avatarComplete({required String objectName}) =>
      _refComplete(_avatarUrl, objectName, op: 'avatarComplete');

  Future<InitUploadResult> bodyRefInitUpload() =>
      _refInitUpload(_bodyRefUrl, op: 'bodyRefInitUpload');

  Future<String> bodyRefComplete({required String objectName}) =>
      _refComplete(_bodyRefUrl, objectName, op: 'bodyRefComplete');

  Future<InitUploadResult> faceRefInitUpload() =>
      _refInitUpload(_faceRefUrl, op: 'faceRefInitUpload');

  Future<String> faceRefComplete({required String objectName}) =>
      _refComplete(_faceRefUrl, objectName, op: 'faceRefComplete');

  // ---- image reads (a 404 means "not set yet", not an error) ----

  Future<String?> getMyAvatar() async {
    debugLog('--- getMyAvatar ---');
    final res = await withAuth(
      (token) => http
          .get(Uri.parse(_avatarUrl), headers: authHeaders(token))
          .timeout(_quick),
    );
    if (res.statusCode == 404) return null;
    return _data(decodeMap(res, op: 'getMyAvatar'))['object_url']?.toString();
  }

  /// Body-ref and face-ref have no dedicated GET — both are bundled into the
  /// main profile response under their own key.
  Future<String?> _profileImageField(String key, {required String op}) async {
    debugLog('--- $op ---');
    final res = await withAuth(
      (token) => http
          .get(Uri.parse(_baseUrl), headers: authHeaders(token))
          .timeout(_quick),
    );
    if (res.statusCode == 404) return null;
    return _data(decodeMap(res, op: op))[key]?.toString();
  }

  Future<String?> getBodyRef() =>
      _profileImageField('body_reference_object_url', op: 'getBodyRef');

  /// The response key (`face_reference_object_url`) is inferred from the
  /// `face-reference` URL path since there's no backend response sample to
  /// confirm against yet; verify once the endpoint is live and adjust if the
  /// key differs.
  Future<String?> getFaceReference() =>
      _profileImageField('face_reference_object_url', op: 'getFaceReference');

  /// The user's Style Taste Profile — one entry per learned preference
  /// dimension (`style_balance`, `color_pairing`, ...), each with its own
  /// `score`/`confidence`/`label`/`insight`. When there isn't enough data
  /// yet (fewer than the backend's analysis minimum), `status` comes back
  /// `"learning"` instead of `"ready"` rather than the backend fabricating
  /// untrustworthy scores — callers should treat scores/confidence as
  /// unreliable in that case.
  Future<StyleTasteProfile> getMyStyleTaste() async {
    debugLog('--- getMyStyleTaste ---');
    final res = await withAuth(
      (token) => http
          .get(Uri.parse(_styleTasteUrl), headers: authHeaders(token))
          .timeout(_quick),
    );
    final data = _data(decodeMap(res, op: 'getMyStyleTaste'));
    debugLog('--- getMyStyleTaste status: ${data['status']} ---');
    return StyleTasteProfile.fromApi(data);
  }

  /// Outfit counts per style tag (`GET /users/me/style_profile`), sorted
  /// high to low by the backend — powers Style Taste's style profile pie
  /// chart.
  Future<List<StyleProfileItem>> getMyStyleProfile() async {
    debugLog('--- getMyStyleProfile ---');
    final res = await withAuth(
      (token) => http
          .get(Uri.parse(_styleProfileUrl), headers: authHeaders(token))
          .timeout(_quick),
    );
    final data = _data(decodeMap(res, op: 'getMyStyleProfile'));
    debugLog('--- getMyStyleProfile data: $data ---');
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(StyleProfileItem.fromJson)
        .toList();
  }

  Future<UserProfile> updateMyProfile({
    String? name,
    String? gender,
    String? birthday,
    num? height,
    num? weight,
    String? unitSystem,
    String? location,
    Map<String, String>? weeklySchedule,
    num? temperatureOffsetC,
    String? locale,
  }) async {
    debugLog('--- updateMyProfile ---');
    final uri = Uri.parse(_baseUrl);

    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (gender != null) payload['gender'] = gender;
    if (birthday != null) payload['birthday'] = birthday;
    if (height != null) payload['height'] = height;
    if (weight != null) payload['weight'] = weight;
    if (unitSystem != null) payload['unit_system'] = unitSystem;
    if (location != null) payload['location'] = location;
    if (weeklySchedule != null) payload['weekly_schedule'] = weeklySchedule;
    if (temperatureOffsetC != null) {
      payload['temperature_offset_c'] = temperatureOffsetC;
    }
    if (locale != null) payload['locale'] = locale;

    final res = await withAuth(
      (token) => http
          .patch(uri, headers: authHeaders(token), body: jsonEncode(payload))
          .timeout(_quick),
    );

    return UserProfile.fromJson(_data(decodeMap(res, op: 'updateMyProfile')));
  }
}
