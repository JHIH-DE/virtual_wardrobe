import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/look.dart';
import '../services/looks_service.dart';

final looksProvider =
    AsyncNotifierProvider<LooksNotifier, List<Look>>(LooksNotifier.new);

class LooksNotifier extends AsyncNotifier<List<Look>> {
  @override
  Future<List<Look>> build() => LookService().getAllLooks();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => LookService().getAllLooks());
  }

  void add(Look look) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([look, ...current]);
  }

  void removeById(int id) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((l) => l.id != id).toList());
  }

  void updateName(int id, {required String name}) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((l) => l.id == id ? l.copyWith(name: name) : l).toList(),
    );
  }

  void updateFavorite(int id, {required bool isFavorite}) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((l) => l.id == id ? l.copyWith(isFavorite: isFavorite) : l).toList(),
    );
  }
}
