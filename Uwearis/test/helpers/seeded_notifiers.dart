import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uwearis/core/providers/daily_outfit_provider.dart';
import 'package:uwearis/core/providers/garments_provider.dart';
import 'package:uwearis/core/providers/outfits_provider.dart';
import 'package:uwearis/core/providers/trips_provider.dart';
import 'package:uwearis/data/garment.dart';
import 'package:uwearis/data/outfit.dart';
import 'package:uwearis/data/trip.dart';

// Provider fakes whose build() serves a fixed list instead of fetching:
// `garmentsProvider.overrideWith(() => SeededGarmentsNotifier(closet))`.
// Everything else — mutations, refreshIfNeeded — is the real notifier's.
// A fake that delays, fails, counts calls or stubs another method stays in
// its own test file.

/// [refreshReseeds]: `refresh()` puts [seed] back without fetching. Off,
/// `refresh()` is the real one, which fetches.
class SeededGarmentsNotifier extends GarmentsNotifier {
  SeededGarmentsNotifier(this.seed, {this.refreshReseeds = false});

  final List<Garment> seed;
  final bool refreshReseeds;

  @override
  Future<List<Garment>> build() async => seed;

  @override
  Future<void> refresh() => refreshReseeds ? _reseed() : super.refresh();

  Future<void> _reseed() async => state = AsyncData(seed);
}

/// See [SeededGarmentsNotifier] for [refreshReseeds].
class SeededOutfitsNotifier extends OutfitsNotifier {
  SeededOutfitsNotifier(this.seed, {this.refreshReseeds = false});

  final List<Outfit> seed;
  final bool refreshReseeds;

  @override
  Future<List<Outfit>> build() async => seed;

  @override
  Future<void> refresh() => refreshReseeds ? _reseed() : super.refresh();

  Future<void> _reseed() async => state = AsyncData(seed);
}

class SeededDailyOutfitNotifier extends DailyOutfitNotifier {
  SeededDailyOutfitNotifier(this.seed);

  final List<Outfit> seed;

  @override
  Future<List<Outfit>> build() async => seed;
}

class SeededTripsNotifier extends TripsNotifier {
  SeededTripsNotifier(this.seed);

  final List<Trip> seed;

  @override
  Future<List<Trip>> build() async => seed;
}
