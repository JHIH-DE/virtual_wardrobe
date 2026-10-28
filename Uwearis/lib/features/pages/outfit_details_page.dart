import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/daily_outfit_provider.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/idempotency_key.dart';
import '../../core/utils/image_cache_bust.dart';
import '../../core/utils/outfit_garments.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/carousel_dots_indicator.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/images/fullscreen_image_viewer.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/overlays/ai_consent_dialog.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/save_changes_dialog.dart';
import '../widgets/common/overlays/text_input_dialog.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/outfit/outfit_garment_section.dart';
import '../widgets/outfit/outfit_image.dart';
import '../widgets/outfit/outfit_share_sheet.dart';
import '../widgets/outfit/outfit_tag_row.dart';
import '../widgets/outfit/outfit_tags_sheet.dart';
import '../widgets/outfit/outfit_title.dart';
import 'create_outfit_page.dart';

enum _OutfitMenuAction { rename, share, delete }

enum _VersionMenuAction { setCover, regenerate, delete }

class OutfitDetailsPage extends ConsumerStatefulWidget {
  final Outfit outfit;

  /// Freshly rendered from Add Outfit: shows a "Save" action, and leaving
  /// before saving prompts (Don't Save deletes the whole group).
  final bool isNew;

  /// False for entry points (e.g. Trip Details) that shouldn't offer
  /// "+ New Version".
  final bool showEditOutfitWhenSaved;

  const OutfitDetailsPage({
    super.key,
    required this.outfit,
    this.isNew = false,
    this.showEditOutfitWhenSaved = true,
  });

  @override
  ConsumerState<OutfitDetailsPage> createState() => _OutfitDetailsPageState();
}

class _OutfitDetailsPageState extends ConsumerState<OutfitDetailsPage> {
  bool _isDeleting = false;
  // Discarding a new outfit (deleting its group) on leave.
  bool _isLeaving = false;
  // Hides the Save button until _fetchOutfitDetails resolves, so it doesn't
  // flash on entry points that hide it.
  bool _isResolvingSavedStatus = false;
  List<Garment>? _garments;
  bool _isLoadingGarments = false;
  // Lets [_loadGarments] skip re-fetching the set it already has.
  Set<int>? _loadedGarmentIds;
  // Guards against re-entering _openCreateAnotherVersion.
  bool _isAddingVersion = false;
  // [isNew] only: Save was tapped, so leaving no longer prompts.
  bool _saved = false;
  bool _isRegenerating = false;
  bool _isSettingCover = false;
  bool _isTogglingFavorite = false;
  // Keeps the tag button disabled so two tag saves can't race.
  bool _isSavingTags = false;

  // Seeded with widget.outfit, replaced by [_loadGroupOutfits].
  late final List<Outfit> _versions = [widget.outfit];

  static const int _maxVersions = 10;
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // False until [_loadGroupOutfits] resolves, so the counter / version-only
  // menu items don't pop in after a single-version first render.
  bool _versionsResolved = false;

  /// The version shown in the carousel; photo, favorite, garments and the
  /// version actions apply to it.
  Outfit get _current => _versions[_currentIndex];

  /// The group's cover version (lowest id when unset, same pick as
  /// [OutfitService.getAllOutfits]), so the title doesn't change per swipe.
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

  /// Gates "Set as Cover" / "Delete This Version"; with one version the
  /// app-bar Delete already covers deleting the group.
  bool get _hasMultipleVersions => _versionsResolved && _versions.length >= 2;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    if (widget.outfit.garmentIds.isNotEmpty) _loadGarments();
    if (widget.isNew) {
      _isResolvingSavedStatus = !widget.showEditOutfitWhenSaved;
      _versionsResolved = true;
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

  Future<void> _loadGroupOutfits() async {
    try {
      final outfits = await OutfitService().getGroupOutfits(
        widget.outfit.groupId,
      );
      if (!mounted) return;
      if (outfits.isEmpty) {
        setState(() => _versionsResolved = true);
        return;
      }
      // Order isn't guaranteed; stay on the version the page opened with.
      final matchedIndex = outfits.indexWhere((o) => o.id == widget.outfit.id);
      setState(() {
        _versions
          ..clear()
          ..addAll(outfits);
        _currentIndex = matchedIndex >= 0 ? matchedIndex : 0;
        _versionsResolved = true;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
      _loadGarments();
    } catch (_) {
      // Leave the single seed version already showing.
      if (mounted) setState(() => _versionsResolved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PopScope(
          canPop: !widget.isNew || _saved,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _leaveNewOutfit();
          },
          child: Scaffold(
            backgroundColor: AppColors.pageBackground,
            extendBody: true,
            appBar: _buildAppBar(),
            body: Builder(
              builder: (bodyContext) => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  _showsBottomActionButton
                      ? BottomActionButton.scrollClearance(bodyContext)
                      : 30 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  Text(_title, style: AppTextStyle.bold20),
                  const SizedBox(height: 8),
                  _buildInfoCard(),
                  const SizedBox(height: AppDimens.cardHeaderGap),
                  _buildOutfitImage(),
                  if (_current.garmentIds.isNotEmpty) ...[
                    _buildGarmentSection(),
                  ],
                ],
              ),
            ),
            bottomNavigationBar: _buildBottomBar(),
          ),
        ),
        if (_isLeaving)
          Positioned.fill(child: LoadingOverlay(label: _l10n.loading)),
      ],
    );
  }

  AppToolBar _buildAppBar() {
    final items = [
      if (_isSaved)
        AppPopupMenu.item(
          value: _OutfitMenuAction.rename,
          icon: const Icon(
            Icons.edit_outlined,
            size: 20,
            color: AppColors.icon,
          ),
          label: _l10n.rename,
        ),
      if (!_isRegenerating)
        AppPopupMenu.item(
          value: _OutfitMenuAction.share,
          icon: const Icon(
            Icons.share_outlined,
            size: 20,
            color: AppColors.icon,
          ),
          label: _l10n.share,
        ),
      if (_isSaved)
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
    ];
    return AppToolBar(
      title: _l10n.outfitDetailsTitle,
      onBack: widget.isNew ? _leaveNewOutfit : null,
      actions: [
        if (items.isNotEmpty)
          AppPopupMenu<_OutfitMenuAction>(
            variant: AppPopupMenuVariant.toolbar,
            onSelected: _handleMenuAction,
            items: items,
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

    if (widget.isNew) {
      return BottomActionButton(
        label: _l10n.save,
        leading: const Icon(Icons.check),
        enabled: !_saved,
        onPressed: _save,
      );
    }

    return const SizedBox.shrink();
  }

  bool get _showsBottomActionButton =>
      !_isResolvingSavedStatus && widget.isNew && !_saved;

  /// Opens Add Outfit in version mode on this version's garments and
  /// background; the version it renders is swiped into view here.
  /// At [_maxVersions] the pill stays and explains the limit instead.
  Future<void> _openCreateAnotherVersion() async {
    if (_isAddingVersion) return;
    if (_versions.length >= _maxVersions) {
      await _showVersionLimitDialog();
      return;
    }
    setState(() => _isAddingVersion = true);
    final outfit = await Navigator.push<Outfit>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateOutfitPage(
          // A deleted garment can't go into a new version.
          initialGarments: [
            for (final g in _garments ?? const <Garment>[])
              if (!g.isDeleted) g,
          ],
          targetGroupId: _current.groupId,
          initialBackgroundId: _current.backgroundId,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _isAddingVersion = false);
    if (outfit == null) return;
    // Read before the swipe-in await so it still lands if the page closes.
    final outfits = ref.read(outfitsProvider.notifier);
    setState(() {
      _versions.add(outfit);
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
    await outfits.refresh();
  }

  Future<void> _showVersionLimitDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.versionLimitReachedTitle,
        body: _l10n.versionLimitReachedBody,
        primaryLabel: _l10n.ok,
        onPrimary: () => Navigator.pop(ctx),
        primaryIsTextButton: true,
      ),
    );
  }

  Widget _buildInfoCard() {
    return OutfitTagsHeader(
      seasons: _effectiveSeasons,
      style: _effectiveStyle,
      onEdit: _isSavingTags ? null : _openEditTagsSheet,
    );
  }

  /// Auto-saves on close if the selection changed. The target version is
  /// captured up front so a swipe while the sheet is open can't retarget it.
  Future<void> _openEditTagsSheet() async {
    if (_isSavingTags) return;
    final target = _current;
    final index = _currentIndex;
    final tags = await showOutfitTagsSheet(context, target);
    if (tags == null || !mounted) return;
    await _saveTags(index, target, seasons: tags.seasons, styles: tags.style);
  }

  /// Optimistic; a failure rolls back to [target] and offers Retry.
  Future<void> _saveTags(
    int index,
    Outfit target, {
    required List<String> seasons,
    required List<String> styles,
  }) async {
    final updated = target.copyWith(seasons: seasons, style: styles);
    // Read before the await so the sync still lands if the page is popped
    // meanwhile. Each is a no-op when it doesn't hold this version.
    final outfits = ref.read(outfitsProvider.notifier);
    final dailyOutfits = ref.read(dailyOutfitProvider.notifier);
    setState(() {
      _isSavingTags = true;
      if (index < _versions.length) _versions[index] = updated;
    });

    void rollBack() {
      // Only undo our own optimistic write — a reload may have replaced it.
      if (index < _versions.length && identical(_versions[index], updated)) {
        _versions[index] = target;
      }
    }

    var retry = false;
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        season: seasons,
        style: styles,
      );
      outfits.updateOutfit(updated);
      dailyOutfits.updateOutfit(updated);
    } on AuthExpiredException {
      if (!mounted) return;
      setState(rollBack);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('OutfitDetailsPage update tags failed: $e');
      setState(rollBack);
      await showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.outfitUpdateFailed),
        onRetry: () => retry = true,
      );
    } finally {
      if (mounted) setState(() => _isSavingTags = false);
    }
    // After the finally, or it would clear _isSavingTags under the retry.
    if (retry && mounted) {
      await _saveTags(index, target, seasons: seasons, styles: styles);
    }
  }

  void _shareOutfit() {
    showOutfitShareSheet(
      context,
      imageUrl: _current.imageUrl,
      name: _title,
      style: _effectiveStyle.map(outfitTagLabel).toList(),
      seasons: _effectiveSeasons.map(outfitTagLabel).toList(),
      garmentImageUrls: [
        for (final g in _garments ?? const <Garment>[])
          if ((g.imageUrl ?? '').isNotEmpty) g.imageUrl!,
      ],
    );
  }

  Future<String?> _refreshImageUrlFor(int index) async {
    if (index >= _versions.length) return null;
    final outfit = _versions[index];
    final fresh = await fetchFreshOutfitImageUrl(outfit.groupId, outfit.id);
    // By id: the list may have been reloaded or a version deleted meanwhile.
    final i = _versions.indexWhere((v) => v.id == outfit.id);
    if (mounted && i >= 0) {
      setState(() => _versions[i] = _versions[i].copyWith(imageUrl: fresh));
    }
    return fresh;
  }

  /// One request at a time: overlapping ones could land out of order, and
  /// a failed one's rollback would undo the other.
  Future<void> _toggleFavorite() async {
    if (_isTogglingFavorite) return;
    final target = _current;
    final next = !target.isFavorite;
    final updated = target.copyWith(isFavorite: next);
    // Read before the await so the sync still lands if the page is popped
    // meanwhile. Each is a no-op when it doesn't hold this version.
    final outfits = ref.read(outfitsProvider.notifier);
    final dailyOutfits = ref.read(dailyOutfitProvider.notifier);

    // By id, not index: versions may be deleted or reloaded meanwhile.
    void setFavorite(bool value) {
      final i = _versions.indexWhere((v) => v.id == target.id);
      if (i >= 0) _versions[i] = _versions[i].copyWith(isFavorite: value);
    }

    setState(() {
      _isTogglingFavorite = true;
      setFavorite(next);
    });
    try {
      await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        isFavorite: next,
      );
      outfits.updateOutfit(updated);
      dailyOutfits.updateOutfit(updated);
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => setFavorite(!next));
      await AuthExpiredHandler.handle(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => setFavorite(!next));
      showErrorDialog(context, message: _l10n.failedToUpdateFavorite);
    } finally {
      if (mounted) setState(() => _isTogglingFavorite = false);
    }
  }

  /// Group-level, so it's applied to every entry in [_versions].
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
      unawaited(ref.read(outfitsProvider.notifier).refresh());
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
      debugLog('OutfitDetailsPage._setCover failed: $e');
      setState(() {
        _versions
          ..clear()
          ..addAll(previous);
      });
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.outfitUpdateFailed),
      );
    } finally {
      if (mounted) setState(() => _isSettingCover = false);
    }
  }

  /// Re-renders the current version in place. Confirms first: it's a paid
  /// AI call.
  Future<void> _regenerateImage() async {
    if (_isRegenerating) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.regenerateOutfitConfirmTitle,
        body: _l10n.regenerateOutfitConfirmBody,
        primaryLabel: _l10n.regenerate,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (ok != true || !mounted) return;
    if (!await ensureAiConsent(context) || !mounted || _isRegenerating) return;

    final target = _current;
    final index = _currentIndex;
    setState(() => _isRegenerating = true);
    try {
      final outfit = await OutfitService().regenerateOutfit(
        target.groupId,
        target.id,
        idempotencyKey: newIdempotencyKey(),
      );
      if (!mounted) return;
      setState(() => _versions[index] = outfit);
      // The image is overwritten at the same URL, so bump the cache key
      // every consumer reads or they keep serving the old bytes.
      ImageCacheBust.bump(outfitImageCacheKey(target.id));
      unawaited(ref.read(outfitsProvider.notifier).refresh());
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('OutfitDetailsPage._regenerateImage failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(
          _l10n,
          e,
          fallback: _l10n.failedToGenerateOutfit,
        ),
      );
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  Widget _buildOutfitImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.outfitPhotoRadius),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                    _loadGarments();
                  },
                  itemCount: _versions.length,
                  itemBuilder: (_, index) {
                    final outfit = _versions[index];
                    // Survives URL re-signing; versioned by _regenerateImage.
                    final cacheKey = outfitImageVersionedCacheKey(outfit.id);
                    return GestureDetector(
                      onTap: () => showFullscreenImage(
                        context,
                        imageUrl: outfit.imageUrl,
                        cacheKey: cacheKey,
                        onRefreshUrl: () => _refreshImageUrlFor(index),
                      ),
                      child: RefreshableNetworkImage(
                        key: ValueKey(cacheKey),
                        imageUrl: outfit.imageUrl,
                        cacheKey: cacheKey,
                        fit: BoxFit.cover,
                        errorLabel: _l10n.failedToLoadImage,
                        onRefreshUrl: () => _refreshImageUrlFor(index),
                      ),
                    );
                  },
                ),
                if (!_isRegenerating)
                  Positioned(
                    top: 12,
                    right: 12,
                    // One version: Regenerate is the only action, no menu.
                    child: _hasMultipleVersions
                        ? _buildVersionMenuButton()
                        : _buildRegenerateBadge(),
                  ),
                if (!_isRegenerating && _canAddVersion)
                  Positioned(
                    left: 12,
                    bottom: 8,
                    child: AccentPillButton(
                      label: _l10n.addVersionButton,
                      enabled: !_isAddingVersion,
                      onPressed: _openCreateAnotherVersion,
                    ),
                  ),
                if (!_isRegenerating && _isSaved)
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
                          : AppColors.hintText,
                      border: Border.all(color: AppColors.borderSubtle),
                      boxShadow: const [],
                      size: 36,
                      iconSize: 20,
                      discAlignment: Alignment.bottomRight,
                      onTap: _toggleFavorite,
                    ),
                  ),
                if (_isRegenerating)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppDimens.outfitPhotoRadius,
                      ),
                      child: LoadingOverlay(label: _l10n.generatingEllipsis),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildVersionIndicator(),
      ],
    );
  }

  /// Until Save, a new outfit is discarded via "Don't Save" on leave.
  bool get _isSaved => !widget.isNew || _saved;

  bool get _canAddVersion => _isSaved && widget.showEditOutfitWhenSaved;

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

  Widget _buildRegenerateBadge() {
    return CardCornerBadge(
      icon: Icons.refresh,
      backgroundColor: AppColors.surfaceTranslucent,
      iconColor: AppColors.hintText,
      border: Border.all(color: AppColors.borderSubtle),
      boxShadow: const [],
      size: 36,
      iconSize: 20,
      discAlignment: Alignment.topRight,
      onTap: _regenerateImage,
    );
  }

  Widget _buildVersionMenuButton() {
    return AppPopupMenu<_VersionMenuAction>(
      onSelected: _handleVersionMenuAction,
      items: [
        if (_hasMultipleVersions)
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
        if (_hasMultipleVersions)
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
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceTranslucent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Icon(
          Icons.more_horiz,
          size: 20,
          color: AppColors.hintText,
        ),
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
    return OutfitGarmentSection(
      garments: _garments,
      garmentCount: _current.garmentIds.length,
      isLoading: _isLoadingGarments && !_isRegenerating,
      onGarmentTap: _openGarmentDetail,
    );
  }

  /// A garment restored from the dialog ("Add Back to Closet") is swapped
  /// in locally so its warning badge clears without a re-fetch.
  Future<void> _openGarmentDetail(Garment g) async {
    final restored = await GarmentDetailDialog.show(context, g);
    if (restored == null || !mounted) return;
    ref.read(garmentsProvider.notifier).updateGarment(restored);
    setState(() {
      _garments = _garments
          ?.map((existing) => existing.id == restored.id ? restored : existing)
          .toList();
    });
  }

  Future<void> _fetchOutfitDetails() async {
    try {
      final outfit = await OutfitService().getOutfit(
        widget.outfit.groupId,
        widget.outfit.id,
      );
      if (!mounted) return;
      // isNew never loads sibling versions.
      setState(() => _versions[0] = outfit);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isResolvingSavedStatus = false);
    }
  }

  /// Called from several uncoordinated places; skips the fetch (and its
  /// loading flicker) when the id set is already loaded.
  Future<void> _loadGarments() async {
    final idsToLoad = _current.garmentIds.toSet();
    if (_garments != null && setEquals(_loadedGarmentIds, idsToLoad)) return;

    setState(() => _isLoadingGarments = true);
    try {
      final garments = await loadOutfitGarments(
        idsToLoad,
        cached: ref.read(garmentsProvider).value ?? const [],
        outfitId: _current.id,
      );
      if (mounted) {
        setState(() {
          _garments = garments;
          _loadedGarmentIds = idsToLoad;
        });
      }
    } catch (e) {
      debugLog('Failed to load garments for outfit ${_current.id}: $e');
    } finally {
      if (mounted) setState(() => _isLoadingGarments = false);
    }
  }

  /// The outfit is already persisted; this only confirms, without leaving.
  void _save() {
    if (_saved) return;
    setState(() => _saved = true);
    ref.read(outfitsProvider.notifier).refresh();
    showFeedbackOverlay(context, message: _l10n.outfitSaved);
  }

  /// Pops `true` on Save so Add Outfit shows its confirmation; Don't Save
  /// deletes the whole group first.
  Future<void> _leaveNewOutfit() async {
    if (_saved) {
      Navigator.pop(context);
      return;
    }

    final choice = await showSaveChangesDialog(
      context,
      title: _l10n.saveOutfitPromptTitle,
      body: _l10n.saveOutfitPromptBody,
    );
    if (!mounted || choice == SaveChangesChoice.cancel) return;

    if (choice == SaveChangesChoice.save) {
      ref.read(outfitsProvider.notifier).refresh();
      Navigator.pop(context, true);
      return;
    }

    setState(() => _isLeaving = true);
    try {
      await OutfitService().deleteGroup(widget.outfit.groupId);
      if (!mounted) return;
      for (final version in _versions) {
        ref.read(outfitsProvider.notifier).removeOutfit(version.id);
      }
      Navigator.pop(context, false);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('OutfitDetailsPage._leaveNewOutfit failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.outfitDeleteFailed),
      );
    } finally {
      if (mounted) setState(() => _isLeaving = false);
    }
  }

  /// App-bar Delete: always the whole group.
  Future<void> _deleteOutfit() => _confirmThenDeleteGroup();

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
      debugLog('OutfitDetailsPage._confirmThenDeleteGroup failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.outfitDeleteFailed),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// Deletes only the shown version; the last one takes the group with it.
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
      // Not removeOutfit: if [target] was the group's card representative,
      // the card must switch to another version, not disappear. Unawaited:
      // the list re-fetch mustn't keep this page's actions disabled.
      unawaited(ref.read(outfitsProvider.notifier).refresh());
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      debugLog('OutfitDetailsPage._deleteThisOutfit failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.outfitDeleteFailed),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String get _title => outfitDisplayTitle(
    _l10n,
    groupName: _primary.groupName,
    name: _primary.name,
    seasons: _effectiveSeasons,
    style: _effectiveStyle,
  );

  Future<void> _showRenameDialog() async {
    final result = await showTextInputDialog(
      context,
      title: _l10n.renameOutfit,
      hint: _l10n.outfitNameLabel,
      initialValue: _title,
    );

    if (result == null || !mounted) return;
    try {
      await OutfitService().updateGroup(_primary.groupId, name: result);
      if (!mounted) return;
      // Group-level: every version shares it.
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
      debugLog('OutfitDetailsPage rename failed: $e');
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.outfitUpdateFailed),
      );
    }
  }
}
