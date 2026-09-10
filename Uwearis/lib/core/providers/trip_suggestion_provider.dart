import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/packing_analysis.dart';
import '../services/trip_service.dart';

/// A trip's packing analysis (`GET /{trip_id}/suggestion`), keyed by trip id.
/// Shared by Trip Details' packing-advice card and the suitcase garment
/// picker two screens deeper — the picker no longer re-fetches what the
/// details page already has. Force a re-fetch with
/// `ref.invalidate(tripSuggestionProvider(tripId))`.
final tripSuggestionProvider = FutureProvider.family<PackingAnalysis, int>(
  (ref, tripId) => TripService().getTripSuggestion(tripId),
);
