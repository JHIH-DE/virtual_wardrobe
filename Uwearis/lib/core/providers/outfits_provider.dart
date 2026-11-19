import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/outfit.dart';
import '../services/outfit_service.dart';
import '../utils/signed_url.dart';
import 'list_refetch_guard.dart';
import 'retry_policy.dart';

final outfitsProvider = AsyncNotifierProvider<OutfitsNotifier, List<Outfit>>(
  OutfitsNotifier.new,
  retry: appRetryPolicy,
);

/// Feedback for OutfitsPage to show once navigation lands back there — the
/// details page that caused it has already popped itself away.
enum OutfitFeedbackKind { saved, deleted }

final outfitFeedbackProvider = StateProvider<OutfitFeedbackKind?>(
  (ref) => null,
);

class OutfitsNotifier extends AsyncNotifier<List<Outfit>> {
  final _guard = ListRefetchGuard<Outfit>();

  // `general` outfits only (getAllOutfits' default type). The sort is pinned
  // rather than left to the backend default: Home's _latestOwnOutfit relies
  // on state.first being the newest.
  static Future<List<Outfit>> _fetch() =>
      OutfitService().getAllOutfits(sort: 'created_at_desc');

  // The latest favorite write per outfit, so an optimistic toggle settling
  // late can't undo a newer one (another screen's).
  final _favoriteWrites = <int, int>{};
  int _favoriteWriteCount = 0;

  @override
  Future<List<Outfit>> build() async {
    ref.onDispose(() {
      _guard.reset();
      _favoriteWrites.clear();
    });
    final fresh = await _guard.load(_fetch);
    return fresh ?? state.value ?? const [];
  }

  /// True if any cached signed image URL has expired (or is about to).
  bool get isStale =>
      (state.value?.isNotEmpty ?? false) &&
      anySignedUrlExpired(state.value!.map((o) => o.imageUrl));

  Future<void> refreshIfNeeded() async {
    if (state.isLoading) return;
    if (!state.hasValue || state.value!.isEmpty || isStale) {
      await refresh();
    }
  }

  Future<void> refresh() => _guard.refresh(_fetch, (s) => state = s);

  void _edit(List<Outfit> Function(List<Outfit>) edit) {
    state = AsyncData(_guard.edit(state.value ?? [], edit));
  }

  void removeOutfit(int id) =>
      _edit((list) => list.where((o) => o.id != id).toList());

  // Field-level, not a whole-Outfit replace: callers hold copies from other
  // endpoints (a group's versions, today's plan) without this list's
  // versionCount / group fields, and maybe an older signed image URL than a
  // refresh's reply the edit is replayed onto.
  /// A favorite already confirmed by the server.
  void updateOutfitFavorite(int outfitId, {required bool isFavorite}) {
    updateOutfitFavoriteOptimistically(outfitId, isFavorite: isFavorite);
  }

  /// Shows [isFavorite] while its PATCH is in flight. Pass the returned
  /// token to [settleOutfitFavorite] once the PATCH answers.
  int updateOutfitFavoriteOptimistically(
    int outfitId, {
    required bool isFavorite,
  }) {
    final token = _favoriteWrites[outfitId] = ++_favoriteWriteCount;
    _editOutfit(outfitId, (o) => o.copyWith(isFavorite: isFavorite));
    return token;
  }

  /// The PATCH answered: [isFavorite] is the requested value on success,
  /// the previous one on failure. Re-applied on success too, because a
  /// refresh that read the server before the PATCH committed may have
  /// replaced the optimistic value. Ignored when a newer favorite write for
  /// this outfit came after [token] (or the provider was rebuilt).
  void settleOutfitFavorite(
    int outfitId,
    int token, {
    required bool isFavorite,
  }) {
    if (_favoriteWrites[outfitId] != token) return;
    _editOutfit(outfitId, (o) => o.copyWith(isFavorite: isFavorite));
  }

  void updateOutfitTags(
    int outfitId, {
    required List<String> seasons,
    required List<String> style,
  }) =>
      _editOutfit(outfitId, (o) => o.copyWith(seasons: seasons, style: style));

  void _editOutfit(int outfitId, Outfit Function(Outfit) update) =>
      _edit((list) => [for (final o in list) o.id == outfitId ? update(o) : o]);

  /// The name is group-level, shared by every version in the group.
  void updateGroupName(int groupId, {required String name}) => _edit(
    (list) => list
        .map((o) => o.groupId == groupId ? o.copyWith(groupName: name) : o)
        .toList(),
  );
}
