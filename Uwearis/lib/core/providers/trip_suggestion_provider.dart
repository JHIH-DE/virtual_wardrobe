import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/packing_analysis.dart';
import '../services/trip_service.dart';
import 'retry_policy.dart';

/// A trip's packing analysis, shared by Trip Details and the suitcase
/// garment picker so the picker doesn't re-fetch.
final tripSuggestionProvider = FutureProvider.family<PackingAnalysis, int>(
  (ref, tripId) => TripService().getTripSuggestion(tripId),
  retry: appRetryPolicy,
);
