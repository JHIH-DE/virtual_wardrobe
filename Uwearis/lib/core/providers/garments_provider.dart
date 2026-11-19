import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/garment.dart';
import '../services/garment_service.dart';
import '../utils/signed_url.dart';
import 'list_refetch_guard.dart';
import 'retry_policy.dart';

final garmentsProvider = AsyncNotifierProvider<GarmentsNotifier, List<Garment>>(
  GarmentsNotifier.new,
  retry: appRetryPolicy,
);

class GarmentsNotifier extends AsyncNotifier<List<Garment>> {
  final _guard = ListRefetchGuard<Garment>();

  // The latest favorite write per garment, so an optimistic toggle settling
  // late can't undo a newer one (another screen's).
  final _favoriteWrites = <int, int>{};
  int _favoriteWriteCount = 0;

  @override
  Future<List<Garment>> build() async {
    ref.onDispose(() {
      _guard.reset();
      _favoriteWrites.clear();
    });
    final fresh = await _guard.load(GarmentService().getGarments);
    return fresh ?? state.value ?? const [];
  }

  /// True if any cached signed image URL has expired (or is about to).
  bool get isStale =>
      (state.value?.isNotEmpty ?? false) &&
      anySignedUrlExpired(state.value!.map((g) => g.imageUrl));

  Future<void> refreshIfNeeded() async {
    if (state.isLoading) return;
    if (!state.hasValue || state.value!.isEmpty || isStale) {
      await refresh();
    }
  }

  Future<void> refresh() =>
      _guard.refresh(GarmentService().getGarments, (s) => state = s);

  void _edit(List<Garment> Function(List<Garment>) edit) {
    state = AsyncData(_guard.edit(state.value ?? [], edit));
  }

  void addGarment(Garment garment) => _edit(
    (list) => [
      garment,
      ...list.where((g) => g.id == null || g.id != garment.id),
    ],
  );

  void updateGarment(Garment garment) => _edit(
    (list) => list.map((g) => g.id == garment.id ? garment : g).toList(),
  );

  void removeGarment(int garmentId) =>
      _edit((list) => list.where((g) => g.id != garmentId).toList());

  /// A favorite already confirmed by the server.
  void updateFavorite(int garmentId, {required bool isFavorite}) {
    updateFavoriteOptimistically(garmentId, isFavorite: isFavorite);
  }

  /// Shows [isFavorite] while its PATCH is in flight. Pass the returned
  /// token to [settleFavorite] once the PATCH answers.
  int updateFavoriteOptimistically(int garmentId, {required bool isFavorite}) {
    final token = _favoriteWrites[garmentId] = ++_favoriteWriteCount;
    _setFavorite(garmentId, isFavorite);
    return token;
  }

  /// The PATCH answered: [isFavorite] is the requested value on success,
  /// the previous one on failure. Re-applied on success too, because a
  /// refresh that read the server before the PATCH committed may have
  /// replaced the optimistic value. Ignored when a newer favorite write for
  /// this garment came after [token] (or the provider was rebuilt).
  void settleFavorite(int garmentId, int token, {required bool isFavorite}) {
    if (_favoriteWrites[garmentId] != token) return;
    _setFavorite(garmentId, isFavorite);
  }

  void _setFavorite(int garmentId, bool isFavorite) => _edit(
    (list) => list
        .map((g) => g.id == garmentId ? g.copyWith(isFavorite: isFavorite) : g)
        .toList(),
  );
}
