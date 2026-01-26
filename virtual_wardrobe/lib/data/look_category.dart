import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'garment_category.dart';

class Look {
  final int id;
  final String imageUrl;
  final String? seasons; 
  final String? style;   
  final String? advice;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final List<Garment> items;

  Look({
    required this.id,
    required this.imageUrl,
    this.seasons,
    this.style,
    this.advice,
    this.errorMessage,
    this.items = const [],
    DateTime? createdAt,
    this.finishedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Look.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    // 健壯地解析 ID，防止 String/int 型別不符
    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    return Look(
      id: parseId(json['job_id']),
      imageUrl: json['result_image_url'] ?? '',
      errorMessage: json['error_message'],
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      finishedAt: parseDate(json['finished_at']),
      seasons: json['seasons'],
      style: json['style'],
      advice: json['ai_notes'],
      items: [], 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': id,
      'result_image_url': imageUrl,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'finished_at': finishedAt?.toIso8601String(),
      'seasons': seasons,
      'style': style,
      'ai_notes': advice,
    };
  }
}

class LooksStore extends ChangeNotifier {
  LooksStore._();
  static final LooksStore I = LooksStore._();

  final List<Look> _looks = [];

  List<Look> get looks => List.unmodifiable(_looks);

  void add(Look look) {
    _looks.insert(0, look);
    notifyListeners();
  }

  void setLooks(List<Look> newLooks) {
    _looks.clear();
    _looks.addAll(newLooks);
    notifyListeners();
  }

  void removeById(int id) { // ✅ 將 String 改為 int 以符合 Look.id 型別
    _looks.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  void clear() {
    _looks.clear();
    notifyListeners();
  }
}
