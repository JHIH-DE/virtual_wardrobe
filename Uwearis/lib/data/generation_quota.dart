/// `GET /outfit/generation-quota`: today's AI try-on allowance. Counts every
/// render (Create Outfit, versions, regenerate, trip try-on).
class GenerationQuota {
  /// Null: this account's tier has no daily limit.
  final int? limit;
  final int used;
  final int? remaining;

  /// When the count resets (00:00 Asia/Taipei), in device-local time.
  final DateTime resetsAt;

  const GenerationQuota({
    required this.limit,
    required this.used,
    required this.remaining,
    required this.resetsAt,
  });

  bool get isUnlimited => limit == null;

  factory GenerationQuota.fromJson(Map<String, dynamic> json) {
    return GenerationQuota(
      limit: (json['limit'] as num?)?.toInt(),
      used: (json['used'] as num?)?.toInt() ?? 0,
      remaining: (json['remaining'] as num?)?.toInt(),
      resetsAt: DateTime.parse(json['resets_at'] as String).toLocal(),
    );
  }
}
