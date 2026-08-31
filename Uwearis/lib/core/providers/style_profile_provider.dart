import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/style_profile.dart';
import '../services/profile_service.dart';

final styleProfileProvider =
    AsyncNotifierProvider<StyleProfileNotifier, List<StyleProfileItem>>(
      StyleProfileNotifier.new,
    );

class StyleProfileNotifier extends AsyncNotifier<List<StyleProfileItem>> {
  @override
  Future<List<StyleProfileItem>> build() =>
      ProfileService().getMyStyleProfile();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => ProfileService().getMyStyleProfile());
  }
}
