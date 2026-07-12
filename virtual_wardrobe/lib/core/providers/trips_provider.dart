import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/trip_plan.dart';
import '../services/trip_plan_service.dart';

final tripsProvider = AsyncNotifierProvider<TripsNotifier, List<TripPlan>>(
  TripsNotifier.new,
);

class TripsNotifier extends AsyncNotifier<List<TripPlan>> {
  @override
  Future<List<TripPlan>> build() => TripPlanService().getTripPlans();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => TripPlanService().getTripPlans());
  }

  void add(TripPlan trip) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([trip, ...current]);
  }

  void remove(String id) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((t) => t.id != id).toList());
  }

  void updateTrip(TripPlan trip) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((t) => t.id == trip.id ? trip : t).toList());
  }
}
