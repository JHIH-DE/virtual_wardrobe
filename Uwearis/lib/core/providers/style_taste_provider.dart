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
  @override
  Future<StyleTasteProfile> build() => _fetch();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<StyleTasteProfile> _fetch() => ProfileService().getMyStyleTaste();
}
