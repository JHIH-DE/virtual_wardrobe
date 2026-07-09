import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/look.dart';
import '../services/look_service.dart';
import '../utils/signed_url.dart';

final looksProvider = AsyncNotifierProvider<LooksNotifier, List<Look>>(
  LooksNotifier.new,
);

class LooksNotifier extends AsyncNotifier<List<Look>> {
  @override
  Future<List<Look>> build() => LookService().getAllLooks();

  /// True if any cached look's signed image URL has expired (or is about
  /// to), meaning the cached list should be re-fetched before display.
  bool get isStale {
    final looks = state.valueOrNull;
    if (looks == null || looks.isEmpty) return false;
    return looks.any(
      (l) => l.imageUrl.isNotEmpty && isSignedUrlExpired(l.imageUrl),
    );
  }

  /// Refreshes the list only if it's empty or its image URLs are stale.
  Future<void> refreshIfNeeded() async {
    if (state.isLoading) return;
    if (!state.hasValue || state.value!.isEmpty || isStale) {
      await refresh();
    }
  }

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
      current
          .map((l) => l.id == id ? l.copyWith(isFavorite: isFavorite) : l)
          .toList(),
    );
  }
}
