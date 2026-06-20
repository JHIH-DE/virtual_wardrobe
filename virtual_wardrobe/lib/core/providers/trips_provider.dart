import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/trip_plan.dart';

final tripsProvider =
    NotifierProvider<TripsNotifier, List<TripPlan>>(TripsNotifier.new);

class TripsNotifier extends Notifier<List<TripPlan>> {
  @override
  List<TripPlan> build() => [];

  void add(TripPlan trip) => state = [trip, ...state];

  void remove(String id) => state = state.where((t) => t.id != id).toList();
}
