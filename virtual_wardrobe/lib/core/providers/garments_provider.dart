import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/garments_service.dart';
import '../../data/garment.dart';

final garmentsProvider =
    AsyncNotifierProvider<GarmentsNotifier, List<Garment>>(GarmentsNotifier.new);

class GarmentsNotifier extends AsyncNotifier<List<Garment>> {
  @override
  Future<List<Garment>> build() => GarmentService().getGarments();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => GarmentService().getGarments());
  }

  void addGarment(Garment garment) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, garment]);
  }

  void updateGarment(Garment garment) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.map((g) => g.id == garment.id ? garment : g).toList());
  }

  void removeGarment(int garmentId) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((g) => g.id != garmentId).toList());
  }
}
