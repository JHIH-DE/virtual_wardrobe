import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/outfit_service.dart';
import '../../data/look_category.dart';

final looksProvider =
    AsyncNotifierProvider<LooksNotifier, List<Look>>(LooksNotifier.new);

class LooksNotifier extends AsyncNotifier<List<Look>> {
  @override
  Future<List<Look>> build() => OutfitService().getAllOutfits();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => OutfitService().getAllOutfits());
  }

  void add(Look look) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([look, ...current]);
  }

  void removeById(int id) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((l) => l.id != id).toList());
  }
}
