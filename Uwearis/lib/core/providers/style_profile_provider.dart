import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/style_profile.dart';
import '../services/profile_service.dart';
import 'retry_policy.dart';

final styleProfileProvider =
    AsyncNotifierProvider<StyleProfileNotifier, List<StyleProfileItem>>(
      StyleProfileNotifier.new,
      retry: appRetryPolicy,
    );

class StyleProfileNotifier extends AsyncNotifier<List<StyleProfileItem>> {
  // Riverpod keeps this notifier across invalidate (a sign-in), so a refresh
  // from an earlier build — maybe the previous account's — is told apart by
  // this, bumped when a build is disposed.
  int _generation = 0;

  @override
  Future<List<StyleProfileItem>> build() {
    ref.onDispose(() => _generation++);
    return ProfileService().getMyStyleProfile();
  }

  Future<void> refresh() async {
    final generation = _generation;
    state = const AsyncLoading();
    final next = await AsyncValue.guard(
      () => ProfileService().getMyStyleProfile(),
    );
    if (generation == _generation) state = next;
  }
}
