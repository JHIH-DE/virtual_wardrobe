import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/outfit.dart';
import '../../data/outfit_group.dart';
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

  // Riverpod keeps this notifier across invalidate (a sign-in) and `ref` is
  // always the newest build's: a reply to an earlier generation would land
  // in the next account's state, and its `ref.read(outfitsProvider)` would
  // read that account's outfits. Bumped on every dispose/rebuild; work from
  // another generation stops at its next await.
  int _generation = 0;

  bool _isCurrent(int generation) => generation == _generation;

  // One read loop per generation: the build's fetch, then any passes that
  // events or refresh() queued. [_loopFor] is the generation that owns the
  // running loop (an older one's neither blocks nor, finishing, frees a
  // newer one's); [_loopDone] completes when that loop ends.
  int? _loopFor;
  Completer<void>? _loopDone;

  // Bumped by garmentLinkChanges (in this generation), so a generate that
  // was refused while an outfit or version landed doesn't record that stale
  // refusal in [_insufficientFor].
  int _linkEpoch = 0;

  // outfitsProvider's candidates as last seen: completed outfits with an
  // image, id → image cache key. Only the group cards — versions change
  // through OutfitService's events instead. Null until first seen.
  Map<int, String?>? _candidates;
  // A change (or refresh()) that arrived mid-pass; that pass may have read
  // the server before it, so one more pass runs afterwards — any number of
  // them meanwhile share it.
  bool _resyncPending = false;

  /// One favorite request per outfit at a time: overlapping ones could land
  /// out of order, and a failed one's rollback would undo the other.
  final Set<int> _favoriteInFlight = {};

  @override
  Future<List<Outfit>> build() {
    final generation = _generation;
    // Re-read today's plan only for a change that can alter it: the
    // candidates (an outfit added or gone, a card re-rendered), any version
    // added / landed / deleted, or an outfit in the plan re-rendered. Not a
    // favorite, tag, name or re-signed URL — and not the outfits' first load,
    // which this build's own fetch already covers.
    _candidates = _candidatesOf(ref.read(outfitsProvider).value);
    ref.listen(outfitsProvider, (_, next) {
      if (!next.hasValue || next.isLoading) return;
      final previous = _candidates;
      final candidates = _candidatesOf(next.value)!;
      _candidates = candidates;
      if (previous != null && _planAffected(previous, candidates)) {
        _requestSync(generation);
      }
    });
    final links = OutfitService.garmentLinkChanges.listen((_) {
      if (!_isCurrent(generation)) return;
      // A new version needn't change the cards [_insufficientFor] is keyed
      // by, yet the backend's candidates grew; let generate try again.
      _linkEpoch++;
      _insufficientFor = null;
      _requestSync(generation);
    });
    final images = OutfitService.outfitImageChanges.listen((outfitId) {
      if (!_isCurrent(generation)) return;
      if (state.value?.any((o) => o.id == outfitId) ?? false) {
        _requestSync(generation);
      }
    });
    ref.onDispose(() {
      _generation++;
      _loopFor = null;
      _loopDone = null;
      _resyncPending = false;
      _linkEpoch = 0;
      _insufficientFor = null;
      _candidates = null;
      links.cancel();
      images.cancel();
    });
    // The build's fetch is the loop's first pass.
    _loopFor = generation;
    final done = _loopDone = Completer<void>();
    return _buildPass(generation, done);
  }

  Future<List<Outfit>> _buildPass(int generation, Completer<void> done) async {
    try {
      return await _fetch(generation);
    } finally {
      if (_isCurrent(generation) && _resyncPending) {
        // Queued during the build: run once its value is in state, still
        // owning the loop so nothing starts a parallel pass meanwhile.
        Future(() => _drain(generation, done));
      } else {
        if (_loopFor == generation) {
          _loopFor = null;
          _loopDone = null;
        }
        done.complete();
      }
    }
  }

  /// Today's plan, generating one if there's none. Stops (empty) as soon as
  /// [generation] is gone, so it never reads the next account's outfits or
  /// generates for it; callers drop the result then too.
  Future<List<Outfit>> _fetch(int generation) async {
    final date = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(date);
    final service = DailyOutfitService();
    final picked = await service.getDailyOutfit(today) ?? const [];
    if (!_isCurrent(generation)) return const [];
    if (picked.isNotEmpty) return picked;

    // Same candidates the backend picks from: completed outfits with a
    // try-on image.
    final outfits = outfitGroupCovers(await ref.read(outfitsProvider.future));
    if (!_isCurrent(generation)) return const [];
    final candidateIds =
        outfits
            .where((o) => o.status == 'completed' && o.imageUrl.isNotEmpty)
            .map((o) => o.id)
            .toList()
          ..sort();
    if (candidateIds.isEmpty) return const [];
    final attempt = '$today|${candidateIds.join(',')}';
    if (attempt == _insufficientFor) return const [];

    final linkEpoch = _linkEpoch;
    try {
      return await _generate(service, date, generation);
    } on AuthExpiredException {
      rethrow;
    } catch (e) {
      // Not if an outfit or version landed meanwhile: the refusal predates
      // it, and the pass that landing queued must be free to try again.
      if (_isInsufficientOutfitData(e) &&
          _isCurrent(generation) &&
          linkEpoch == _linkEpoch) {
        _insufficientFor = attempt;
      }
      debugLog('DailyOutfitNotifier: generate failed: $e');
      return const [];
    }
  }

  /// Falls back to a primary alone when too few outfits suit today.
  Future<List<Outfit>> _generate(
    DailyOutfitService service,
    DateTime date,
    int generation,
  ) async {
    try {
      return await service.generate(
        date: date,
        alternativesPerDay: alternativesPerDay,
      );
    } catch (e) {
      if (!_isInsufficientOutfitData(e)) rethrow;
      // The fallback is a second request; not for a generation that's gone.
      if (!_isCurrent(generation)) return const [];
      return await service.generate(date: date);
    }
  }

  static Map<int, String?>? _candidatesOf(List<OutfitGroup>? groups) =>
      groups == null
      ? null
      : {
          for (final o in outfitGroupCovers(groups))
            if (o.status == 'completed' && o.imageUrl.isNotEmpty)
              o.id: o.resultImageCacheKey,
        };

  /// Whether a candidates change can alter today's plan as read back: with
  /// a plan, only an outfit in it gone or re-rendered (new outfits don't
  /// change a day already picked); without one (or not known yet), any
  /// change, as it may now be enough to generate.
  bool _planAffected(Map<int, String?> before, Map<int, String?> after) {
    if (_sameCandidates(before, after)) return false;
    final plan = state.value;
    if (plan == null || plan.isEmpty) return true;
    return plan.any(
      (o) =>
          before.containsKey(o.id) &&
          (!after.containsKey(o.id) || after[o.id] != before[o.id]),
    );
  }

  static bool _sameCandidates(Map<int, String?> a, Map<int, String?> b) =>
      a.length == b.length &&
      a.entries.every((e) => b.containsKey(e.key) && b[e.key] == e.value);

  static bool _isInsufficientOutfitData(Object e) =>
      e is ApiException && e.errorCode == 'INSUFFICIENT_OUTFIT_DATA';

  /// Queues a pass of the read loop (see [build] for what triggers one): it
  /// starts one, or — while one is running — has it run one more pass,
  /// shared by every request meanwhile. Completes when the loop ends. Reads
  /// in place: only [refresh] shows loading (it would swap Home's carousel
  /// for its fallback).
  Future<void> _requestSync(int generation) {
    if (!_isCurrent(generation)) return Future.value();
    _resyncPending = true;
    final running = _loopDone;
    if (_loopFor == generation && running != null) return running.future;
    _loopFor = generation;
    final done = _loopDone = Completer<void>();
    _drain(generation, done);
    return done.future;
  }

  /// Runs passes while one is pending. A pass's answer is written only if
  /// nothing was queued during it: a queued pass follows and is newer.
  Future<void> _drain(int generation, Completer<void> done) async {
    try {
      while (_resyncPending && _isCurrent(generation)) {
        _resyncPending = false;
        final next = await AsyncValue.guard(() => _fetch(generation));
        if (!_isCurrent(generation)) return;
        if (!_resyncPending) state = next;
      }
    } finally {
      if (_loopFor == generation) {
        _loopFor = null;
        _loopDone = null;
      }
      done.complete();
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

  /// Shows loading, then re-reads through the same loop as events (joining
  /// it if one is running). Completes when that loop ends, so with any
  /// change notified before then already applied.
  Future<void> refresh() {
    state = const AsyncLoading();
    return _requestSync(_generation);
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
    if (!_favoriteInFlight.add(target.id)) return;
    final generation = _generation;
    final next = target.copyWith(isFavorite: !target.isFavorite);
    final outfits = ref.read(outfitsProvider.notifier);
    updateOutfit(next);
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        isFavorite: next.isFavorite,
      );
      outfits.updateOutfitFavorite(target.id, isFavorite: next.isFavorite);
    } catch (_) {
      if (_isCurrent(generation)) updateOutfit(target);
      rethrow;
    } finally {
      _favoriteInFlight.remove(target.id);
    }
  }

  /// Optimistic tag update for Today's Outfit's tag sheet; syncs
  /// [outfitsProvider] once saved. A null [temperature] leaves it as is.
  /// Rolls back and rethrows on failure.
  Future<void> updateOutfitTags(
    Outfit target, {
    required List<String> style,
    OutfitTemperatureEdit? temperature,
  }) async {
    final generation = _generation;
    final updated = target.copyWith(
      style: style,
      suitableTemperature: optimisticOutfitTemperature(target, temperature),
    );
    final outfits = ref.read(outfitsProvider.notifier);
    updateOutfit(updated);
    try {
      final saved = await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        style: style,
        suitableTemperature: temperature,
      );
      // Going back to automatic is only known from the reply.
      final settled = updated.copyWith(
        suitableTemperature: saved.suitableTemperature,
      );
      if (_isCurrent(generation)) updateOutfit(settled);
      outfits.updateOutfitTags(
        target.id,
        style: style,
        suitableTemperature: settled.suitableTemperature,
      );
    } catch (_) {
      if (_isCurrent(generation)) updateOutfit(target);
      rethrow;
    }
  }
}
