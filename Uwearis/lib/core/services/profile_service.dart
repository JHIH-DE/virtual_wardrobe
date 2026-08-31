import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/style_profile.dart';
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

  Future<Map<String, dynamic>> getMyProfile() async {
    debugLog('--- getMyProfile ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getMyProfile');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

  Future<InitUploadResult> avatarInitUpload() async {
    debugLog('--- avatarInitUpload ---');
    final uri = Uri.parse('$_avatarUrl/init-upload');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'content_type': 'image/jpeg'}),
      ),
    );
    final envelope = decodeMap(res, op: 'avatarInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

  Future<String> avatarComplete({required String objectName}) async {
    debugLog('--- avatarComplete ---');
    final uri = Uri.parse('$_avatarUrl/complete');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'object_name': objectName}),
      ),
    );
    final envelope = decodeMap(res, op: 'avatarComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) {
      throw Exception('avatarComplete: response missing object_url');
    }
    return url;
  }

  Future<String?> getMyAvatar() async {
    debugLog('--- getMyAvatar ---');
    final uri = Uri.parse(_avatarUrl);
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    if (res.statusCode == 404) return null;
    final envelope = decodeMap(res, op: 'getMyAvatar');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['object_url']?.toString();
  }

  Future<InitUploadResult> bodyRefInitUpload() async {
    debugLog('--- bodyRefInitUpload ---');
    final uri = Uri.parse('$_bodyRefUrl/init-upload');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'content_type': 'image/jpeg'}),
      ),
    );
    final envelope = decodeMap(res, op: 'bodyRefInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

  Future<String> bodyRefComplete({required String objectName}) async {
    debugLog('--- bodyRefComplete ---');
    final uri = Uri.parse('$_bodyRefUrl/complete');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'object_name': objectName}),
      ),
    );
    final envelope = decodeMap(res, op: 'bodyRefComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) {
      throw Exception('bodyRefComplete: response missing object_url');
    }
    return url;
  }

  Future<String?> getBodyRef() async {
    debugLog('--- getBodyRef ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    if (res.statusCode == 404) return null;
    final envelope = decodeMap(res, op: 'getBodyRef');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['body_reference_object_url']?.toString();
  }

  Future<InitUploadResult> faceRefInitUpload() async {
    debugLog('--- faceRefInitUpload ---');
    final uri = Uri.parse('$_faceRefUrl/init-upload');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'content_type': 'image/jpeg'}),
      ),
    );
    final envelope = decodeMap(res, op: 'faceRefInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

  Future<String> faceRefComplete({required String objectName}) async {
    debugLog('--- faceRefComplete ---');
    final uri = Uri.parse('$_faceRefUrl/complete');
    final res = await withAuth(
      (token) => http.post(
        uri,
        headers: authHeaders(token),
        body: jsonEncode({'object_name': objectName}),
      ),
    );
    final envelope = decodeMap(res, op: 'faceRefComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) {
      throw Exception('faceRefComplete: response missing object_url');
    }
    return url;
  }

  /// Mirrors [getBodyRef] — bundled into the main profile GET rather
  /// than a dedicated fetch endpoint. The response key
  /// (`face_reference_object_url`) is inferred from the `face-reference`
  /// URL path since there's no backend response sample to confirm
  /// against yet; verify once the endpoint is live and adjust if the key
  /// differs.
  Future<String?> getFaceReference() async {
    debugLog('--- getFaceReference ---');
    final uri = Uri.parse(_baseUrl);
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    if (res.statusCode == 404) return null;
    final envelope = decodeMap(res, op: 'getFaceReference');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['face_reference_object_url']?.toString();
  }

  /// The user's Style Taste Profile — one entry per learned preference
  /// dimension (`style_balance`, `color_pairing`, ...), each with its own
  /// `score`/`confidence`/`label`/`insight`. When there isn't enough data
  /// yet (fewer than the backend's analysis minimum), `status` comes back
  /// `"learning"` instead of `"ready"` rather than the backend fabricating
  /// untrustworthy scores — callers should treat scores/confidence as
  /// unreliable in that case.
  Future<Map<String, dynamic>> getMyStyleTaste() async {
    debugLog('--- getMyStyleTaste ---');
    final uri = Uri.parse(_styleTasteUrl);
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getMyStyleTaste');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    debugLog('--- getMyStyleTaste data: $data ---');
    return data;
  }

  /// Outfit counts per style tag (`GET /users/me/style_profile`), sorted
  /// high to low by the backend — powers Style Taste's style profile pie
  /// chart.
  Future<List<StyleProfileItem>> getMyStyleProfile() async {
    debugLog('--- getMyStyleProfile ---');
    final uri = Uri.parse(_styleProfileUrl);
    final res = await withAuth(
      (token) => http.get(uri, headers: authHeaders(token)),
    );
    final envelope = decodeMap(res, op: 'getMyStyleProfile');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    debugLog('--- getMyStyleProfile data: $data ---');
    final items = data['items'];
    if (items is! List) return const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(StyleProfileItem.fromJson)
        .toList();
  }

  Future<Map<String, dynamic>> updateMyProfile({
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
      (token) => http.patch(
        uri,
        headers: authHeaders(token),
        body: jsonEncode(payload),
      ),
    );

    final envelope = decodeMap(res, op: 'updateMyProfile');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }
}
