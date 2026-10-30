import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/carousel_dots_indicator.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_list_card.dart';
import '../widgets/outfit/outfit_image.dart';

/// Pops with the version on screen to add to the trip, or null. Deliberately
/// read-only (no favourite / regenerate / cover / delete).
class TripOutfitVersionPage extends ConsumerStatefulWidget {
  final Outfit outfit;
  final Set<int> packedGarmentIds;

  /// Versions already in the trip can't be added again.
  final Set<int> addedOutfitIds;

  const TripOutfitVersionPage({
    super.key,
    required this.outfit,
    this.packedGarmentIds = const {},
    this.addedOutfitIds = const {},
  });

  @override
  ConsumerState<TripOutfitVersionPage> createState() =>
      _TripOutfitVersionPageState();
}

class _TripOutfitVersionPageState extends ConsumerState<TripOutfitVersionPage> {
  // Just the tapped outfit until [_loadVersions] resolves.
  late final List<Outfit> _versions = [widget.outfit];
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  bool _versionsResolved = false;

  // A second tap during the pop transition would pop the page underneath
  // (the outfit grid) too, with this result.
  bool _popped = false;

  Outfit get _current => _versions[_currentIndex];

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(garmentsProvider.notifier).refreshIfNeeded();
      _loadVersions();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVersions() async {
    try {
      final outfits = await OutfitService().getGroupOutfits(
        widget.outfit.groupId,
      );
      if (!mounted || outfits.isEmpty) return;
      // Order isn't guaranteed; stay on the tapped version.
      final matchedIndex = outfits.indexWhere((o) => o.id == widget.outfit.id);
      setState(() {
        _versions
          ..clear()
          ..addAll(outfits);
        _currentIndex = matchedIndex >= 0 ? matchedIndex : 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      // Leave the single seed version showing.
      debugLog('Failed to load outfit versions: $e');
    } finally {
      if (mounted) setState(() => _versionsResolved = true);
    }
  }

  void _addToTrip() {
    if (_popped) return;
    _popped = true;
    Navigator.pop(context, _current);
  }

  @override
  Widget build(BuildContext context) {
    // Only garments still in the closet can be packed.
    final closetById = {
      for (final g in (ref.watch(garmentsProvider).value ?? const []).active)
        if (g.id != null) g.id!: g,
    };
    final garments = [
      for (final id in _current.garmentIds.toSet())
        if (closetById[id] != null) closetById[id]!,
    ];
    final hasUnpacked = garments.any(
      (g) => !widget.packedGarmentIds.contains(g.id),
    );
    final alreadyAdded = widget.addedOutfitIds.contains(_current.id);
    final notice = alreadyAdded
        ? _l10n.tripOutfitAlreadyAdded
        : garments.isNotEmpty && !hasUnpacked
        ? _l10n.allItemsAlreadyInSuitcase
        : null;

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: AppToolBar(title: _l10n.selectVersionTitle),
      bottomNavigationBar: _buildAddButton(enabled: !alreadyAdded),
      body: Builder(
        builder: (bodyContext) => ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            alreadyAdded
                ? 24 + MediaQuery.paddingOf(context).bottom
                : BottomActionButton.scrollClearance(bodyContext),
          ),
          children: [
            _buildVersionCarousel(),
            _buildVersionIndicator(),
            if (notice != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimens.sectionSpacing,
                ),
                child: Text(
                  notice,
                  textAlign: TextAlign.center,
                  style: AppTextStyle.medium14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            LabeledDivider(label: _l10n.garmentsCount(garments.length)),
            const SizedBox(height: AppDimens.cardHeaderGap),
            for (final g in garments)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDimens.sectionSpacing,
                ),
                child: GarmentListCard(
                  garment: g,
                  onTap: () => GarmentDetailDialog.show(context, g),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionCarousel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemCount: _versions.length,
          itemBuilder: (_, index) {
            final outfit = _versions[index];
            return OutfitImage(
              imageUrl: outfit.imageUrl,
              groupId: outfit.groupId,
              outfitId: outfit.id,
              errorLabel: _l10n.failedToLoadImage,
            );
          },
        ),
      ),
    );
  }

  Widget _buildVersionIndicator() {
    if (!_versionsResolved || _versions.length < 2) {
      return const SizedBox(height: AppDimens.sectionSpacing);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: AppDimens.sectionSpacing),
      child: CarouselDotsIndicator(
        count: _versions.length,
        currentIndex: _currentIndex,
      ),
    );
  }

  Widget _buildAddButton({required bool enabled}) {
    return BottomActionButton(
      label: _l10n.addToTrip,
      onPressed: enabled ? _addToTrip : null,
      leading: const Icon(Icons.luggage_outlined),
    );
  }
}
