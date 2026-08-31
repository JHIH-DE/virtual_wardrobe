import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/outfit_service.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/outfit/outfit_card.dart';

/// Lets the user pick which `type: general` outfit group [sourceOutfit]
/// gets copied into (see [OutfitService.copyOutfit]) — an existing group
/// (added there as another version) or a brand new one. Pops the newly
/// copied [Outfit] on success, or null if the user backs out.
class SelectOutfitGroupPage extends ConsumerStatefulWidget {
  final Outfit sourceOutfit;

  const SelectOutfitGroupPage({super.key, required this.sourceOutfit});

  @override
  ConsumerState<SelectOutfitGroupPage> createState() =>
      _SelectOutfitGroupPageState();
}

class _SelectOutfitGroupPageState
    extends ConsumerState<SelectOutfitGroupPage> {
  bool _isCopying = false;

  /// Pass null to create a fresh group instead of copying into an existing
  /// one — see [OutfitService.copyOutfit]'s own groupId-omitted behavior.
  Future<void> _copyInto(int? groupId) async {
    if (_isCopying) return;
    setState(() => _isCopying = true);
    try {
      final outfit = await OutfitService().copyOutfit(
        groupId: groupId,
        sourceOutfitId: widget.sourceOutfit.id,
      );
      if (!mounted) return;
      await ref.read(outfitsProvider.notifier).refresh();
      if (!mounted) return;
      Navigator.pop(context, outfit);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outfitsAsync = ref.watch(outfitsProvider);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppToolBar(title: l10n.selectOutfitGroupTitle),
          body: outfitsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => ErrorStateWidget(
              error: e,
              onRetry: () => ref.read(outfitsProvider.notifier).refresh(),
            ),
            data: (groups) => _buildGrid(groups),
          ),
        ),
        if (_isCopying) Positioned.fill(child: LoadingOverlay(label: l10n.loading)),
      ],
    );
  }

  Widget _buildGrid(List<Outfit> groups) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimens.cardSpacing,
        mainAxisSpacing: AppDimens.cardSpacing,
        mainAxisExtent: AppDimens.outfitCardHeight,
      ),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildNewGroupCard();
        final outfit = groups[index - 1];
        return OutfitCard(
          outfit: outfit,
          onTap: () => _copyInto(outfit.groupId),
        );
      },
    );
  }

  Widget _buildNewGroupCard() {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () => _copyInto(null),
      child: SizedBox(
        height: AppDimens.outfitCardHeight,
        child: CustomPaint(
          painter: const DashedBorderPainter(
            color: AppColors.borderStrong,
            radius: AppDimens.cardRadius,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add, size: 32, color: AppColors.icon),
                const SizedBox(height: 8),
                Text(
                  l10n.newOutfitGroup,
                  style: AppTextStyle.bold14,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
