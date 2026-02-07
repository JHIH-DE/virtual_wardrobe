import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'base_service.dart';

class ProfileService with BaseService {
   static final String _baseUrl = '${AppConfig.fullApiUrl}/users/me';
   static final String _avatarUrl = '$_baseUrl/avatar';
   static final String _fullBodyUrl = '$_baseUrl/full-body';

   Future<Map<String, dynamic>> getMyProfile() async {
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);
    final res = await http.get(uri, headers: authHeaders(token));
    final envelope = decodeMap(res, op: 'getMyProfile');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }

   Future<InitUploadResult> avatarInitUpload() async {
    final token = await getSafeToken();
    final uri = Uri.parse('$_avatarUrl/init-upload');
    final res = await http.post(uri, headers: authHeaders(token), body: jsonEncode({'content_type': 'image/jpeg'}));
    final envelope = decodeMap(res, op: 'avatarInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

   Future<String> avatarComplete({required String objectName}) async {
    final token = await getSafeToken();
    final uri = Uri.parse('$_avatarUrl/complete');
    final res = await http.post(uri, headers: authHeaders(token), body: jsonEncode({'object_name': objectName}));
    final envelope = decodeMap(res, op: 'avatarComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) throw Exception('avatarComplete: response missing object_url');
    return url;
  }

   Future<String?> getMyAvatar() async {
    final token = await getSafeToken();
    final uri = Uri.parse(_avatarUrl);
    final res = await http.get(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);
    if (res.statusCode == 404) return null;
    final envelope = decodeMap(res, op: 'getMyAvatar');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['object_url']?.toString();
  }

  Future<InitUploadResult> fullBodyInitUpload() async {
    final token = await getSafeToken();
    final uri = Uri.parse('$_fullBodyUrl/init-upload');
    final res = await http.post(uri, headers: authHeaders(token), body: jsonEncode({'content_type': 'image/jpeg'}));
    final envelope = decodeMap(res, op: 'fullBodyInitUpload');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return InitUploadResult.fromJson(data);
  }

  Future<String> fullBodyComplete({required String objectName}) async {
    final token = await getSafeToken();
    final uri = Uri.parse('$_fullBodyUrl/complete');
    final res = await http.post(uri, headers: authHeaders(token), body: jsonEncode({'object_name': objectName}));
    final envelope = decodeMap(res, op: 'fullBodyComplete');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    final url = data['object_url']?.toString();
    if (url == null) throw Exception('fullBodyComplete: response missing object_url');
    return url;
  }

  Future<String?> getMyFullBody() async {
    final token = await getSafeToken();
    final uri = Uri.parse(_fullBodyUrl);
    final res = await http.get(uri, headers: authHeaders(token));
    throwIfAuthExpired(res);
    if (res.statusCode == 404) return null;
    final envelope = decodeMap(res, op: 'getMyFullBody');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? envelope;
    return data['object_url']?.toString();
  }

  Future<Map<String, dynamic>> updateMyProfile(
       {
         String? name,
         String? gender,
         String? birthday,
         num? height,
         num? weight,
         String? unitSystem,
       }) async {
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);

     final payload = <String, dynamic>{};
     if (name != null) payload['name'] = name;
     if (gender != null) payload['gender'] = gender;
     if (birthday != null) payload['birthday'] = birthday;
     if (height != null) payload['height'] = height;
     if (weight != null) payload['weight'] = weight;
     if (unitSystem != null) payload['unit_system'] = unitSystem;

     final res = await http.patch(
       uri,
       headers: authHeaders(token),
       body: jsonEncode(payload),
     );

     final envelope = decodeMap(res, op: 'updateMyProfile');
     return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
   }
}