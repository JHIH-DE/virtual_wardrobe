import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/daily_outfit_provider.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/outfit_garments.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/carousel_dots_indicator.dart';
import '../widgets/common/images/fullscreen_image_viewer.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/outfit/outfit_garment_section.dart';
import '../widgets/outfit/outfit_image.dart';
import '../widgets/outfit/outfit_tag_row.dart';
import '../widgets/outfit/outfit_tags_sheet.dart';
import '../widgets/outfit/outfit_title.dart';
import 'outfit_details_page.dart';

/// Swipes between today's daily outfit options (not one group's versions
/// like [OutfitDetailsPage]). Read-only apart from the favorite heart.
class TodayOutfitPage extends ConsumerStatefulWidget {
  final int initialIndex;

  /// Lets Home keep its own carousel on the same option.
  final ValueChanged<int>? onIndexChanged;

  const TodayOutfitPage({
    super.key,
    this.initialIndex = 0,
    this.onIndexChanged,
  });

  @override
  ConsumerState<TodayOutfitPage> createState() => _TodayOutfitPageState();
}

class _TodayOutfitPageState extends ConsumerState<TodayOutfitPage> {
  late int _currentIndex = widget.initialIndex;
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );

  // Keyed by outfit id, so swiping back doesn't re-fetch.
  final Map<int, List<Garment>> _garmentsByOutfitId = {};
  final Set<int> _loadingGarmentsFor = {};
  bool _isSavingTags = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(dailyOutfitProvider).value ?? const <Outfit>[];
    final current = options.isEmpty
        ? null
        : options[_currentIndex.clamp(0, options.length - 1)];
    // No-op once this option's garments are loaded or loading.
    if (current != null) _loadGarments(current);

    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: AppToolBar(title: _l10n.todaysOutfit),
      body: current == null
          ? const SizedBox.shrink()
          : Builder(
              builder: (bodyContext) => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  BottomActionButton.scrollClearance(bodyContext),
                ),
                children: [
                  Text(_titleFor(current), style: AppTextStyle.bold20),
                  const SizedBox(height: 8),
                  OutfitTagsHeader(
                    seasons: current.seasons,
                    style: current.style,
                    onEdit: _isSavingTags ? null : () => _editTags(current),
                  ),
                  const SizedBox(height: AppDimens.cardHeaderGap),
                  _buildOutfitImage(options, current),
                  if (options.length > 1) ...[
                    const SizedBox(height: 10),
                    CarouselDotsIndicator(
                      count: options.length,
                      currentIndex: _currentIndex,
                    ),
                  ],
                  const SizedBox(height: AppDimens.sectionSpacing),
                  if (current.garmentIds.isNotEmpty)
                    OutfitGarmentSection(
                      garments: _garmentsByOutfitId[current.id],
                      garmentCount: current.garmentIds.length,
                      isLoading: !_garmentsByOutfitId.containsKey(current.id),
                      onGarmentTap: _openGarmentDetail,
                    ),
                ],
              ),
            ),
      bottomNavigationBar: current == null
          ? null
          : BottomActionButton(
              label: _l10n.viewFullOutfit,
              onPressed: () => _openFullOutfit(current),
            ),
    );
  }

  Widget _buildOutfitImage(List<Outfit> options, Outfit current) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.outfitPhotoRadius),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: options.length,
              itemBuilder: (_, index) {
                final outfit = options[index];
                final cacheKey = outfitImageVersionedCacheKey(outfit.id);
                return GestureDetector(
                  onTap: () => showFullscreenImage(
                    context,
                    imageUrl: outfit.imageUrl,
                    cacheKey: cacheKey,
                    onRefreshUrl: () => _refreshImageUrl(outfit),
                  ),
                  child: RefreshableNetworkImage(
                    key: ValueKey(cacheKey),
                    imageUrl: outfit.imageUrl,
                    cacheKey: cacheKey,
                    fit: BoxFit.cover,
                    errorLabel: _l10n.failedToLoadImage,
                    onRefreshUrl: () => _refreshImageUrl(outfit),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 12,
              right: 12,
              child: CardCornerBadge(
                icon: current.isFavorite
                    ? Icons.favorite
                    : Icons.favorite_border,
                backgroundColor: AppColors.surfaceTranslucent,
                iconColor: current.isFavorite
                    ? AppColors.favorite
                    : AppColors.hintText,
                border: Border.all(color: AppColors.borderSubtle),
                boxShadow: const [],
                size: 36,
                iconSize: 20,
                discAlignment: Alignment.bottomRight,
                onTap: () => _toggleFavorite(current),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Daily outfits lack the group name; look it up in the Outfits list.
  String? _groupNameFor(Outfit outfit, List<Outfit> outfits) {
    if (outfit.groupName != null) return outfit.groupName;
    for (final o in outfits) {
      if (o.groupId == outfit.groupId && o.groupName != null) {
        return o.groupName;
      }
    }
    return null;
  }

  String _titleFor(Outfit outfit) => outfitDisplayTitle(
    _l10n,
    groupName: _groupNameFor(
      outfit,
      ref.watch(outfitsProvider).value ?? const [],
    ),
    name: outfit.name,
    seasons: outfit.seasons,
    style: outfit.style,
  );

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    widget.onIndexChanged?.call(index);
  }

  Future<void> _loadGarments(Outfit outfit) async {
    if (_garmentsByOutfitId.containsKey(outfit.id) ||
        !_loadingGarmentsFor.add(outfit.id)) {
      return;
    }
    List<Garment> garments;
    try {
      garments = await loadOutfitGarments(
        outfit.garmentIds,
        cached: ref.read(garmentsProvider).value ?? const [],
        outfitId: outfit.id,
      );
    } catch (e) {
      debugLog('TodayOutfitPage: failed to load garments for ${outfit.id}: $e');
      garments = const [];
    } finally {
      _loadingGarmentsFor.remove(outfit.id);
    }
    if (mounted) setState(() => _garmentsByOutfitId[outfit.id] = garments);
  }

  Future<String?> _refreshImageUrl(Outfit outfit) async {
    final fresh = await fetchFreshOutfitImageUrl(outfit.groupId, outfit.id);
    ref
        .read(dailyOutfitProvider.notifier)
        .updateOutfit(outfit.copyWith(imageUrl: fresh));
    return fresh;
  }

  Future<void> _editTags(Outfit target) async {
    if (_isSavingTags) return;
    final tags = await showOutfitTagsSheet(context, target);
    if (tags == null || !mounted) return;
    await _saveTags(target, tags);
  }

  /// A failure rolls back (in [DailyOutfitNotifier.updateOutfitTags]) and
  /// offers Retry.
  Future<void> _saveTags(Outfit target, OutfitTags tags) async {
    setState(() => _isSavingTags = true);
    var retry = false;
    try {
      await ref
          .read(dailyOutfitProvider.notifier)
          .updateOutfitTags(target, seasons: tags.seasons, style: tags.style);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('TodayOutfitPage update tags failed: $e');
      await showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.outfitUpdateFailed),
        onRetry: () => retry = true,
      );
    } finally {
      if (mounted) setState(() => _isSavingTags = false);
    }
    // After the finally, or it would clear _isSavingTags under the retry.
    if (retry && mounted) await _saveTags(target, tags);
  }

  Future<void> _toggleFavorite(Outfit target) async {
    try {
      await ref.read(dailyOutfitProvider.notifier).toggleOutfitFavorite(target);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('TodayOutfitPage._toggleFavorite: $e');
      showErrorDialog(context, message: _l10n.failedToUpdateFavorite);
    }
  }

  /// "Add Back to Closet" on a soft-deleted garment swaps the restored one
  /// into [garmentsProvider] and every option's list here.
  Future<void> _openGarmentDetail(Garment g) async {
    final restored = await GarmentDetailDialog.show(context, g);
    if (restored == null || !mounted) return;
    ref.read(garmentsProvider.notifier).updateGarment(restored);
    setState(() {
      _garmentsByOutfitId.updateAll(
        (_, garments) => [
          for (final existing in garments)
            existing.id == restored.id ? restored : existing,
        ],
      );
    });
  }

  void _openFullOutfit(Outfit outfit) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitDetailsPage(
          outfit: outfit.copyWith(
            groupName: _groupNameFor(
              outfit,
              ref.read(outfitsProvider).value ?? const [],
            ),
          ),
        ),
      ),
    );
  }
}
