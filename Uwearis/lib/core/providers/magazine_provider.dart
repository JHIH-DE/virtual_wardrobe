import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/magazine.dart';
import '../services/magazine_service.dart';
import 'locale_provider.dart';
import 'retry_policy.dart';

/// Explore's home: the latest issue for one backend locale and audience.
/// The texts follow the profile's `locale`, pushed first (as
/// `backgroundsProvider`). Reset by `invalidateSignedInProviders`.
final magazineHomeProvider =
    FutureProvider.family<
      MagazineHome,
      ({String apiLocale, MagazineAudience audience})
    >((ref, key) async {
      await ref
          .read(localeProvider.notifier)
          .ensureBackendLocale(key.apiLocale);
      return MagazineService().getHome(audience: key.audience);
    }, retry: appRetryPolicy);

/// One published story, while its page is open.
final magazineStoryProvider = FutureProvider.autoDispose
    .family<MagazineStory, ({String apiLocale, int storyId})>((ref, key) async {
      await ref
          .read(localeProvider.notifier)
          .ensureBackendLocale(key.apiLocale);
      return MagazineService().getStory(key.storyId);
    }, retry: appRetryPolicy);

FutureProvider<MagazineHome> magazineHomeFor(
  BuildContext context,
  MagazineAudience audience,
) => magazineHomeProvider((
  apiLocale: LocaleNotifier.apiLocaleFor(Localizations.localeOf(context)),
  audience: audience,
));
