import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/outfit.dart';
import '../services/daily_outfit_service.dart';
import '../utils/signed_url.dart';

/// Today's server-generated daily outfit options (empty means no plan for
/// today yet). Generation/rendering is entirely server-side on its own
/// schedule, so this is a plain read — same shape as [outfitsProvider], just
/// scoped to the current date.
final dailyOutfitProvider =
    AsyncNotifierProvider<DailyOutfitNotifier, List<Outfit>>(
      DailyOutfitNotifier.new,
    );

class DailyOutfitNotifier extends AsyncNotifier<List<Outfit>> {
  @override
  Future<List<Outfit>> build() => _fetch();

  Future<List<Outfit>> _fetch() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return await DailyOutfitService().getDailyOutfit(today) ?? const [];
  }

  bool get _isStale =>
      (state.value?.isNotEmpty ?? false) &&
      anySignedUrlExpired(state.value!.map((o) => o.imageUrl));

  /// Re-fetches only if the list is empty or its image URLs have expired
  /// (also covers "the app was left open past midnight").
  Future<void> refreshIfNeeded() async {
    if (state.isLoading) return;
    if (!state.hasValue || state.value!.isEmpty || _isStale) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }
}
