import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/background_option.dart';
import '../services/background_service.dart';
import 'locale_provider.dart';
import 'retry_policy.dart';

/// The try-on backgrounds for one backend locale ([LocaleNotifier.apiLocaleFor]
/// of the displayed one), kept until the app restarts (they rarely change).
/// Their `label`s follow the profile's `locale`, which is pushed first — same
/// as `adjustmentOptionsProvider`, so a language switch fetches names in the
/// new language. Reset by `invalidateSignedInProviders`, so a load that failed
/// under an earlier session isn't kept.
final backgroundsProvider =
    FutureProvider.family<List<BackgroundOption>, String>((
      ref,
      apiLocale,
    ) async {
      await ref.read(localeProvider.notifier).ensureBackendLocale(apiLocale);
      return BackgroundService().getBackgrounds();
    }, retry: appRetryPolicy);

/// [backgroundsProvider] for the locale [context] displays.
FutureProvider<List<BackgroundOption>> backgroundsFor(BuildContext context) =>
    backgroundsProvider(
      LocaleNotifier.apiLocaleFor(Localizations.localeOf(context)),
    );
