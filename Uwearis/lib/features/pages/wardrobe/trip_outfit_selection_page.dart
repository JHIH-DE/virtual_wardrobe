import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/providers/outfits_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../data/outfit.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/overlays/error_state_widget.dart';
import '../../widgets/outfit/outfit_grid.dart';
import 'trip_outfit_version_page.dart';

/// Pick an outfit, then a version ([TripOutfitVersionPage]), to add to the
/// trip; pops with the chosen [Outfit] or null.
class TripOutfitSelectionPage extends ConsumerStatefulWidget {
  final Set<int> packedGarmentIds;
  final Set<int> addedOutfitIds;

  const TripOutfitSelectionPage({
    super.key,
    this.packedGarmentIds = const {},
    this.addedOutfitIds = const {},
  });

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
      if (!mounted) return;
      ref.listenManual(outfitsProvider, (_, next) {
        if (isSettledAuthExpiry(next) && mounted) {
          AuthExpiredHandler.handle(context);
        }
      });
      ref.read(outfitsProvider.notifier).refreshIfNeeded();
    });
  }

  Future<void> _pickVersion(Outfit outfit) async {
    final version = await Navigator.push<Outfit>(
      context,
      MaterialPageRoute(
        builder: (_) => TripOutfitVersionPage(
          outfit: outfit,
          group: groupOf(outfit, ref.read(outfitsProvider).value),
          packedGarmentIds: widget.packedGarmentIds,
          addedOutfitIds: widget.addedOutfitIds,
        ),
      ),
    );
    if (version != null && mounted) Navigator.pop(context, version);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupsAsync = ref.watch(outfitsProvider);
    final outfitsAsync = groupsAsync.whenData(outfitGroupCovers);
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
          groupNameOf: (o) => groupOf(o, groupsAsync.value)?.name,
          onRefresh: () => ref.read(outfitsProvider.notifier).refresh(),
          emptyMessage: l10n.noOutfitsYet,
          padding: AppDimens.pageGridPadding,
          onOutfitTap: _pickVersion,
        ),
      ),
    );
  }
}
