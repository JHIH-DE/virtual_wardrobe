import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'base_service.dart';

class ProfileService with BaseService {
   Future<Map<String, dynamic>> getMyProfile(String accessToken) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    final envelope = decodeMap(res, op: 'getMyProfile');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

   Future<InitUploadResult> avatarInitUpload(String accessToken) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me/avatar/init-upload');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'content_type': 'image/jpeg'}));
    final envelope = decodeMap(res, op: 'avatarInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

   Future<String> avatarComplete(String accessToken, {required String objectName}) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me/avatar/complete');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'object_name': objectName}));
    final envelope = decodeMap(res, op: 'avatarComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) throw Exception('avatarComplete: response missing object_url');
    return url;
  }

   Future<String?> getMyAvatar(String accessToken) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me/avatar');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    throwIfAuthExpired(res);
    if (res.statusCode == 404) return null;
    final envelope = decodeMap(res, op: 'getMyAvatar');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['object_url']?.toString();
  }

  Future<InitUploadResult> fullBodyInitUpload(String accessToken) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me/full-body/init-upload');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'content_type': 'image/jpeg'}));
    final envelope = decodeMap(res, op: 'fullBodyInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

  Future<String> fullBodyComplete(String accessToken, {required String objectName}) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me/full-body/complete');
    final res = await http.post(uri, headers: authHeaders(accessToken), body: jsonEncode({'object_name': objectName}));
    final envelope = decodeMap(res, op: 'fullBodyComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) throw Exception('fullBodyComplete: response missing object_url');
    return url;
  }

  Future<String?> getMyFullBody(String accessToken) async {
    final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me/full-body');
    final res = await http.get(uri, headers: authHeaders(accessToken));
    throwIfAuthExpired(res);
    if (res.statusCode == 404) return null;
    final envelope = decodeMap(res, op: 'getMyFullBody');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['object_url']?.toString();
  }

  Future<Map<String, dynamic>> updateMyProfile(
       String accessToken, {
         String? name,
         String? gender,
         String? birthday,
         num? height,
         num? weight,
         String? unitSystem,
       }) async {
     final uri = Uri.parse('${AppConfig.fullApiUrl}/users/me');

     final payload = <String, dynamic>{};
     if (name != null) payload['name'] = name;
     if (gender != null) payload['gender'] = gender;
     if (birthday != null) payload['birthday'] = birthday;
     if (height != null) payload['height'] = height;
     if (weight != null) payload['weight'] = weight;
     if (unitSystem != null) payload['unit_system'] = unitSystem;

     final res = await http.patch(
       uri,
       headers: authHeaders(accessToken),
       body: jsonEncode(payload),
     );

     final envelope = decodeMap(res, op: 'updateMyProfile');
     return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
   }
}