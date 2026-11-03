import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../utils/debug_log.dart';

/// How a pending try-on can be checked on relaunch.
enum PendingTryOnKind {
  /// Sent with an Idempotency-Key: `GET /outfit/generations/{key}`
  /// (Create Outfit, Outfit Details' regenerate).
  keyed,

  /// A trip outfit's try-on. Its endpoint takes no key, so the only check is
  /// whether that trip outfit's image has changed since ([imageMarker]).
  trip,
}

/// A try-on whose outcome the app hasn't learned yet, so a relaunch can
/// still find out (see `recoverPendingTryOns`). Holds only random keys and
/// ids — nothing that identifies the user.
class PendingTryOn {
  final String key;
  final PendingTryOnKind kind;

  /// The draft group created for a new outfit; null when adding a version
  /// to an existing group, and for the other kinds.
  final int? draftGroupId;

  /// A regenerate's target, whose cached image must be refreshed once the
  /// new one lands.
  final int? regeneratedOutfitId;

  final int? tripId;
  final int? tripOutfitId;

  /// The trip outfit's image before the try-on (`tripOutfitImageMarker`).
  final String? imageMarker;
  final DateTime startedAt;

  const PendingTryOn({
    required this.key,
    this.kind = PendingTryOnKind.keyed,
    this.draftGroupId,
    this.regeneratedOutfitId,
    this.tripId,
    this.tripOutfitId,
    this.imageMarker,
    required this.startedAt,
  });

  Map<String, dynamic> toJson() => {
    'key': key,
    'kind': kind.name,
    'draft_group_id': draftGroupId,
    'regenerated_outfit_id': regeneratedOutfitId,
    'trip_id': tripId,
    'trip_outfit_id': tripOutfitId,
    'image_marker': imageMarker,
    'started_at': startedAt.toIso8601String(),
  };

  /// Entries written before [kind] existed are keyed generates.
  static PendingTryOn? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final key = json['key'];
    final startedAt = DateTime.tryParse(json['started_at'] as String? ?? '');
    if (key is! String || startedAt == null) return null;
    final kind = PendingTryOnKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => PendingTryOnKind.keyed,
    );
    int? id(String field) => (json[field] as num?)?.toInt();
    return PendingTryOn(
      key: key,
      kind: kind,
      draftGroupId: id('draft_group_id'),
      regeneratedOutfitId: id('regenerated_outfit_id'),
      tripId: id('trip_id'),
      tripOutfitId: id('trip_outfit_id'),
      imageMarker: json['image_marker'] as String?,
      startedAt: startedAt,
    );
  }
}

/// SharedPreferences-backed; cleared at session end, since keys aren't
/// scoped by user locally. [session] changes at every [clear], so work that
/// started for one account can tell, when it finishes, that the account is
/// gone — and a write that started before a sign-out is dropped instead of
/// putting the old account's entries back.
class PendingTryOnStore {
  static const _prefsKey = 'pending_try_ons';

  /// Long past the backend's lease (240s): by then the outcome is settled,
  /// and an entry this old can only be dropped, never acted on.
  static const maxAge = Duration(minutes: 30);

  static int _session = 0;
  static int get session => _session;

  // Keys this process is still waiting on: recovery leaves them to their
  // own request instead of racing it.
  static final Set<String> _inFlight = {};

  static void markInFlight(String key) => _inFlight.add(key);
  static void unmarkInFlight(String key) => _inFlight.remove(key);
  static bool isInFlight(String key) => _inFlight.contains(key);

  static Future<List<PendingTryOn>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map(PendingTryOn.fromJson)
          .whereType<PendingTryOn>()
          .toList();
    } catch (e) {
      debugLog('PendingTryOnStore.load failed: $e');
      return const [];
    }
  }

  /// No-op unless [forSession] is still the current [session].
  static Future<void> add(
    PendingTryOn pending, {
    required int forSession,
  }) async {
    if (forSession != _session) return;
    final all = [
      for (final p in await load())
        if (p.key != pending.key) p,
      pending,
    ];
    await _write(all, forSession);
  }

  /// No-op unless [forSession] is still the current [session].
  static Future<void> remove(String key, {required int forSession}) async {
    if (forSession != _session) return;
    final all = await load();
    if (!all.any((p) => p.key == key)) return;
    await _write(all.where((p) => p.key != key).toList(), forSession);
  }

  static Future<void> clear() async {
    _session++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (e) {
      debugLog('PendingTryOnStore.clear failed: $e');
    }
  }

  static Future<void> _write(List<PendingTryOn> all, int forSession) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // The list was read before the await; a sign-out since then wins.
      if (forSession != _session) return;
      if (all.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(
          _prefsKey,
          jsonEncode(all.map((p) => p.toJson()).toList()),
        );
      }
    } catch (e) {
      // Losing an entry only loses the relaunch check, never a result.
      debugLog('PendingTryOnStore write failed: $e');
    }
  }
}
