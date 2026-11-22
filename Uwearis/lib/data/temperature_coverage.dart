/// `GET /daily_outfits/temperature-coverage`: how many outfits the daily
/// pick can choose from on a day of each average-temperature band. The
/// user's temperature offset is already applied server-side.
class TemperatureCoverage {
  final double temperatureOffsetC;
  final int usableOutfitCount;

  /// Outfits a day needs (main pick + alternatives).
  final int enoughCount;

  /// Coldest to hottest.
  final List<TemperatureBand> bands;

  const TemperatureCoverage({
    required this.temperatureOffsetC,
    required this.usableOutfitCount,
    required this.enoughCount,
    required this.bands,
  });

  factory TemperatureCoverage.fromJson(Map<String, dynamic> json) {
    final enough = (json['enough_count'] as num?)?.toInt() ?? 3;
    final bands = json['bands'];
    return TemperatureCoverage(
      temperatureOffsetC:
          (json['temperature_offset_c'] as num?)?.toDouble() ?? 0,
      usableOutfitCount: (json['usable_outfit_count'] as num?)?.toInt() ?? 0,
      enoughCount: enough,
      bands: bands is List
          ? bands
                .whereType<Map<String, dynamic>>()
                .map((b) => TemperatureBand.fromJson(b, enoughCount: enough))
                .toList()
          : const [],
    );
  }
}

/// `[minC, maxC)` of the day's average temperature; a null end is open.
class TemperatureBand {
  final double? minC;
  final double? maxC;
  final int outfitCount;
  final TemperatureCoverageStatus status;

  const TemperatureBand({
    required this.minC,
    required this.maxC,
    required this.outfitCount,
    required this.status,
  });

  factory TemperatureBand.fromJson(
    Map<String, dynamic> json, {
    required int enoughCount,
  }) {
    final count = (json['outfit_count'] as num?)?.toInt() ?? 0;
    return TemperatureBand(
      minC: (json['min_c'] as num?)?.toDouble(),
      maxC: (json['max_c'] as num?)?.toDouble(),
      outfitCount: count,
      status:
          TemperatureCoverageStatus.fromApiValue(json['status'] as String?) ??
          TemperatureCoverageStatus.fromCount(count, enoughCount),
    );
  }
}

enum TemperatureCoverageStatus {
  none('none'),
  few('few'),
  enough('enough');

  final String apiValue;
  const TemperatureCoverageStatus(this.apiValue);

  static TemperatureCoverageStatus? fromApiValue(String? value) {
    for (final s in values) {
      if (s.apiValue == value) return s;
    }
    return null;
  }

  static TemperatureCoverageStatus fromCount(int count, int enoughCount) {
    if (count <= 0) return none;
    return count < enoughCount ? few : enough;
  }
}
