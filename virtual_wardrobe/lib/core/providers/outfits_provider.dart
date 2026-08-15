import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/outfit.dart';
import '../services/outfit_service.dart';
import '../utils/signed_url.dart';

final outfitsProvider = AsyncNotifierProvider<OutfitsNotifier, List<Outfit>>(
  OutfitsNotifier.new,
);

/// A save/delete that just happened on [OutfitDetailsPage], to be shown as a
/// [showFeedbackOverlay] on [OutfitsPage] once navigation lands back there —
/// set here rather than shown directly, since the details page pops (or
/// pops-to-root) itself away before the message would matter.
enum OutfitFeedbackKind { saved, deleted }

final outfitFeedbackProvider = StateProvider<OutfitFeedbackKind?>(
  (ref) => null,
);

class OutfitsNotifier extends AsyncNotifier<List<Outfit>> {
  // The Outfits tab is standalone try-ons only — 'daily'/'trip' outfits are
  // managed from Home's daily outfit / Trip Details instead, so they're
  // filtered out server-side rather than fetched and discarded.
  @override
  Future<List<Outfit>> build() =>
      OutfitService().getAllOutfits(jobType: 'general');

  /// True if any cached outfit's signed image URL has expired (or is about
  /// to), meaning the cached list should be re-fetched before display.
  bool get isStale {
    final outfits = state.valueOrNull;
    if (outfits == null || outfits.isEmpty) return false;
    return outfits.any(
      (o) => o.imageUrl.isNotEmpty && isSignedUrlExpired(o.imageUrl),
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
    state = await AsyncValue.guard(
      () => OutfitService().getAllOutfits(jobType: 'general'),
    );
  }

  void add(Outfit outfit) {
    final current = state.valueOrNull ?? [];
    state = AsyncData([outfit, ...current]);
  }

  void removeById(int id) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(current.where((o) => o.id != id).toList());
  }

  void updateName(int id, {required String name}) {
    final current = state.valueOrNull ?? [];
    state = AsyncData(
      current.map((o) => o.id == id ? o.copyWith(name: name) : o).toList(),
    );
  }

}
