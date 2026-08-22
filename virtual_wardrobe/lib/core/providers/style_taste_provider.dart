import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/style_taste.dart';
import '../services/profile_service.dart';

final styleTasteProfileProvider =
    AsyncNotifierProvider<StyleTasteProfileNotifier, StyleTasteProfile>(
      StyleTasteProfileNotifier.new,
    );

class StyleTasteProfileNotifier extends AsyncNotifier<StyleTasteProfile> {
  @override
  Future<StyleTasteProfile> build() => _fetch();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<StyleTasteProfile> _fetch() async {
    final data = await ProfileService().getMyStyleTaste();
    return StyleTasteProfile.fromApi(data);
  }
}
