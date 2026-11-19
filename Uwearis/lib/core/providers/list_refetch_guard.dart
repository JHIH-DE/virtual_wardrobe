import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps a list provider's re-fetch from undoing what happened while it was
/// in flight. Its reply reflects the server when the request arrived, so it
/// can lack a local edit committed meanwhile, lose to a newer fetch, or —
/// after a rebuild (the next sign-in) — belong to the previous account.
///
/// Riverpod keeps the notifier across invalidate and `ref` is always the
/// newest build's, so `ref.mounted` can't tell those apart; [reset] (from
/// `ref.onDispose`) starts a new generation instead.
class ListRefetchGuard<T> {
  int _generation = 0;
  int _fetchesStarted = 0;
  int _fetchApplied = 0;

  /// The fetches of this generation still waiting for a reply, by order.
  final Set<int> _inFlight = {};

  /// Local edits made since the oldest fetch in flight started, replayed
  /// onto each fetch's reply. Each must be idempotent.
  final List<List<T> Function(List<T>)> _edits = [];

  /// Call from `ref.onDispose` in `build`.
  void reset() {
    _generation++;
    _inFlight.clear();
    _edits.clear();
  }

  /// Applies [edit] to [current], remembering it for the fetches in flight.
  List<T> edit(List<T> current, List<T> Function(List<T>) edit) {
    if (_inFlight.isNotEmpty) _edits.add(edit);
    return edit(current);
  }

  /// For `build`: [fetch]'s reply with the edits made meanwhile re-applied,
  /// or null when it must be dropped. A failure is rethrown (so the
  /// provider's retry policy applies) unless it would be dropped.
  Future<List<T>?> load(Future<List<T>> Function() fetch) async =>
      (await _run(fetch))?.items;

  /// For `refresh()`: reports each state through [setState] — loading, then
  /// the reply, or its error. Shows a reply that a newer refresh still in
  /// flight will follow, but stays loading until that one answers; an error
  /// that newer refresh can still replace isn't shown at all. Completes
  /// when this refresh's own request has.
  Future<void> refresh(
    Future<List<T>> Function() fetch,
    void Function(AsyncValue<List<T>> state) setState,
  ) async {
    setState(const AsyncLoading());
    try {
      final result = await _run(fetch);
      if (result == null) return;
      setState(AsyncData(result.items));
      // Riverpod keeps the value just set across this loading state.
      if (result.newerInFlight) setState(const AsyncLoading());
    } catch (e, stack) {
      setState(AsyncError(e, stack));
    }
  }

  Future<({List<T> items, bool newerInFlight})?> _run(
    Future<List<T>> Function() fetch,
  ) async {
    final generation = _generation;
    final order = ++_fetchesStarted;
    final editsBefore = _edits.length;
    _inFlight.add(order);
    bool isCurrent() => generation == _generation && order > _fetchApplied;
    bool newerInFlight() => _inFlight.any((o) => o > order);
    try {
      final fresh = await fetch();
      if (!isCurrent()) return null;
      _fetchApplied = order;
      return (
        items: _edits.skip(editsBefore).fold<List<T>>(fresh, (l, e) => e(l)),
        newerInFlight: newerInFlight(),
      );
    } catch (_) {
      if (!isCurrent() || newerInFlight()) return null;
      rethrow;
    } finally {
      if (generation == _generation) {
        _inFlight.remove(order);
        if (_inFlight.isEmpty) _edits.clear();
      }
    }
  }
}
