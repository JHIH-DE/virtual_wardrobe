import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../core/providers/points_provider.dart';
import '../../../core/providers/daily_outfit_provider.dart';
import '../../../core/providers/garments_provider.dart';
import '../../../core/providers/outfits_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/services/base_service.dart';
import '../../../core/services/outfit_service.dart';
import '../../../core/services/pending_try_on_store.dart';
import '../../../core/utils/api_error_text.dart';
import '../../../core/utils/debug_log.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../core/utils/image_cache_bust.dart';
import '../../../core/utils/outfit_garments.dart';
import '../../../core/utils/remaining_points.dart';
import '../../../core/utils/try_on_request.dart';
import '../../../data/garment.dart';
import '../../../data/outfit.dart';
import '../../../data/outfit_group.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_popup_menu.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/accent_pill_button.dart';
import '../../widgets/common/buttons/bottom_action_button.dart';
import '../../widgets/common/cards/card_corner_badge.dart';
import '../../widgets/common/carousel_dots_indicator.dart';
import '../../widgets/common/images/fullscreen_image_viewer.dart';
import '../../widgets/common/images/refreshable_network_image.dart';
import '../../widgets/common/overlays/ai_consent_dialog.dart';
import '../../widgets/common/overlays/confirm_dialog.dart';
import '../../widgets/common/overlays/error_dialog.dart';
import '../../widgets/common/overlays/feedback_overlay.dart';
import '../../widgets/common/overlays/loading_overlay.dart';
import '../../widgets/common/overlays/save_changes_dialog.dart';
import '../../widgets/common/overlays/text_input_dialog.dart';
import '../../widgets/common/overlays/try_on_dialogs.dart';
import '../../widgets/garment/garment_detail_dialog.dart';
import '../../widgets/outfit/outfit_garment_section.dart';
import '../../widgets/outfit/outfit_image.dart';
import '../../widgets/outfit/outfit_share_sheet.dart';
import '../../widgets/outfit/outfit_tag_row.dart';
import '../../widgets/outfit/outfit_tags_sheet.dart';
import '../../widgets/outfit/outfit_title.dart';
import 'create_outfit_page.dart';

enum _OutfitMenuAction { showAllVersions, rename, share, delete }

enum _VersionMenuAction { setCover, regenerate, delete }

class OutfitDetailsPage extends ConsumerStatefulWidget {
  final Outfit outfit;

  /// [outfit]'s group when the caller already has it (the Outfits list):
  /// every version shows at once instead of after a fetch.
  final OutfitGroup? group;

  /// Set when opened from a filtered Outfits list (with [group]): only the
  /// versions it accepts show, until the menu's Clear Filter.
  final bool Function(Outfit version)? versionFilter;

  /// Freshly rendered from Add Outfit: shows a "Save" action, and leaving
  /// before saving prompts (Don't Save deletes the whole group).
  final bool isNew;

  /// False for entry points (e.g. Trip Details) that shouldn't offer
  /// "+ New Version".
  final bool showEditOutfitWhenSaved;

  const OutfitDetailsPage({
    super.key,
    required this.outfit,
    this.group,
    this.versionFilter,
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
  // Only the latest [_loadGarments] may apply: a swipe/animation loads every
  // page it passes, and those loads can land out of order.
  int _garmentsRequest = 0;
  // The id set the latest in-flight load is fetching; only read while
  // [_isLoadingGarments].
  Set<int>? _loadingGarmentIds;
  // The latest load failed; [_garments] is cleared so another version's
  // set isn't shown under this photo.
  Object? _garmentsError;
  // Guards against re-entering _openCreateAnotherVersion.
  bool _isAddingVersion = false;
  // [isNew] only: Save was tapped, so leaving no longer prompts.
  bool _saved = false;
  bool _isRegenerating = false;
  // Held from the tap until the flow ends, so a tap during its confirm or
  // consent check (before [_isRegenerating] is set) opens no second confirm.
  bool _isRegenerateFlowActive = false;
  // The last regenerate's key while its outcome is unknown: retrying the same
  // outfit reuses it, so a backend that honours keys replays instead of
  // rendering again.
  String? _regenerateKey;
  int? _regenerateKeyOutfitId;
  bool _regenerateStatusUnavailable = false;
  bool _isSettingCover = false;
  bool _isTogglingFavorite = false;
  // Keeps the tag button disabled so two tag saves can't race.
  bool _isSavingTags = false;

  // Seeded with widget.outfit, replaced by [_loadGroupOutfits].
  late final List<Outfit> _versions = [widget.outfit];

  static const int _maxVersions = 10;
  int _currentIndex = 0;
  late final PageController _pageController = PageController(
    initialPage: _currentIndex,
  );

  // False until [_loadGroupOutfits] resolves, so the counter / version-only
  // menu items don't pop in after a single-version first render.
  bool _versionsResolved = false;

  /// Ids of the versions in the carousel when [OutfitDetailsPage.
  /// versionFilter] hides some; null shows all. Versions added here join it,
  /// and an edited version stays until the page closes.
  Set<int>? _shownIds;

  /// The carousel's versions; [_currentIndex] indexes this. Version limits,
  /// cover and delete still go by the whole group in [_versions].
  List<Outfit> get _shown => _shownIds == null
      ? _versions
      : [
          for (final v in _versions)
            if (_shownIds!.contains(v.id)) v,
        ];

  /// The version shown in the carousel; photo, favorite, garments and the
  /// version actions apply to it.
  Outfit get _current => _shown[_currentIndex];

  /// [_current]'s position in [_versions].
  int get _currentVersionIndex =>
      _versions.indexWhere((v) => v.id == _current.id);

  // Group-level, from [OutfitDetailsPage.group] or the group fetch.
  String? _groupName;
  int? _coverOutfitId;

  /// The group's representative (same pick as [OutfitGroup.cover]),
  /// so the title doesn't change per swipe.
  Outfit get _primary => groupRepresentative(_versions, _coverOutfitId);

  List<String> get _effectiveSeasons => _current.seasons;
  List<String> get _effectiveStyle => _current.style;

  /// Gates "Set as Cover" / "Delete This Version"; with one version the
  /// app-bar Delete already covers deleting the group.
  bool get _hasMultipleVersions => _versionsResolved && _versions.length >= 2;

  bool get _atVersionLimit => _versions.length >= _maxVersions;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    if (!widget.isNew && group != null && group.versions.isNotEmpty) {
      final versions = group.versions;
      _groupName = group.name;
      _coverOutfitId = group.coverOutfitId;
      _versions
        ..clear()
        ..addAll(versions);
      final filter = widget.versionFilter;
      if (filter != null) {
        final ids = {
          widget.outfit.id,
          for (final v in versions)
            if (filter(v)) v.id,
        };
        if (ids.length < versions.length) _shownIds = ids;
      }
      _currentIndex = math.max(
        0,
        _shown.indexWhere((o) => o.id == widget.outfit.id),
      );
      _versionsResolved = true;
    }
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
      final group = await OutfitService().getOutfitGroup(widget.outfit.groupId);
      final outfits = group.versions;
      if (!mounted) return;
      if (outfits.isEmpty) {
        setState(() => _versionsResolved = true);
        return;
      }
      // Order isn't guaranteed; stay on the version showing.
      final currentId = _current.id;
      final filter = widget.versionFilter;
      setState(() {
        _groupName = group.name;
        _coverOutfitId = group.coverOutfitId;
        _versions
          ..clear()
          ..addAll(outfits);
        if (_shownIds != null && filter != null) {
          _shownIds!.addAll([
            for (final v in outfits)
              if (filter(v)) v.id,
          ]);
        }
        final matchedIndex = _shown.indexWhere((o) => o.id == currentId);
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
          canPop: (!widget.isNew || _saved) && !_isRegenerating,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            // A system back mid-render takes the same Stop Waiting confirm.
            if (_isRegenerating) {
              _stopWaitingForRegenerate();
            } else {
              _leaveNewOutfit();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.pageBackground,
            extendBody: true,
            appBar: _buildAppBar(),
            body: Builder(
              builder: (bodyContext) => ListView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  _showsBottomActionButton
                      ? BottomActionButton.scrollClearance(bodyContext)
                      : 24 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 4),
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
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.deletingOutfitEllipsis),
          ),
      ],
    );
  }

  AppToolBar _buildAppBar() {
    final items = [
      if (_shownIds != null)
        AppPopupMenu.item(
          value: _OutfitMenuAction.showAllVersions,
          icon: const Icon(
            Icons.filter_alt_off_outlined,
            size: 20,
            color: AppColors.icon,
          ),
          label: _l10n.outfitVersionsClearFilter,
        ),
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
            color: AppColors.error,
          ),
          label: _l10n.deleteOutfitTitle,
          isDestructive: true,
        ),
    ];
    return AppToolBar(
      title: _title,
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
      case _OutfitMenuAction.showAllVersions:
        _showAllVersions();
        break;
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
  /// At [_maxVersions] the pill is disabled.
  Future<void> _openCreateAnotherVersion() async {
    if (_isAddingVersion || _atVersionLimit) return;
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
      _shownIds?.add(outfit.id);
      _currentIndex = _shown.length - 1;
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

  Widget _buildInfoCard() {
    return OutfitTagsHeader(
      style: _effectiveStyle,
      temperatureMinC: _current.suitableTempMinC,
      temperatureMaxC: _current.suitableTempMaxC,
      onEdit: _isSavingTags ? null : _openEditTagsSheet,
    );
  }

  /// Auto-saves on close if the selection changed. The target version is
  /// captured up front so a swipe while the sheet is open can't retarget it.
  Future<void> _openEditTagsSheet() async {
    if (_isSavingTags) return;
    final target = _current;
    final index = _currentVersionIndex;
    final edits = await showOutfitTagsSheet(context, target);
    if (edits == null || !mounted) return;
    await _saveTags(index, target, edits);
  }

  /// Optimistic; a failure rolls back to [target] and offers Retry.
  Future<void> _saveTags(int index, Outfit target, OutfitTagEdits edits) async {
    final updated = target.copyWith(
      style: edits.style,
      suitableTemperature: optimisticOutfitTemperature(
        target,
        edits.temperature,
      ),
    );
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
      final saved = await OutfitService().updateOutfit(
        target.groupId,
        target.id,
        style: edits.style,
        suitableTemperature: edits.temperature,
      );
      // Going back to automatic is only known from the reply.
      final settled = updated.copyWith(
        suitableTemperature: saved.suitableTemperature,
      );
      if (mounted &&
          index < _versions.length &&
          identical(_versions[index], updated)) {
        setState(() => _versions[index] = settled);
      }
      outfits.updateOutfitTags(
        target.id,
        style: edits.style,
        suitableTemperature: settled.suitableTemperature,
      );
      dailyOutfits.updateOutfit(settled);
    } on AuthExpiredException {
      if (!mounted) return;
      setState(rollBack);
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
      if (mounted) setState(rollBack);
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
    if (retry && mounted) await _saveTags(index, target, edits);
  }

  void _shareOutfit() {
    showOutfitShareSheet(
      context,
      imageUrl: _current.imageUrl,
      name: _title,
      style: [for (final s in _effectiveStyle) outfitTagLabel(_l10n, s)],
      seasons: [for (final s in _effectiveSeasons) outfitTagLabel(_l10n, s)],
      garmentImageUrls: [
        for (final g in _garments ?? const <Garment>[])
          if ((g.imageUrl ?? '').isNotEmpty) g.imageUrl!,
      ],
    );
  }

  Future<String?> _refreshImageUrlFor(Outfit outfit) async {
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
      outfits.updateOutfitFavorite(target.id, isFavorite: next);
      dailyOutfits.updateOutfit(updated);
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => setFavorite(!next));
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
      if (mounted) setState(() => setFavorite(!next));
    } catch (_) {
      if (!mounted) return;
      setState(() => setFavorite(!next));
      showErrorDialog(context, message: _l10n.failedToUpdateFavorite);
    } finally {
      if (mounted) setState(() => _isTogglingFavorite = false);
    }
  }

  Future<void> _setCover() async {
    if (_isSettingCover) return;
    final target = _current;
    final previous = _coverOutfitId;
    setState(() {
      _isSettingCover = true;
      _coverOutfitId = target.id;
    });
    try {
      await OutfitService().updateGroup(
        target.groupId,
        coverOutfitId: target.id,
      );
      unawaited(ref.read(outfitsProvider.notifier).refresh());
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => _coverOutfitId = previous);
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
      if (!mounted) return;
      setState(() => _coverOutfitId = previous);
    } catch (e) {
      if (!mounted) return;
      debugLog('OutfitDetailsPage._setCover failed: $e');
      setState(() => _coverOutfitId = previous);
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
    if (_isRegenerating || _isRegenerateFlowActive) return;
    _isRegenerateFlowActive = true;
    try {
      await _confirmAndRegenerate();
    } finally {
      _isRegenerateFlowActive = false;
    }
  }

  Future<void> _confirmAndRegenerate() async {
    final target = _current;
    final retryingUnknown = _regenerateKeyOutfitId == target.id;

    // Re-asking a backend that can't report status may render again; that
    // dialog already says so, in place of the plain confirm.
    final ok = retryingUnknown && _regenerateStatusUnavailable
        ? await showRetryWhileUnknownDialog(context)
        : await showConfirmDialog(
            context,
            title: _l10n.regenerateOutfitConfirmTitle,
            body: _l10n.regenerateOutfitConfirmBody,
            confirmLabel: _l10n.regenerate,
          );
    if (!ok || !mounted) return;
    if (!await ensureAiConsent(context) || !mounted || _isRegenerating) return;

    final key = retryingUnknown && !_regenerateStatusUnavailable
        ? _regenerateKey!
        : newIdempotencyKey();
    final index = _currentVersionIndex;
    // All read before the await: the page may be gone when it lands.
    final overlay = Overlay.of(context, rootOverlay: true);
    final points = ref.read(pointsProvider.notifier);
    final l10n = _l10n;
    final outfits = ref.read(outfitsProvider.notifier);
    final session = PendingTryOnStore.session;
    setState(() => _isRegenerating = true);
    try {
      final outfit = await sendKeyedTryOn(
        key: key,
        session: session,
        regeneratedOutfitId: target.id,
        send: () => OutfitService().regenerateOutfit(
          target.groupId,
          target.id,
          idempotencyKey: key,
        ),
      );
      _regenerateKey = null;
      _regenerateKeyOutfitId = null;
      if (PendingTryOnStore.session == session) {
        // The image is overwritten at the same URL, so bump the cache key
        // every consumer reads or they keep serving the old bytes.
        ImageCacheBust.bump(outfitImageCacheKey(target.id));
        unawaited(outfits.refresh());
        unawaited(announceRemainingPoints(overlay, l10n, points));
      }
      if (!mounted) return;
      setState(() => _versions[index] = outfit);
    } on TryOnStillRunning catch (e) {
      _regenerateKey = key;
      _regenerateKeyOutfitId = target.id;
      _regenerateStatusUnavailable = e.statusUnavailable;
      if (!mounted) return;
      showErrorDialog(
        context,
        message: e.statusUnavailable
            ? _l10n.tryOnOutcomeUnknown
            : _l10n.tryOnStillRendering(_l10n.regenerate),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended before the outcome was known: not a failure. Kept
      // like an unknown outcome, so a retry here replays this key.
      _regenerateKey = key;
      _regenerateKeyOutfitId = target.id;
      _regenerateStatusUnavailable = false;
    } catch (e) {
      // Definitive: the next attempt is a new request (its quota was
      // released).
      _regenerateKey = null;
      _regenerateKeyOutfitId = null;
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

  /// Leaves mid-regenerate; the render goes on and is applied if it lands.
  Future<void> _stopWaitingForRegenerate() async {
    final stop = await showStopWaitingDialog(context);
    if (!stop || !mounted || !_isRegenerating) return;
    Navigator.pop(context);
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
                  itemCount: _shown.length,
                  itemBuilder: (_, index) {
                    final outfit = _shown[index];
                    // Survives URL re-signing; versioned by _regenerateImage.
                    final cacheKey = outfit.displayImageCacheKey;
                    return GestureDetector(
                      onTap: () => showFullscreenImage(
                        context,
                        imageUrl: outfit.imageUrl,
                        cacheKey: cacheKey,
                        onRefreshUrl: () => _refreshImageUrlFor(outfit),
                      ),
                      child: RefreshableNetworkImage(
                        key: ValueKey(cacheKey),
                        imageUrl: outfit.imageUrl,
                        cacheKey: cacheKey,
                        fit: BoxFit.cover,
                        errorLabel: _l10n.failedToLoadImage,
                        onRefreshUrl: () => _refreshImageUrlFor(outfit),
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
                      enabled: !_isAddingVersion && !_atVersionLimit,
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
                      child: LoadingOverlay(
                        label: _l10n.generatingTryOnEllipsis,
                        actionLabel: _l10n.stopWaiting,
                        onAction: _stopWaitingForRegenerate,
                        frosted: true,
                      ),
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
    final shown = _shown;
    if (!_versionsResolved || shown.length < 2) {
      return const SizedBox(height: AppDimens.sectionSpacing);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: AppDimens.sectionSpacing),
      child: CarouselDotsIndicator(
        count: shown.length,
        currentIndex: _currentIndex,
      ),
    );
  }

  void _showAllVersions() {
    setState(() {
      _currentIndex = _currentVersionIndex;
      _shownIds = null;
    });
    if (_pageController.hasClients) _pageController.jumpToPage(_currentIndex);
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
              color: AppColors.error,
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
      error: _garmentsError,
      onRetry: _loadGarments,
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
  /// loading flicker) when the id set is already loaded or being loaded.
  Future<void> _loadGarments() async {
    final outfitId = _current.id;
    final idsToLoad = _current.garmentIds.toSet();
    // The latest load already fetches this set: let it land instead of
    // superseding it with an identical fetch.
    if (_isLoadingGarments && setEquals(_loadingGarmentIds, idsToLoad)) return;
    // Bumped before the early return too, so a load still in flight for
    // another version can't overwrite the set already showing.
    final request = ++_garmentsRequest;
    if (_garments != null && setEquals(_loadedGarmentIds, idsToLoad)) {
      if (_isLoadingGarments) setState(() => _isLoadingGarments = false);
      return;
    }

    _loadingGarmentIds = idsToLoad;
    setState(() {
      _isLoadingGarments = true;
      _garmentsError = null;
    });
    try {
      final garments = await loadOutfitGarments(
        idsToLoad,
        cached: ref.read(garmentsProvider).value ?? const [],
        outfitId: outfitId,
      );
      if (mounted && request == _garmentsRequest) {
        setState(() {
          _garments = garments;
          _loadedGarmentIds = idsToLoad;
        });
      }
    } on AuthExpiredException {
      if (mounted && request == _garmentsRequest) {
        await AuthExpiredHandler.handle(context);
      }
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
    } catch (e) {
      debugLog('Failed to load garments for outfit $outfitId: $e');
      if (mounted && request == _garmentsRequest) {
        setState(() {
          _garments = null;
          _loadedGarmentIds = null;
          _garmentsError = e;
        });
      }
    } finally {
      if (mounted && request == _garmentsRequest) {
        setState(() => _isLoadingGarments = false);
      }
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
      ref.read(outfitsProvider.notifier).removeGroup(widget.outfit.groupId);
      Navigator.pop(context, false);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
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
    final ok = await showConfirmDialog(
      context,
      title: _l10n.deleteOutfitTitle,
      body: _l10n.deleteOutfitGroupConfirmation,
      confirmLabel: _l10n.delete,
      destructive: true,
    );
    if (ok != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await OutfitService().deleteGroup(widget.outfit.groupId);
      ref.read(outfitsProvider.notifier).removeGroup(widget.outfit.groupId);
      final feedback = ref.read(outfitFeedbackProvider.notifier);
      if (mounted) Navigator.pop(context);
      feedback.state = OutfitFeedbackKind.deleted;
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
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
    final ok = await showConfirmDialog(
      context,
      title: _l10n.deleteOutfitTitle,
      body: _l10n.deleteOutfitConfirmation,
      confirmLabel: _l10n.delete,
      destructive: true,
    );
    if (ok != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await OutfitService().deleteOutfit(target.groupId, target.id);
      if (!mounted) return;
      setState(() {
        _versions.remove(target);
        // The last shown version is gone: show the rest of the group.
        if (_shownIds != null && _shown.isEmpty) _shownIds = null;
        _currentIndex = _currentIndex.clamp(0, _shown.length - 1);
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentIndex);
      }
      _loadGarments();
      // Re-fetched so the card shows the backend's cover once [target] was
      // it. Unawaited: the list re-fetch mustn't keep this page's actions
      // disabled.
      unawaited(ref.read(outfitsProvider.notifier).refresh());
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
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
    groupName: _groupName,
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
      setState(() => _groupName = result);
      ref
          .read(outfitsProvider.notifier)
          .updateGroupName(_primary.groupId, name: result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
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
