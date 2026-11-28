import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/magazine_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/utils/external_links.dart';
import '../../../data/magazine.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/overlays/error_state_widget.dart';
import '../../widgets/magazine/magazine_story_view.dart';

/// One magazine story, opened from Explore's carousel.
class MagazineStoryPage extends ConsumerWidget {
  final int storyId;

  /// Shown in the toolbar while the story loads.
  final String? title;

  const MagazineStoryPage({super.key, required this.storyId, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = magazineStoryProvider((
      apiLocale: LocaleNotifier.apiLocaleFor(Localizations.localeOf(context)),
      storyId: storyId,
    ));
    ref.listen(provider, (_, next) {
      if (isSettledAuthExpiry(next)) AuthExpiredHandler.handle(context);
    });
    final story = ref.watch(provider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(
        title: story.value?.summary.title ?? title ?? l10n.explore,
      ),
      body: story.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: AppSpinner()),
        error: (error, _) => ErrorStateWidget(
          error: error,
          onRetry: () => ref.invalidate(provider),
        ),
        data: (story) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            AppDimens.sectionSpacing + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            MagazineStoryView(
              story: story,
              onShopItem: (item) => _openProduct(context, item),
              onOpenSource: (url) => openMagazineSource(context, url),
            ),
          ],
        ),
      ),
    );
  }

  void _openProduct(BuildContext context, MagazineItem item) {
    final url = item.product?.productUrl;
    if (url != null) openProductPage(context, url);
  }
}
