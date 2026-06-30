import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/garment.dart';
import '../config/app_config.dart';
import 'base_service.dart';

class AnalyzeGarmentResult {
  final Map<String, dynamic> metadata;
  final String? processedImagePath;

  const AnalyzeGarmentResult({required this.metadata, this.processedImagePath});
}

class GarmentService with BaseService {

  static final GarmentService _instance = GarmentService._internal();
  static final String _baseUrl = '${AppConfig.fullApiUrl}/garments';
  factory GarmentService() => _instance;
  GarmentService._internal();

  final Map<int, Garment> _cache = {};

  Future<InitUploadResult> initUpload() async {
    debugPrint('--- initUpload ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/init-upload');
    final res = await http.post(
      uri,
      headers: authHeaders(token),
      body: jsonEncode({'content_type': 'image/jpeg'}),
    ).timeout(const Duration(seconds: 15));

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
    final res = await http.put(
      uri, 
      headers: {'Content-Type': 'image/jpeg'}, 
      body: bytes
    ).timeout(const Duration(seconds: 45)); // Image upload can take longer
    
    throwIfAuthExpired(res);

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
    final res = await http.get(uri, headers: authHeaders(token)).timeout(const Duration(seconds: 15));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'getGarments');
    final data = envelope['data'];
    if (data is! List) throw Exception('getGarments: response missing list data');

    final garments = data.whereType<Map<String, dynamic>>().map((j) => Garment.fromJson(j)).toList();
    for (final g in garments) {
      if (g.id != null) _cache[g.id!] = g;
    }
    return garments;
  }

  Future<Garment> getGarment(int garmentId) async {
    if (_cache.containsKey(garmentId)) return _cache[garmentId]!;

    debugPrint('--- getGarment: $garmentId  ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$garmentId');
    final res = await http.get(uri, headers: authHeaders(token)).timeout(const Duration(seconds: 15));
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'getGarment');
    final data = envelope['data'] as Map<String, dynamic>?;

    if (data == null) {
      throw Exception('getGarment: response missing data');
    }

    final garment = Garment.fromJson(data);
    _cache[garmentId] = garment;
    return garment;
  }

  Future<void> deleteGarment(int garmentId) async {
    debugPrint('--- deleteGarment: $garmentId ---');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/$garmentId');
    final res = await http.delete(uri, headers: authHeaders(token)).timeout(const Duration(seconds: 15));
    throwIfAuthExpired(res);
    if (res.statusCode == 200 || res.statusCode == 204 || res.statusCode == 404) {
      _cache.remove(garmentId);
      return;
    }
    throw Exception('deleteGarment failed (${res.statusCode})');
  }

  Future<Garment> updateGarment(Garment garment) async {
    debugPrint('--- updateGarment ---');
    if (garment.id == null) throw Exception('updateGarment: missing id');
    final token = await getSafeToken();
    final uri = Uri.parse('$_baseUrl/${garment.id}');
    final res = await http.patch(
      uri, 
      headers: authHeaders(token), 
      body: jsonEncode(garment.toJson())
    ).timeout(const Duration(seconds: 15));
    
    throwIfAuthExpired(res);
    final envelope = decodeMap(res, op: 'updateGarment');
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) throw Exception('updateGarment: response missing data');

    final updated = Garment.fromJson(data);
    if (updated.id != null) _cache[updated.id!] = updated;
    return updated;
  }

  Future<AnalyzeGarmentResult> analyzeGarment(String localPath) async {
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

    final streamedRes = await request.send().timeout(const Duration(seconds: 30));
    final res = await http.Response.fromStream(streamedRes);

    final envelope = decodeMap(res, op: 'analyzeInstantGarment');
    final data = (envelope['data'] as Map<String, dynamic>?) ?? {};
    final metadata = (data['metadata'] as Map<String, dynamic>?) ?? {};

    String? processedImagePath;
    final base64Str = data['processed_image_base64'] as String?;
    if (base64Str != null && base64Str.isNotEmpty) {
      final bytes = base64Decode(base64Str);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/processed_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes);
      processedImagePath = file.path;
    }

    return AnalyzeGarmentResult(metadata: metadata, processedImagePath: processedImagePath);
  }
}
