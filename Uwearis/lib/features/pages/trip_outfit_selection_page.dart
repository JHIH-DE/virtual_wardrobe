import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/outfit/outfit_grid.dart';

/// Lets the user pick one of their saved outfits, so its garments can be
/// added to a trip's suitcase in one go — pops with the chosen [Outfit], or
/// null if dismissed without picking one.
///
/// The list is the same "standalone try-ons" the Outfits tab shows, so this
/// reads [outfitsProvider] rather than fetching its own copy.
class TripOutfitSelectionPage extends ConsumerStatefulWidget {
  const TripOutfitSelectionPage({super.key});

  @override
  ConsumerState<TripOutfitSelectionPage> createState() =>
      _TripOutfitSelectionPageState();
}

class _TripOutfitSelectionPageState
    extends ConsumerState<TripOutfitSelectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(outfitsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException && mounted) {
          AuthExpiredHandler.handle(context);
        }
      });
      ref.read(outfitsProvider.notifier).refreshIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outfitsAsync = ref.watch(outfitsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(title: l10n.selectAnOutfitTitle),
      body: outfitsAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => ErrorStateWidget(
          error: e,
          onRetry: () => ref.read(outfitsProvider.notifier).refresh(),
        ),
        data: (outfits) => OutfitGrid(
          outfits: outfits,
          onRefresh: () => ref.read(outfitsProvider.notifier).refresh(),
          emptyMessage: l10n.noOutfitsYet,
          padding: AppDimens.pageGridPadding,
          onOutfitTap: (outfit) => Navigator.pop(context, outfit),
        ),
      ),
    );
  }
}
