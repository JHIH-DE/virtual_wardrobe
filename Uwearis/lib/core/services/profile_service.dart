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

  /// One `GET /users/me` request parsed into everything Account / Settings /
  /// Home / My Virtual Model need: the profile fields plus both reference-photo
  /// signed URLs and the generated base-model signed URL — all four already
  /// live in the same response body (see [_profileImageField]'s doc).
  /// [ProfileNotifier] uses this instead of calling
  /// [getMyProfile]/[getBodyRef]/[getFaceReference] separately (that used to
  /// be 3 redundant requests to this same endpoint via `Future.wait`).
  ///
  /// Note: this only reflects what the backend's DB record says (an
  /// `object_name` set → a signed URL comes back) — it does not verify the
  /// underlying GCS object still exists. A stale/deleted object 404s only
  /// when the image widget actually requests the signed URL; that's a
  /// per-image UI concern (see `RefreshableNetworkImage`/`AppImage`'s
  /// `onLoadError`), not something this call can detect or should fail on.
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

  /// The whole init-upload → PUT-to-signed-URL → complete flow for one
  /// reference photo, returning its new signed object URL. Callers just hand
  /// over the local file path — see [account_page] / [my_virtual_model_page].
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

  /// Manually (re-)triggers base-model generation from the user's currently
  /// committed body-reference (required) and face-reference (optional —
  /// used as the face identity input only if one has been uploaded) photos.
  /// Every successful generation clears the previous base-model GCS file on
  /// the backend, so this is a destructive replace, not an append. Returns
  /// the newly-generated base model's signed `object_url`.
  Future<String> generateBaseModel() async {
    debugLog('--- generateBaseModel ---');
    final res = await withAuth(
      (token) => http
          .post(Uri.parse('$_baseModelUrl/generate'), headers: authHeaders(token))
          .timeout(_completeTimeout),
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

  /// Permanently deletes the signed-in user's account — every DB row and GCS
  /// file under it — with no way to undo it. 404 (already deleted) is
  /// treated as success, same as every other idempotent delete in the app.
  Future<void> deleteMyAccount() async {
    debugLog('--- deleteMyAccount ---');
    await deleteIdempotent(Uri.parse(_baseUrl), op: 'deleteMyAccount');
  }
}
