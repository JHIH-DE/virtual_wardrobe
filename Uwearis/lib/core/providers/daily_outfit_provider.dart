import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/outfit.dart';
import '../services/api_exception.dart';
import '../services/auth_handler.dart';
import '../services/daily_outfit_service.dart';
import '../services/outfit_service.dart';
import '../utils/debug_log.dart';
import '../utils/signed_url.dart';
import 'outfits_provider.dart';
import 'retry_policy.dart';

/// Today's daily outfit options: a primary plus up to
/// [DailyOutfitNotifier.alternativesPerDay] of the user's own outfits.
/// A day with no plan gets one generated on first read; empty means too few
/// suitable outfits.
final dailyOutfitProvider =
    AsyncNotifierProvider<DailyOutfitNotifier, List<Outfit>>(
      DailyOutfitNotifier.new,
      retry: appRetryPolicy,
    );

class DailyOutfitNotifier extends AsyncNotifier<List<Outfit>> {
  static const alternativesPerDay = 2;

  /// Day + candidate set the last generate got `INSUFFICIENT_OUTFIT_DATA`
  /// for; retrying the same inputs can't succeed, so [_fetch] skips it.
  String? _insufficientFor;
  bool _syncing = false;

  @override
  Future<List<Outfit>> build() {
    ref.listen(outfitsProvider, (_, next) {
      if (next.hasValue && !next.isLoading) _syncWithOutfits();
    });
    return _fetch();
  }

  Future<List<Outfit>> _fetch() async {
    final date = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(date);
    final service = DailyOutfitService();
    final picked = await service.getDailyOutfit(today) ?? const [];
    if (picked.isNotEmpty) return picked;

    // Same candidates the backend picks from: completed outfits with a
    // try-on image.
    final outfits = await ref.read(outfitsProvider.future);
    final candidateIds =
        outfits
            .where((o) => o.status == 'completed' && o.imageUrl.isNotEmpty)
            .map((o) => o.id)
            .toList()
          ..sort();
    if (candidateIds.isEmpty) return const [];
    final attempt = '$today|${candidateIds.join(',')}';
    if (attempt == _insufficientFor) return const [];

    try {
      return await _generate(service, date);
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
      if (_isInsufficientOutfitData(e)) _insufficientFor = attempt;
      debugLog('DailyOutfitNotifier: generate failed: $e');
      return const [];
    }
  }

  /// Falls back to a primary alone when too few outfits suit today.
  Future<List<Outfit>> _generate(
    DailyOutfitService service,
    DateTime date,
  ) async {
    try {
      return await service.generate(
        date: date,
        alternativesPerDay: alternativesPerDay,
      );
    } catch (e) {
      if (!_isInsufficientOutfitData(e)) rethrow;
      return await service.generate(date: date);
    }
  }

  static bool _isInsufficientOutfitData(Object e) =>
      e is ApiException && e.errorCode == 'INSUFFICIENT_OUTFIT_DATA';

  /// Re-reads in place on any [outfitsProvider] change. Not via [refresh]:
  /// flipping to loading would swap Home's carousel for its fallback.
  Future<void> _syncWithOutfits() async {
    if (state.isLoading || _syncing) return;
    _syncing = true;
    try {
      state = await AsyncValue.guard(_fetch);
    } finally {
      _syncing = false;
    }
  }

  bool get _isStale =>
      (state.value?.isNotEmpty ?? false) &&
      anySignedUrlExpired(state.value!.map((o) => o.imageUrl));

  /// Re-fetches only if the list is empty or its image URLs have expired.
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

  void updateOutfit(Outfit outfit) {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((o) => o.id == outfit.id ? outfit : o).toList(),
    );
  }

  /// Optimistic favorite toggle shared by Home and Today's Outfit. Rolls
  /// back and rethrows on failure; the caller owns the error UI.
  Future<void> toggleOutfitFavorite(Outfit target) async {
    final next = target.copyWith(isFavorite: !target.isFavorite);
    final outfits = ref.read(outfitsProvider.notifier);
    updateOutfit(next);
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        isFavorite: next.isFavorite,
      );
      outfits.updateOutfit(next);
    } catch (_) {
      updateOutfit(target);
      rethrow;
    }
  }
}
