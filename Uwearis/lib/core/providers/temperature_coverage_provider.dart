import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/temperature_coverage.dart';
import '../services/daily_outfit_service.dart';
import 'retry_policy.dart';

/// Auto-disposed, so each Outfit Insights visit fetches fresh counts.
final temperatureCoverageProvider =
    FutureProvider.autoDispose<TemperatureCoverage>(
      (ref) => DailyOutfitService().getTemperatureCoverage(),
      retry: appRetryPolicy,
    );
