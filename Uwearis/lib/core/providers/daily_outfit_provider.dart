import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/outfit.dart';
import '../services/api_exception.dart';
import '../services/auth_handler.dart';
import '../services/daily_outfit_service.dart';
import '../utils/debug_log.dart';
import '../utils/signed_url.dart';
import 'outfits_provider.dart';
import 'retry_policy.dart';

/// Today's daily outfit options — a primary plus up to
/// [DailyOutfitNotifier.alternativesPerDay] alternatives, each one of the
/// user's own outfits. Nothing picks a plan in the background any more, so
/// a day with no plan yet gets one generated here on first read; empty
/// means the backend couldn't find enough suitable outfits (or the user has
/// none yet).
final dailyOutfitProvider =
    AsyncNotifierProvider<DailyOutfitNotifier, List<Outfit>>(
      DailyOutfitNotifier.new,
      retry: appRetryPolicy,
    );

class DailyOutfitNotifier extends AsyncNotifier<List<Outfit>> {
  static const alternativesPerDay = 2;

  /// The day + candidate outfit set the last generate came up short for
  /// (`INSUFFICIENT_OUTFIT_DATA`). Retrying with the same inputs can't
  /// succeed, so [_fetch] skips generating until the day or the user's
  /// outfits change.
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

  /// Asks for a primary plus [alternativesPerDay] alternatives, settling
  /// for a primary alone when today's weather leaves too few suitable
  /// outfits for that.
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

  /// Today's options are the user's own outfits, so any change to
  /// [outfitsProvider] (a delete, re-render, favorite, a new outfit that
  /// makes a plan possible) re-reads them. Done in place rather than via
  /// [refresh] — most changes don't affect today's plan, and flipping to
  /// loading would swap Home's carousel out for its fallback meanwhile.
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

  void updateOutfit(Outfit outfit) {
    final current = state.value ?? [];
    state = AsyncData(
      current.map((o) => o.id == outfit.id ? outfit : o).toList(),
    );
  }
}
