import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/garment_sub_category.dart';
import '../services/garment_service.dart';
import 'locale_provider.dart';
import 'retry_policy.dart';

/// Which sub-category lists: [locale] is the backend locale
/// ([LocaleNotifier.apiLocaleFor] of the displayed one); [allGenders] picks
/// the full lists (labels) over the gender-filtered ones (the picker).
typedef SubCategoryCatalogKey = ({String locale, bool allGenders});

/// Labelled by the profile's `locale`, which is pushed first — same as
/// `adjustmentOptionsProvider`. Reset per account by
/// `invalidateSignedInProviders`, and on a gender change by Personal
/// Details (the picker lists depend on it).
final subCategoryCatalogProvider =
    FutureProvider.family<SubCategoryCatalog, SubCategoryCatalogKey>((
      ref,
      key,
    ) async {
      await ref.read(localeProvider.notifier).ensureBackendLocale(key.locale);
      return GarmentService().getSubCategories(allGenders: key.allGenders);
    }, retry: appRetryPolicy);

/// [subCategoryCatalogProvider] for the locale [context] displays: the
/// gender-filtered lists, or every value with [allGenders].
FutureProvider<SubCategoryCatalog> subCategoryCatalogFor(
  BuildContext context, {
  bool allGenders = false,
}) => subCategoryCatalogProvider((
  locale: LocaleNotifier.apiLocaleFor(Localizations.localeOf(context)),
  allGenders: allGenders,
));

/// A sub-category's display label, for `build`. Uses the full lists — a
/// garment may hold a value the user's picker doesn't offer (a skirt in a
/// `Male` closet). Shows the stored value while they load or when they
/// fail — a label is never worth an error state.
String Function(String value) watchSubCategoryLabel(
  WidgetRef ref,
  BuildContext context,
) {
  final catalog = ref
      .watch(subCategoryCatalogFor(context, allGenders: true))
      .value;
  return (value) => catalog?.labelFor(value) ?? value;
}

/// Like [watchSubCategoryLabel], but looks the lists up only when the
/// returned function runs (a filter sheet opening), so a screen that's built
/// at launch and may never show a label doesn't fetch them. Until they've
/// loaded it shows the stored value.
String Function(String value) readSubCategoryLabel(
  WidgetRef ref,
  BuildContext context,
) {
  final provider = subCategoryCatalogFor(context, allGenders: true);
  return (value) => ref.read(provider).value?.labelFor(value) ?? value;
}
