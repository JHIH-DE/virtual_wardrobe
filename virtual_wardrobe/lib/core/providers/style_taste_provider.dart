import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/style_taste.dart';
import '../services/style_taste_service.dart';

final styleTastePreferencesProvider =
    AsyncNotifierProvider<
      StyleTastePreferencesNotifier,
      List<StyleTastePreference>
    >(StyleTastePreferencesNotifier.new);

class StyleTastePreferencesNotifier
    extends AsyncNotifier<List<StyleTastePreference>> {
  @override
  Future<List<StyleTastePreference>> build() =>
      StyleTasteService().getPreferences();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => StyleTasteService().getPreferences());
  }
}

final styleTastePersonalitySummaryProvider =
    AsyncNotifierProvider<StyleTastePersonalitySummaryNotifier, String>(
      StyleTastePersonalitySummaryNotifier.new,
    );

class StyleTastePersonalitySummaryNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() => StyleTasteService().getPersonalitySummary();
}
