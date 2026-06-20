import 'package:flutter/material.dart';

class Look {
  final int id;
  final List<int> garmentIds;
  final String imageUrl;
  final String? seasons;
  final String? style;
  final String? advice;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? finishedAt;

  Look({
    required this.id,
    this.garmentIds = const [],
    required this.imageUrl,
    this.seasons,
    this.style,
    this.advice,
    this.errorMessage,
    DateTime? createdAt,
    this.finishedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Look.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    int parseId(dynamic v) {
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    List<int> parseIds(dynamic v) {
      if (v is List) {
        return v.map((e) => parseId(e)).toList();
      }
      return [];
    }

    return Look(
      id: parseId(json['job_id']),
      garmentIds: parseIds(json['garment_ids']),
      imageUrl: json['result_image_url'] ?? '',
      errorMessage: json['error_message'],
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      finishedAt: parseDate(json['finished_at']),
      seasons: json['seasons'],
      style: json['style'],
      advice: json['ai_notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'job_id': id,
      'garment_ids': garmentIds,
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
