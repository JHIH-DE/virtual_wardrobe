import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/garment.dart';
import '../services/garment_service.dart';
import '../utils/signed_url.dart';

final garmentsProvider = AsyncNotifierProvider<GarmentsNotifier, List<Garment>>(
  GarmentsNotifier.new,
);

class GarmentsNotifier extends AsyncNotifier<List<Garment>> {
  @override
  Future<List<Garment>> build() => GarmentService().getGarments();

  /// True if any cached garment's signed image URL has expired (or is about
  /// to), meaning the cached list should be re-fetched before display.
  bool get isStale {
    final garments = state.valueOrNull;
    if (garments == null || garments.isEmpty) return false;
    return garments.any((g) {
      final url = g.imageUrl;
      return url != null && url.isNotEmpty && isSignedUrlExpired(url);
    });
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
    state = await AsyncValue.guard(() => GarmentService().getGarments());
  }

  void addGarment(Garment garment) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([...current, garment]);
  }

  void updateGarment(Garment garment) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((g) => g.id == garment.id ? garment : g).toList(),
    );
  }

  void removeGarment(int garmentId) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((g) => g.id != garmentId).toList());
  }

  void updateFavorite(int garmentId, {required bool isFavorite}) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current
          .map(
            (g) => g.id == garmentId ? g.copyWith(isFavorite: isFavorite) : g,
          )
          .toList(),
    );
  }
}
