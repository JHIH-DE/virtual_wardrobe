import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/outfit.dart';
import '../services/outfit_service.dart';
import '../utils/signed_url.dart';
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
  // `general` outfits only (getAllOutfits' default type). The sort is pinned
  // rather than left to the backend default: Home's _latestOwnOutfit relies
  // on state.first being the newest.
  @override
  Future<List<Outfit>> build() =>
      OutfitService().getAllOutfits(sort: 'created_at_desc');

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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => OutfitService().getAllOutfits(sort: 'created_at_desc'),
    );
  }

  void removeOutfit(int id) {
    final current = state.value ?? [];
    state = AsyncData(current.where((o) => o.id != id).toList());
  }

  void updateOutfit(Outfit outfit) {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((o) => o.id == outfit.id ? outfit : o).toList(),
    );
  }

  /// The name is group-level, shared by every version in the group.
  void updateGroupName(int groupId, {required String name}) {
    final current = state.value ?? [];
    state = AsyncData(
      current
          .map((o) => o.groupId == groupId ? o.copyWith(groupName: name) : o)
          .toList(),
    );
  }
}
