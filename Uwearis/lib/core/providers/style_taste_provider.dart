import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/style_taste.dart';
import '../services/profile_service.dart';
import 'retry_policy.dart';

final styleTasteProfileProvider =
    AsyncNotifierProvider<StyleTasteProfileNotifier, StyleTasteProfile>(
      StyleTasteProfileNotifier.new,
      retry: appRetryPolicy,
    );

class StyleTasteProfileNotifier extends AsyncNotifier<StyleTasteProfile> {
  // Riverpod keeps this notifier across invalidate (a sign-in), so a refresh
  // from an earlier build — maybe the previous account's — is told apart by
  // this, bumped when a build is disposed.
  int _generation = 0;

  @override
  Future<StyleTasteProfile> build() {
    ref.onDispose(() => _generation++);
    return _fetch();
  }

  Future<void> refresh() async {
    final generation = _generation;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(_fetch);
    if (generation == _generation) state = next;
  }

  Future<StyleTasteProfile> _fetch() => ProfileService().getMyStyleTaste();
}
