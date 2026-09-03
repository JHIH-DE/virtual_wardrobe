import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/image_cache_bust.dart';
import '../../core/utils/signed_url.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/style_type.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/carousel_dots_indicator.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/cards/category_tag.dart';
import '../widgets/common/fields/selectable_chip.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_list_card.dart';
import '../widgets/outfit/outfit_image.dart';
import 'add_outfit_page.dart';
import 'select_outfit_group_page.dart';

enum _OutfitMenuAction { rename, share, delete }

enum _VersionMenuAction { setCover, regenerate, delete }

class OutfitDetailsPage extends ConsumerStatefulWidget {
  final Outfit outfit;

  /// True right after this outfit's try-on was rendered (the Add Outfit
  /// flow) — leaving the page then always keeps it and jumps to the
  /// Outfits tab (see [navigateToOutfitsTabOnSave]) rather than just
  /// popping. There's no "discard" choice at leave time: the outfit is
  /// already persisted server-side the instant it's rendered, so getting
  /// rid of an unwanted one is always the explicit Delete action, same as
  /// any other outfit.
  final bool isNew;

  /// When [isNew], whether leaving jumps to the Outfits tab (popping back
  /// to the shell root) or just pops this page. Jumping to Outfits makes
  /// sense when the outfit was created standalone (Home / Add Outfit), but
  /// not when it was opened from a specific flow like Trip Details, where
  /// the user expects to return to what they were doing.
  final bool navigateToOutfitsTabOnSave;

  /// Whether to offer the "Edit Outfit" entry card. Set this to false for
  /// entry points (e.g. Trip Details) where an outfit shouldn't offer to be
  /// edited from here — the card is hidden entirely in that case instead.
  final bool showEditOutfitWhenSaved;

  /// Shows an "Add to My Outfits" action instead of "Create Another
  /// Version" — for outfits whose group isn't `type: general` (e.g. a
  /// daily outfit). Its own group is server-managed and never shows up in
  /// the Outfits tab (which only lists `type: general` groups), so
  /// "Create Another Version" would just add another unreachable version
  /// there. This re-renders the same garments/background into a brand new
  /// general group instead, so the result actually lands somewhere the
  /// user can find it again.
  final bool showAddToMyOutfits;

  const OutfitDetailsPage({
    super.key,
    required this.outfit,
    this.isNew = false,
    this.navigateToOutfitsTabOnSave = true,
    this.showEditOutfitWhenSaved = true,
    this.showAddToMyOutfits = false,
  });

  @override
  ConsumerState<OutfitDetailsPage> createState() => _OutfitDetailsPageState();
}

class _OutfitDetailsPageState extends ConsumerState<OutfitDetailsPage> {
  bool _isDeleting = false;
  // True while leaving a freshly-rendered outfit refreshes the outfits
  // list before jumping to the Outfits tab — see _leaveNewOutfit.
  bool _isLeaving = false;
  // True while we're waiting on _fetchOutfitDetails for entry points that
  // hide the action bar once saved — avoids flashing the "Save Outfit"
  // button before the rest of the outfit's details have loaded.
  bool _isResolvingSavedStatus = false;
  List<Garment>? _garments;
  bool _isLoadingGarments = false;
  bool _isOpeningTryOn = false;
  // True while regenerateOutfit's AI render is in flight.
  bool _isRegenerating = false;
  // True while _addToMyOutfits's AI render is in flight.
  bool _isAddingToMyOutfits = false;
  // True while _setCover's request is in flight.
  bool _isSettingCover = false;

  // Every outfit in this group, swipeable via [_pageController] — starts
  // with just the seed outfit and gets replaced with the full set once
  // [_loadGroupOutfits] resolves (an existing outfit may already have
  // siblings from earlier "Create Another Version" calls).
  late final List<Outfit> _versions = [widget.outfit];
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  /// The version currently shown in the carousel — photo, favorite,
  /// garments, and the Regenerate/Delete actions all apply to this one.
  Outfit get _current => _versions[_currentIndex];

  /// The group's actual cover version — the app bar title/tags always
  /// reflect this one regardless of which version is currently swiped to,
  /// so the header reads as this outfit *group*'s identity rather than
  /// flickering per-version as the user swipes. Resolved by
  /// `coverOutfitId` (every entry in [_versions] carries the same one —
  /// see [_loadGroupOutfits]/[_setCover]), falling back to the lowest id
  /// when unset, exactly mirroring [OutfitService.getAllOutfits]'s own
  /// "representative" pick for the grid card this page was opened from —
  /// [_versions]' array order doesn't necessarily put that version first.
  Outfit get _primary {
    final coverId = _current.coverOutfitId;
    if (coverId == null) {
      return _versions.reduce((a, b) => a.id < b.id ? a : b);
    }
    return _versions.firstWhere(
      (o) => o.id == coverId,
      orElse: () => _versions.reduce((a, b) => a.id < b.id ? a : b),
    );
  }

  List<String> get _effectiveSeasons => _current.seasons;
  List<String> get _effectiveStyle => _current.style;

  /// A daily outfit's group isn't `type: general` — it's server-managed by
  /// its own daily-plan pipeline, not something the user curates here, so
  /// none of the image overlay controls (favorite/version menu) or the
  /// season/style tag editor apply to it.
  bool get _isDailyOutfit => _current.groupType == OutfitGroupType.daily;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    if (widget.outfit.garmentIds.isNotEmpty) _loadGarments();
    if (widget.isNew) {
      _isResolvingSavedStatus = !widget.showEditOutfitWhenSaved;
      _fetchOutfitDetails();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGroupOutfits());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Replaces [_versions] (initially just [widget.outfit]) with every
  /// outfit actually in the group — otherwise the carousel would only ever
  /// show versions created in *this* page instance.
  Future<void> _loadGroupOutfits() async {
    try {
      final outfits = await OutfitService().getGroupOutfits(
        widget.outfit.groupId,
      );
      if (!mounted || outfits.isEmpty) return;
      // getGroupOutfits doesn't necessarily return the cover version
      // first — the grid card that opened this page shows whichever
      // version is the group's cover, so re-select that same one here by
      // id rather than assuming index 0, or the photo/name would flash to
      // a different version the instant this resolves.
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
      _loadGarments();
    } catch (_) {
      // Leave the single seed version already showing.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PopScope(
          canPop: !widget.isNew,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _leaveNewOutfit();
          },
          child: Scaffold(
            backgroundColor: AppColors.pageBackground,
            extendBody: true,
            appBar: _buildAppBar(),
            body: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                _showsBottomActionButton
                    ? AppDimens.bottomActionBtnClearance
                    : 30,
              ),
              children: [
                Text(_title, style: AppTextStyle.bold20),
                const AppDivider(topSpacing: 12, bottomSpacing: 4),
                _buildInfoCard(),
                const SizedBox(height: 4),
                _buildOutfitImage(),
                const SizedBox(height: AppDimens.sectionSpacing),
                if (_current.garmentIds.isNotEmpty) ...[_buildGarmentSection()],
              ],
            ),
            bottomNavigationBar: _buildBottomBar(),
          ),
        ),
        if (_isOpeningTryOn)
          Positioned.fill(child: LoadingOverlay(label: _l10n.loadingGarments)),
        if (_isLeaving)
          Positioned.fill(child: LoadingOverlay(label: _l10n.loading)),
      ],
    );
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      // Blank — the name shows as its own block below the app bar instead
      // (see build's ListView), so it isn't in the toolbar at all.
      title: '',
      onBack: widget.isNew ? _leaveNewOutfit : null,
      actions: [
        if (!widget.isNew)
          AppPopupMenu<_OutfitMenuAction>(
            onSelected: _handleMenuAction,
            items: [
              AppPopupMenu.item(
                value: _OutfitMenuAction.rename,
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.icon,
                ),
                label: _l10n.rename,
              ),
              AppPopupMenu.item(
                value: _OutfitMenuAction.share,
                icon: const Icon(
                  Icons.share_outlined,
                  size: 20,
                  color: AppColors.icon,
                ),
                label: _l10n.share,
              ),
              AppPopupMenu.item(
                value: _OutfitMenuAction.delete,
                enabled: !_isDeleting,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.icon,
                ),
                label: _l10n.deleteOutfitTitle,
                isDestructive: true,
              ),
            ],
          ),
      ],
    );
  }

  void _handleMenuAction(_OutfitMenuAction action) {
    switch (action) {
      case _OutfitMenuAction.rename:
        _showRenameDialog();
        break;
      case _OutfitMenuAction.share:
        _shareOutfit();
        break;
      case _OutfitMenuAction.delete:
        _deleteOutfit();
        break;
    }
  }

  Widget _buildBottomBar() {
    if (_isResolvingSavedStatus) return const SizedBox.shrink();

    if (widget.showAddToMyOutfits) {
      return BottomActionButton(
        label: _l10n.addToMyOutfits,
        leading: const Icon(Icons.add),
        onPressed: _isAddingToMyOutfits ? null : _addToMyOutfits,
        isLoading: _isAddingToMyOutfits,
      );
    }

    if (!widget.showEditOutfitWhenSaved) return const SizedBox.shrink();

    return BottomActionButton(
      label: _l10n.createAnotherVersion,
      leading: const Icon(Icons.edit_outlined),
      onPressed: _openCreateAnotherVersion,
    );
  }

  bool get _showsBottomActionButton =>
      !_isResolvingSavedStatus &&
      (widget.showAddToMyOutfits || widget.showEditOutfitWhenSaved);

  /// Opens Add Outfit in "Create Another Version" mode — its bottom button
  /// calls `generateOutfit` into this outfit's *same* group instead of a
  /// fresh one (see [AddOutfitPage.existingOutfit]), so the result is a
  /// brand new [Outfit] alongside this one, appended to [_versions] and
  /// swiped into view.
  Future<void> _openCreateAnotherVersion() async {
    setState(() => _isOpeningTryOn = true);
    try {
      final closetGarments = await ref.read(garmentsProvider.future);
      if (!mounted) return;
      setState(() => _isOpeningTryOn = false);
      if (!context.mounted) return;
      final result = await Navigator.push<Outfit>(
        context,
        MaterialPageRoute(
          builder: (_) => AddOutfitPage(
            existingOutfit: _current,
            initialGarments: _garments ?? const [],
            preloadedGarments: closetGarments,
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() {
        _versions.add(result);
        _currentIndex = _versions.length - 1;
      });
      _loadGarments();
      if (_pageController.hasClients) {
        await _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
      await ref.read(outfitsProvider.notifier).refresh();
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => _isOpeningTryOn = false);
      await AuthExpiredHandler.handle(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isOpeningTryOn = false);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToLoadGarments)));
      }
    }
  }

  /// Opens [SelectOutfitGroupPage] so the user can pick which `type:
  /// general` group to copy this outfit into (see
  /// [OutfitDetailsPage.showAddToMyOutfits]) — an existing group or a new
  /// one. [OutfitService.copyOutfit] duplicates the existing render
  /// server-side, no AI re-render. Mirrors [_leaveNewOutfit]'s "jump to Outfits
  /// with a saved toast" ending, since the result is the same: a new
  /// outfit the user can now find in the Outfits tab.
  Future<void> _addToMyOutfits() async {
    if (_isAddingToMyOutfits) return;
    setState(() => _isAddingToMyOutfits = true);
    try {
      final result = await Navigator.push<Outfit>(
        context,
        MaterialPageRoute(
          builder: (_) => SelectOutfitGroupPage(sourceOutfit: _current),
        ),
      );
      if (result == null || !mounted) return;
      final feedback = ref.read(outfitFeedbackProvider.notifier);
      MainShellScope.of(context)?.selectTab(AppTab.outfits);
      Navigator.popUntil(context, (route) => route.isFirst);
      feedback.state = OutfitFeedbackKind.saved;
    } finally {
      if (mounted) setState(() => _isAddingToMyOutfits = false);
    }
  }

  // Styles come back from the backend snake_case (`smart_casual`); seasons
  // are single lowercase words either way, so the underscore swap is a
  // no-op for them.
  String _titleCase(String s) => s
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Widget _buildInfoCard() {
    final tags = [..._effectiveStyle.map(_titleCase)];
    final tagStyle = AppTextStyle.regular14.copyWith(
      color: AppColors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isDailyOutfit) ...[
            GestureDetector(
              onTap: _openEditTagsSheet,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.accentTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sell_outlined,
                  size: 16,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: tags.isEmpty
                ? Text(_l10n.myCollection, style: tagStyle)
                : _CollapsingTagsRow(tags: tags),
          ),
        ],
      ),
    );
  }

  /// Opens a bottom sheet to multi-select Season/Style tags, then saves via
  /// [OutfitService.updateOutfit] on confirm. Applies to whichever version
  /// was current when the sheet was opened — captured up front so a swipe
  /// while the sheet is still open can't retarget the save.
  Future<void> _openEditTagsSheet() async {
    final target = _current;
    final index = _currentIndex;
    final selectedSeasons = target.seasons.map(_titleCase).toSet();
    final selectedStyles = target.style.map(_titleCase).toSet();

    final result =
        await showPickerSheet<({List<String> seasons, List<String> styles})>(
          context,
          builder: (sheetContext) => StatefulBuilder(
            builder: (ctx, setSheetState) {
              Widget chipGroup(List<String> options, Set<String> selected) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: options
                      .map(
                        (option) => SelectableChip(
                          label: option,
                          selected: selected.contains(option),
                          selectedColor: AppColors.accentTint,
                          selectedTextColor: AppColors.accent,
                          onTap: () => setSheetState(() {
                            if (!selected.remove(option)) {
                              selected.add(option);
                            }
                          }),
                        ),
                      )
                      .toList(),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PickerSheetHeader(_l10n.editTagsTitle),
                  const SizedBox(height: 4),
                  Text(_l10n.seasonLabel, style: AppTextStyle.bold16),
                  const SizedBox(height: 12),
                  chipGroup(seasonOptions, selectedSeasons),
                  const SizedBox(height: 24),
                  Text(_l10n.styleLabel, style: AppTextStyle.bold16),
                  const SizedBox(height: 12),
                  chipGroup(styleOptions, selectedStyles),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, (
                        seasons: selectedSeasons.toList(),
                        styles: selectedStyles.toList(),
                      )),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _l10n.save,
                        style: AppTextStyle.regular14.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
    if (result == null || !mounted) return;

    final seasons = result.seasons.map((s) => s.toLowerCase()).toList();
    // Reverses _titleCase's underscore-to-space swap so multi-word styles
    // round-trip back to the backend's snake_case wire format.
    final styles = result.styles
        .map((s) => s.toLowerCase().replaceAll(' ', '_'))
        .toList();
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        season: seasons,
        style: styles,
      );
      if (!mounted || index >= _versions.length) return;
      setState(() {
        _versions[index] = target.copyWith(seasons: seasons, style: styles);
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _shareOutfit() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.shareComingSoon)));
  }

  /// Refreshes the signed image URL for the version at [index] — every
  /// version can self-heal independently, since each carries its own
  /// outfit id.
  Future<String?> _refreshImageUrlFor(int index) async {
    if (index >= _versions.length) return null;
    final outfit = _versions[index];
    final fresh = await fetchFreshOutfitImageUrl(outfit.groupId, outfit.id);
    if (mounted && index < _versions.length) {
      setState(() => _versions[index] = outfit.copyWith(imageUrl: fresh));
    }
    return fresh;
  }

  Future<void> _toggleFavorite() async {
    final target = _current;
    final index = _currentIndex;
    final next = !target.isFavorite;
    setState(() => _versions[index] = target.copyWith(isFavorite: next));
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        isFavorite: next,
      );
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => _versions[index] = target);
      await AuthExpiredHandler.handle(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _versions[index] = target);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateFavorite)));
    }
  }

  /// Sets [_current] as this group's cover outfit (`PATCH
  /// /outfit/{group_id}`) — a group-level choice, so it's applied to every
  /// entry in [_versions] at once rather than just [_current]. No "unset"
  /// path: picking a different version as cover already replaces whichever
  /// one held it before.
  Future<void> _setCover() async {
    if (_isSettingCover) return;
    final target = _current;
    final previous = List<Outfit>.from(_versions);
    setState(() {
      _isSettingCover = true;
      for (var i = 0; i < _versions.length; i++) {
        _versions[i] = _versions[i].copyWith(coverOutfitId: target.id);
      }
    });
    try {
      await OutfitService().updateGroup(
        target.groupId,
        coverOutfitId: target.id,
      );
      await ref.read(outfitsProvider.notifier).refresh();
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() {
        _versions
          ..clear()
          ..addAll(previous);
      });
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _versions
          ..clear()
          ..addAll(previous);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSettingCover = false);
    }
  }

  /// Re-runs the AI render for the currently shown version in place (see
  /// [OutfitService.regenerateOutfit]) — same garment combo/background, new
  /// image, no new version created.
  Future<void> _regenerateImage() async {
    if (_isRegenerating) return;
    final target = _current;
    final index = _currentIndex;
    setState(() => _isRegenerating = true);
    try {
      final outfit = await OutfitService().regenerateOutfit(
        target.groupId,
        target.id,
      );
      if (!mounted) return;
      setState(() => _versions[index] = outfit);
      // regenerateOutfit overwrites the image at its existing URL in place,
      // so the URL never changes — bump the base key every consumer of
      // this outfit's image reads (OutfitImage in the Outfits list, Home,
      // Trip pages) so they all move to a cache key that's never been seen
      // before instead of keep serving pre-regenerate bytes from a
      // stable key's cache entry.
      ImageCacheBust.bump(outfitImageCacheKey(target.id));
      await ref.read(outfitsProvider.notifier).refresh();
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Widget _buildOutfitImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    // Different versions can have different garments — keep
                    // the Garment list in sync with whichever is shown now.
                    _loadGarments();
                  },
                  itemCount: _versions.length,
                  itemBuilder: (_, index) {
                    final outfit = _versions[index];
                    // Stable base id (survives signed-URL re-signing) plus
                    // ImageCacheBust's live version — bumped by
                    // _regenerateImage/_openCreateAnotherVersion, and read
                    // fresh by every widget that shows this outfit's image
                    // (OutfitImage elsewhere included), so nothing keeps
                    // serving pre-regenerate bytes from a stable key's
                    // cache entry.
                    final baseKey = outfitImageCacheKey(outfit.id);
                    final cacheKey =
                        '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
                    return RefreshableNetworkImage(
                      key: ValueKey(cacheKey),
                      imageUrl: outfit.imageUrl,
                      cacheKey: cacheKey,
                      fit: BoxFit.cover,
                      errorLabel: _l10n.failedToLoadImage,
                      onRefreshUrl: () => _refreshImageUrlFor(index),
                    );
                  },
                ),
                if (!_isRegenerating && !_isDailyOutfit) ...[
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildVersionMenuButton(),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: CardCornerBadge(
                      icon: _current.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      backgroundColor: AppColors.surfaceTranslucent,
                      iconColor: _current.isFavorite
                          ? AppColors.favorite
                          : AppColors.icon,
                      size: 36,
                      iconSize: 20,
                      onTap: _toggleFavorite,
                    ),
                  ),
                ],
                if (_isRegenerating)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: LoadingOverlay(label: _l10n.generatingEllipsis),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CarouselDotsIndicator(
          count: _versions.length,
          currentIndex: _currentIndex,
        ),
      ],
    );
  }

  /// Dots marking which version's photo is shown, plus a "current / total"
  /// counter trailing them — hidden entirely when there's only one version.
  /// The photo's own "..." corner menu — Regenerate and Delete this
  /// version for whichever version is currently shown (see
  /// [_deleteThisOutfit] for what "delete" actually does depending on
  /// whether this outfit has siblings in its group).
  Widget _buildVersionMenuButton() {
    return AppPopupMenu<_VersionMenuAction>(
      onSelected: _handleVersionMenuAction,
      items: [
        AppPopupMenu.item(
          value: _VersionMenuAction.setCover,
          enabled: !_isSettingCover,
          icon: const Icon(
            Icons.push_pin_outlined,
            size: 20,
            color: AppColors.icon,
          ),
          label: _l10n.setAsCover,
        ),
        AppPopupMenu.item(
          value: _VersionMenuAction.regenerate,
          icon: const Icon(Icons.refresh, size: 20, color: AppColors.icon),
          label: _l10n.regenerate,
        ),
        AppPopupMenu.item(
          value: _VersionMenuAction.delete,
          enabled: !_isDeleting,
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: AppColors.icon,
          ),
          label: _l10n.deleteThisVersion,
          isDestructive: true,
        ),
      ],
      trigger: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceTranslucent,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.overlaySubtle, blurRadius: 4)],
        ),
        child: const Icon(Icons.more_horiz, size: 20, color: AppColors.icon),
      ),
    );
  }

  void _handleVersionMenuAction(_VersionMenuAction action) {
    switch (action) {
      case _VersionMenuAction.setCover:
        _setCover();
        break;
      case _VersionMenuAction.regenerate:
        _regenerateImage();
        break;
      case _VersionMenuAction.delete:
        _deleteThisOutfit();
        break;
    }
  }

  Widget _buildGarmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDivider(
          label: _l10n.garmentsCount(
            _garments?.length ?? _current.garmentIds.length,
          ),
        ),
        const SizedBox(height: AppDimens.cardHeaderGap),
        if (_isLoadingGarments && !_isRegenerating)
          const Center(child: AppSpinner())
        else if (_garments != null)
          ..._garments!.map(_buildGarmentCard),
      ],
    );
  }

  Widget _buildGarmentCard(Garment g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.sectionSpacing),
      child: GarmentListCard(
        garment: g,
        onTap: () => GarmentDetailDialog.show(context, g),
      ),
    );
  }

  Future<void> _fetchOutfitDetails() async {
    try {
      final outfit = await OutfitService().getOutfit(
        widget.outfit.groupId,
        widget.outfit.id,
      );
      if (!mounted) return;
      // isNew mode never has other versions loaded yet, so this is always
      // the only entry in _versions.
      setState(() => _versions[0] = outfit);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isResolvingSavedStatus = false);
    }
  }

  Map<int, Garment> _indexGarmentsById(List<Garment> garments) {
    return {
      for (final g in garments)
        if (g.id != null) g.id!: g,
    };
  }

  Future<void> _loadGarments() async {
    setState(() => _isLoadingGarments = true);
    try {
      // Reuse whatever My Closet has already loaded into garmentsProvider
      // instead of always hitting the network per garment — but skip stale
      // cache entries whose signed image URL has expired, so photos don't
      // render as broken images.
      final cached = ref.read(garmentsProvider).value ?? const [];
      final cachedById = _indexGarmentsById(cached);
      final idsToLoad = _current.garmentIds.toSet();

      final results = await Future.wait(
        idsToLoad.map((id) {
          final cachedGarment = cachedById[id];
          final imageUrl = cachedGarment?.imageUrl;
          final isFresh =
              cachedGarment != null &&
              (imageUrl == null ||
                  imageUrl.isEmpty ||
                  !isSignedUrlExpired(imageUrl));
          return isFresh
              ? Future.value(cachedGarment)
              : GarmentService().getGarment(id);
        }),
      );
      if (mounted) setState(() => _garments = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGarments = false);
    }
  }

  /// Leaving a freshly-rendered outfit's page (back arrow, system back
  /// gesture) — see [OutfitDetailsPage.isNew]. The outfit is already
  /// persisted server-side the instant it's rendered, so there's nothing to
  /// confirm: this just refreshes the outfits list (so it isn't stale) and
  /// jumps to the Outfits tab. Getting rid of an unwanted outfit is always
  /// the explicit Delete action instead, same as any other outfit.
  Future<void> _leaveNewOutfit() async {
    setState(() => _isLeaving = true);
    try {
      await ref.read(outfitsProvider.notifier).refresh();
      if (!mounted) return;
      if (widget.navigateToOutfitsTabOnSave) {
        final feedback = ref.read(outfitFeedbackProvider.notifier);
        MainShellScope.of(context)?.selectTab(AppTab.outfits);
        Navigator.popUntil(context, (route) => route.isFirst);
        feedback.state = OutfitFeedbackKind.saved;
      } else {
        Navigator.pop(context);
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  /// The app bar's "..." menu action — always deletes the whole group (and
  /// every version in it), regardless of how many it holds.
  Future<void> _deleteOutfit() => _confirmThenDeleteGroup();

  /// Deletes every version and the group itself, then closes the page.
  Future<void> _confirmThenDeleteGroup() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.deleteOutfitTitle,
        body: _l10n.deleteOutfitGroupConfirmation,
        primaryLabel: _l10n.delete,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await OutfitService().deleteGroup(widget.outfit.groupId);
      for (final version in _versions) {
        ref.read(outfitsProvider.notifier).removeOutfit(version.id);
      }
      final feedback = ref.read(outfitFeedbackProvider.notifier);
      if (mounted) Navigator.pop(context);
      feedback.state = OutfitFeedbackKind.deleted;
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// The action bar's delete button under the photo — surgical by default:
  /// if there are other versions left, only the currently shown one is
  /// deleted and the carousel moves on; if it's the last version, the
  /// now-empty group goes with it and the page closes (see
  /// [_confirmThenDeleteGroup]).
  Future<void> _deleteThisOutfit() async {
    if (_isDeleting) return;
    if (_versions.length <= 1) {
      await _confirmThenDeleteGroup();
      return;
    }

    final target = _current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.deleteOutfitTitle,
        body: _l10n.deleteOutfitConfirmation,
        primaryLabel: _l10n.delete,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await OutfitService().deleteOutfit(target.groupId, target.id);
      if (!mounted) return;
      setState(() {
        _versions.remove(target);
        _currentIndex = _currentIndex.clamp(0, _versions.length - 1);
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
      _loadGarments();
      // Not removeById: the flat outfits list shows one card per group (the
      // group's first version stands in for it), so if [target] was that
      // representative the card needs to be replaced with whichever version
      // is now first, not removed outright while the group still exists.
      await ref.read(outfitsProvider.notifier).refresh();
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String get _title {
    final groupName = _primary.groupName;
    if (groupName != null && groupName.isNotEmpty) return groupName;
    final name = _primary.name;
    if (name != null && name.isNotEmpty) return name;
    final parts = [..._effectiveSeasons, ..._effectiveStyle];
    if (parts.isEmpty) return _l10n.myOutfit;
    final word = parts.first;
    final capitalized = word.isEmpty
        ? word
        : '${word[0].toUpperCase()}${word.substring(1)}';
    return _l10n.outfitTitle(capitalized);
  }

  Future<void> _showRenameDialog() async {
    final result = await showTextInputDialog(
      context,
      title: _l10n.renameOutfit,
      hint: _l10n.outfitNameLabel,
      initialValue: _primary.groupName ?? '',
    );

    if (result == null || !mounted) return;
    try {
      await OutfitService().updateGroup(_primary.groupId, name: result);
      if (!mounted) return;
      // The name is a group-level property — every version shares it, not
      // just the one currently shown.
      setState(() {
        for (var i = 0; i < _versions.length; i++) {
          _versions[i] = _versions[i].copyWith(groupName: result);
        }
      });
      ref
          .read(outfitsProvider.notifier)
          .updateGroupName(_primary.groupId, name: result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}

/// Lays [tags] out on a single line, collapsing whatever doesn't fit into a
/// trailing "+N" tag instead of wrapping to a second line.
class _CollapsingTagsRow extends StatelessWidget {
  final List<String> tags;

  const _CollapsingTagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    const tagSpacing = 8.0;
    const tagHPadding = 20.0; // CategoryTag's horizontal padding (10 * 2).
    final tagTextStyle = AppTextStyle.bold12;

    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: tagTextStyle),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final tagWidths = tags.map((t) => textWidth(t) + tagHPadding).toList();

        var visibleCount = tags.length;
        var usedWidth = 0.0;
        for (var i = 0; i < tags.length; i++) {
          final width = tagWidths[i] + (i > 0 ? tagSpacing : 0);
          if (usedWidth + width > maxWidth) {
            visibleCount = i;
            break;
          }
          usedWidth += width;
        }

        if (visibleCount == tags.length) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tags.length; i++) ...[
                if (i > 0) const SizedBox(width: tagSpacing),
                CategoryTag(label: tags[i]),
              ],
            ],
          );
        }

        // Shrink further if needed so the trailing "+N" tag also fits.
        var count = visibleCount;
        while (count > 0) {
          final overflowLabel = '+${tags.length - count}';
          var used = tagSpacing + textWidth(overflowLabel) + tagHPadding;
          for (var i = 0; i < count; i++) {
            used += tagWidths[i] + (i > 0 ? tagSpacing : 0);
          }
          if (used <= maxWidth) break;
          count--;
        }
        count = count.clamp(1, tags.length);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: tagSpacing),
              CategoryTag(label: tags[i]),
            ],
            const SizedBox(width: tagSpacing),
            CategoryTag(label: '+${tags.length - count}'),
          ],
        );
      },
    );
  }
}
