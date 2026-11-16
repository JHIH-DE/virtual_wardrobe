import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/garment_adjustment.dart';
import '../services/outfit_service.dart';
import 'locale_provider.dart';
import 'retry_policy.dart';

/// Try-on adjustment definitions keyed by `key`, for one backend locale
/// ([LocaleNotifier.apiLocaleFor] of the displayed locale — so a device
/// language change re-fetches too). The backend labels by the profile's
/// `locale`, which is pushed first. Per account: reset by
/// `invalidateSignedInProviders`.
final adjustmentOptionsProvider =
    FutureProvider.family<Map<String, AdjustmentDefinition>, String>((
      ref,
      apiLocale,
    ) async {
      await ref.read(localeProvider.notifier).ensureBackendLocale(apiLocale);
      final definitions = await OutfitService().getAdjustmentOptions();
      return {
        for (final d in definitions)
          d.key: d.withoutCodes(hiddenAdjustmentCodes[d.key] ?? const {}),
      };
    }, retry: appRetryPolicy);
