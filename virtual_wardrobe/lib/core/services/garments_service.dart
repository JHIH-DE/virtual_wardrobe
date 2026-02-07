import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';

import '../../data/garment_category.dart';
import '../config/app_config.dart';
import 'base_service.dart';

class GarmentService with BaseService {

  static final GarmentService _instance = GarmentService._internal();
  static final String _baseUrl = '${AppConfig.fullApiUrl}/garments';
  factory GarmentService() => _instance;
  GarmentService._internal();

  Future<InitUploadResult> initUpload() async {
    debugPrint('--- initUpload ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/init-upload');
    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'content_type': 'image/jpeg'}),
    );

    final envelope = decodeMap(res, op: 'initUpload');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('initUpload: invalid response json');
    }

    return InitUploadResult.fromJson(data);
  }

  Future<void> uploadImage(String uploadUrl, String localPath) async {
    debugPrint('--- uploadImage ---');
    final file = File(localPath);
    final bytes = await file.readAsBytes();
    final uri = Uri.parse(uploadUrl);
    final res = await http.put(uri, headers: {'Content-Type': 'image/jpeg'}, body: bytes);

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('PUT to signed url failed: ${res.statusCode} ${res.body}');
    }
  }

  Future<Garment> completeUpload(Garment garment, Map<String, dynamic>? metaData) async {
    debugPrint('--- completeUpload ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/complete');
    final String? dateStr = garment.purchaseDate?.toIso8601String().split('T')[0];

    final payload = <String, dynamic>{
      'name': garment.name,
      'category': garment.category.apiValue,
      'sub_category': garment.subCategory,
      'object_name': garment.objectName,
      'brand': garment.brand,
      'color': garment.color,
      'price': garment.price,
      'purchase_date': dateStr,
      'thickness': garment.thickness,
      'formality': garment.formality,
      'metadata': metaData,
    };

    final res = await http.post(
      uri,
      headers: authHeaders(token),
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 15));

    final envelope = decodeMap(res, op: 'completeUpload');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('completeUpload: response missing data');
    }
    return Garment.fromJson(data);
  }

  Future<List<Garment>> getGarments() async {
    debugPrint('--- getGarments ---');
    final token = await getSafeToken();
    final uri = Uri.parse(_baseUrl);
    final res = await http.get(uri, headers: authHeaders(token));

    final envelope = decodeMap(res, op: 'getGarments');
    final data = envelope['data'];
    if (data is! List) throw Exception('getGarments: response missing list data');

    return data.whereType<Map<String, dynamic>>().map((j) => Garment.fromJson(j)).toList();
  }

  Future<Garment> getGarment(int garmentId) async {
    debugPrint('--- getGarment ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$garmentId');
    final res = await http.get(uri, headers: authHeaders(token));

    final envelope = decodeMap(res, op: 'getGarment');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('getGarment: response missing data');
    }

    return Garment.fromJson(data);
  }

  Future<void> deleteGarment(int garmentId) async {
    debugPrint('--- deleteGarment ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$garmentId');
    final res = await http.delete(uri, headers: {'Authorization': 'Bearer $token'});
    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) return;
    throw Exception('deleteGarment failed (${res.statusCode})');
  }

  Future<Garment> updateGarment(Garment garment) async {
    debugPrint('--- updateGarment ---');
    if (garment.id == null) throw Exception('updateGarment: missing id');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/${garment.id}');
    final res = await http.patch(uri, headers: authHeaders(token), body: jsonEncode(garment.toJson()));
    final envelope = decodeMap(res, op: 'updateGarment');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('updateGarment: response missing data');

    return Garment.fromJson(data);
  }

  Future<Map<String, dynamic>> analyzeGarment(String localPath) async {
    debugPrint('--- analyzeGarment ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/analyze-instant');
    final request = http.MultipartRequest('POST', uri);

    request.headers.addAll({
      'Authorization': 'Bearer $token',
    });

    final mimeType = lookupMimeType(localPath) ?? 'image/jpeg';
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      localPath,
      contentType: MediaType.parse(mimeType),
    ));

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    final envelope = decodeMap(res, op: 'analyzeInstantGarment');
    return (envelope['data'] as Map<String, dynamic>?) ?? envelope;
  }
}