import 'outfit.dart';

/// `GET /outfit/generations/{key}`'s `status`. A failed generation released
/// its quota; retrying it needs a new Idempotency-Key.
enum TryOnGenerationStatus { processing, succeeded, failed }

extension TryOnGenerationStatusApi on TryOnGenerationStatus {
  String get apiValue => switch (this) {
    TryOnGenerationStatus.processing => 'processing',
    TryOnGenerationStatus.succeeded => 'succeeded',
    TryOnGenerationStatus.failed => 'failed',
  };

  static TryOnGenerationStatus fromApiValue(String? value) => switch (value) {
    'succeeded' => TryOnGenerationStatus.succeeded,
    'failed' => TryOnGenerationStatus.failed,
    _ => TryOnGenerationStatus.processing,
  };
}

/// One try-on generate/regenerate request, looked up by the Idempotency-Key
/// it was sent with.
class TryOnGeneration {
  final TryOnGenerationStatus status;
  final String? errorCode;

  /// Set once succeeded, unless the result has since been deleted.
  final Outfit? outfit;

  const TryOnGeneration({required this.status, this.errorCode, this.outfit});

  factory TryOnGeneration.fromJson(Map<String, dynamic> json) {
    final outfit = json['outfit'];
    return TryOnGeneration(
      status: TryOnGenerationStatusApi.fromApiValue(json['status'] as String?),
      errorCode: json['error_code'] as String?,
      outfit: outfit is Map<String, dynamic> ? Outfit.fromJson(outfit) : null,
    );
  }
}
