import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/profile_data.dart';
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
  static final String _baseModelUrl = '$_baseUrl/base-model';
  static final String _styleTasteUrl = '$_baseUrl/style_taste';
  static final String _styleProfileUrl = '$_baseUrl/style_profile';

  static const _quick = Duration(seconds: 15);
  // `complete` runs server-side background removal.
  static const _completeTimeout = Duration(seconds: 60);
  // Synchronous AI generation; the API doc asks for at least 120s.
  static const _generateTimeout = Duration(seconds: 120);

  /// `data`, or the whole body for an un-enveloped response.
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

  /// Profile plus the reference-photo and base-model signed URLs, from one
  /// request. A URL can still point at a deleted object; that surfaces as an
  /// image load error, not here.
  Future<ProfileData> getMyProfileData() async {
    debugLog('--- getMyProfileData ---');
    final res = await withAuth(
      (token) => http
          .get(Uri.parse(_baseUrl), headers: authHeaders(token))
          .timeout(_quick),
    );
    final data = _data(decodeMap(res, op: 'getMyProfileData'));
    return ProfileData(
      profile: UserProfile.fromJson(data),
      bodyRefUrl: data['body_reference_object_url']?.toString(),
      faceRefUrl: data['face_reference_object_url']?.toString(),
      baseModelUrl: data['base_model_object_url']?.toString(),
    );
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

  /// init-upload → PUT to signed URL → complete; returns the new signed URL.
  Future<String> _uploadRef(
    String baseUrl,
    String localPath, {
    required String opPrefix,
  }) async {
    final init = await _refInitUpload(baseUrl, op: '${opPrefix}InitUpload');
    await putJpegToSignedUrl(init.uploadUrl, localPath);
    return _refComplete(baseUrl, init.objectName, op: '${opPrefix}Complete');
  }

  Future<String> uploadAvatar(String localPath) =>
      _uploadRef(_avatarUrl, localPath, opPrefix: 'avatar');

  Future<String> uploadBodyRef(String localPath) =>
      _uploadRef(_bodyRefUrl, localPath, opPrefix: 'bodyRef');

  Future<String> uploadFaceRef(String localPath) =>
      _uploadRef(_faceRefUrl, localPath, opPrefix: 'faceRef');

  /// Also deletes the server-processed variant; 404 counts as success.
  Future<void> _deleteRef(String baseUrl, {required String op}) async {
    debugLog('--- $op ---');
    await deleteIdempotent(Uri.parse(baseUrl), op: op);
  }

  Future<void> deleteAvatar() => _deleteRef(_avatarUrl, op: 'deleteAvatar');

  /// Also deletes the existing base model on the backend, since it was
  /// generated from this photo — callers should clear `baseModelUrl` too.
  Future<void> deleteBodyRef() => _deleteRef(_bodyRefUrl, op: 'deleteBodyRef');

  /// Same base-model side effect as [deleteBodyRef].
  Future<void> deleteFaceRef() => _deleteRef(_faceRefUrl, op: 'deleteFaceRef');

  /// Generates from the body reference (required) and face reference
  /// (optional); uploads don't trigger it. A failure keeps the previous
  /// model. Not counted against the daily try-on quota.
  Future<String> generateBaseModel() async {
    debugLog('--- generateBaseModel ---');
    final res = await withAuth(
      (token) => http
          .post(
            Uri.parse('$_baseModelUrl/generate'),
            headers: authHeaders(token),
          )
          .timeout(_generateTimeout),
    );
    final url = _data(
      decodeMap(res, op: 'generateBaseModel'),
    )['object_url']?.toString();
    if (url == null) {
      throw Exception('generateBaseModel: response missing object_url');
    }
    return url;
  }

  // ---- image reads (a 404 means "not set yet", not an error) ----

  /// The photos have no GET of their own; re-signs via the profile response.
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

  Future<String?> getMyAvatar() =>
      _profileImageField('avatar_object_url', op: 'getMyAvatar');

  Future<String?> getBodyRef() =>
      _profileImageField('body_reference_object_url', op: 'getBodyRef');

  Future<String?> getFaceReference() =>
      _profileImageField('face_reference_object_url', op: 'getFaceReference');

  Future<String?> getBaseModel() =>
      _profileImageField('base_model_object_url', op: 'getBaseModel');

  /// `status` is `"learning"` (scores unreliable) until the backend has
  /// enough data, then `"ready"`.
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

  /// Outfit counts per style tag, sorted high to low by the backend.
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
    num? temperatureOffsetC,
    String? locale,
  }) async {
    // Null means "leave unchanged", so this can't clear a field.
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

  /// Permanent, including all stored files. 404 counts as success.
  Future<void> deleteMyAccount() async {
    debugLog('--- deleteMyAccount ---');
    await deleteIdempotent(Uri.parse(_baseUrl), op: 'deleteMyAccount');
  }
}
