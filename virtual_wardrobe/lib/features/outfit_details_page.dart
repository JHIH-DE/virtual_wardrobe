import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/providers/outfits_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../core/services/outfit_service.dart';
import '../core/utils/signed_url.dart';
import '../data/outfit_version_result.dart';
import '../data/garment.dart';
import '../data/outfit.dart';
import '../l10n/generated/app_localizations.dart';
import 'add_outfit_page.dart';
import 'widgets/common/app_dialog.dart';
import 'widgets/common/app_text_field.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/card_corner_badge.dart';
import 'widgets/common/floating_nav_bar.dart';
import 'widgets/common/labeled_divider.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/common/refreshable_network_image.dart';
import 'widgets/garment/garment_detail_dialog.dart';
import 'widgets/garment/garment_list_card.dart';
import 'widgets/outfit/outfit_image.dart';

enum _OutfitMenuAction { rename, share, regenerate, delete }

/// One image shown in Outfit Details' carousel. [lookId] is null for the
/// outfit's own base image (index 0) — its `look_id` isn't captured
/// client-side, so unlike appended Create Look entries it can't be
/// individually deleted via [OutfitService.deleteLook].
class _OutfitLookEntry {
  final String imageUrl;
  final int? lookId;
  // This specific look's accessories — not the outfit's fixed core combo,
  // since accessories are picked per-look. Drives the Garment list so it
  // reflects whichever look is currently shown, not every look ever
  // generated.
  final List<int> accessoryGarmentIds;
  const _OutfitLookEntry(
    this.imageUrl, {
    this.lookId,
    this.accessoryGarmentIds = const [],
  });
}

class OutfitDetailsPage extends ConsumerStatefulWidget {
  final Outfit outfit;
  final bool isNew;

  /// When [isNew] is true, back normally prompts to save/discard before
  /// leaving. Set this to false to skip that prompt and pop straight back
  /// (e.g. when the outfit is a daily outfit that already exists
  /// server-side, so there's nothing unsaved to lose).
  final bool confirmLeaveOnBack;

  /// After tapping "Save Outfit", whether to jump to the Outfits tab
  /// (popping back to the shell root) or just pop this page. Jumping to
  /// Outfits makes sense when the outfit was created standalone (Home / Add
  /// Outfit), but not when it was opened from a specific flow like Trip
  /// Details, where the user expects Save to return them to what they were
  /// doing.
  final bool navigateToOutfitsTabOnSave;

  /// Once the outfit is saved, whether to still offer the "Edit Outfit"
  /// entry card. Set this to false for entry points (e.g. Trip Details)
  /// where a saved outfit shouldn't offer to be edited from here — the card
  /// is hidden entirely in that case instead.
  final bool showEditOutfitWhenSaved;

  const OutfitDetailsPage({
    super.key,
    required this.outfit,
    this.isNew = false,
    this.confirmLeaveOnBack = true,
    this.navigateToOutfitsTabOnSave = true,
    this.showEditOutfitWhenSaved = true,
  });

  @override
  ConsumerState<OutfitDetailsPage> createState() => _OutfitDetailsPageState();
}

class _OutfitDetailsPageState extends ConsumerState<OutfitDetailsPage> {
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isSaved = false;
  // True while we're waiting on _fetchOutfitDetails to confirm the real
  // isSaved status for entry points that hide the bar once saved — avoids
  // flashing the "Save Outfit" button before we know it's already saved.
  bool _resolvingSavedStatus = false;
  String? _name;
  List<String>? _seasons;
  List<String>? _style;
  List<Garment>? _garments;
  bool _loadingGarments = false;
  bool _openingTryOn = false;
  bool _isRegenerating = false;

  // Starts with just the outfit's own image (index 0); each completed
  // Create Look flow appends its generated image here. Purely client-side
  // — this list doesn't persist across app restarts (the outfit's full
  // `looks[]` history lives on the backend, but this page doesn't fetch it).
  late final List<_OutfitLookEntry> _outfitImages = [
    _OutfitLookEntry(widget.outfit.imageUrl),
  ];
  final PageController _outfitImagePageController = PageController();
  int _currentImageIndex = 0;

  List<String> get _effectiveSeasons => _seasons ?? widget.outfit.seasons;
  List<String> get _effectiveStyle => _style ?? widget.outfit.style;
  bool get _shouldConfirmLeave => widget.isNew && widget.confirmLeaveOnBack;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _name = widget.outfit.name;
    _isSaved = widget.outfit.isSaved;
    if (widget.outfit.garmentIds.isNotEmpty) _loadGarments();
    if (widget.isNew) {
      _resolvingSavedStatus = !widget.showEditOutfitWhenSaved;
      _fetchOutfitDetails();
    }
    // A freshly-created outfit's URL was just signed, but one opened from a
    // list (outfits_page.dart, garment_outfits_page.dart) may have sat in
    // memory long enough for its signed URL to expire — and this also picks
    // up any earlier-generated looks the backend already has for this
    // outfit, since the carousel otherwise only ever shows what's been
    // generated in the current page instance.
    if (!widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLookHistory());
    }
  }

  @override
  void dispose() {
    _outfitImagePageController.dispose();
    super.dispose();
  }

  /// Replaces the single placeholder image ([widget.outfit.imageUrl]) with
  /// this outfit's full look history from the backend — otherwise the
  /// carousel only ever shows what's been generated in *this* page
  /// instance, since [_outfitImages] itself is purely client-side and never
  /// persists across navigations.
  Future<void> _loadLookHistory() async {
    try {
      final data = await OutfitService().getOutfit(widget.outfit.id);
      final entries = allLooksOf(data)
          .map((look) {
            final url = look['result_image_url'] as String?;
            if (url == null || url.isEmpty) return null;
            final rawAccessoryIds = look['accessory_garment_ids'];
            return _OutfitLookEntry(
              url,
              lookId: look['look_id'] as int?,
              accessoryGarmentIds: rawAccessoryIds is List
                  ? rawAccessoryIds.whereType<int>().toList()
                  : const [],
            );
          })
          .whereType<_OutfitLookEntry>()
          .toList();
      if (!mounted || entries.isEmpty) return;
      setState(() {
        _outfitImages
          ..clear()
          ..addAll(entries);
        _currentImageIndex = 0;
      });
      _loadGarments();
    } catch (_) {
      // Leave the single placeholder image already showing.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(context),
        if (_openingTryOn)
          Positioned.fill(child: LoadingOverlay(label: _l10n.loadingGarments)),
        if (_isRegenerating)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingEllipsis),
          ),
      ],
    );
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _title,
      onBack: _shouldConfirmLeave ? _showLeaveDialog : null,
      actions: [
        if (!widget.isNew)
          PopupMenuButton<_OutfitMenuAction>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, color: AppColors.icon),
            color: AppColors.surface,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              _menuItem(
                _OutfitMenuAction.rename,
                Icons.edit_outlined,
                _l10n.rename,
              ),
              _menuItem(
                _OutfitMenuAction.share,
                Icons.share_outlined,
                _l10n.share,
              ),
              PopupMenuItem(
                value: _OutfitMenuAction.regenerate,
                enabled: !_isRegenerating,
                child: Row(
                  children: [
                    const Icon(Icons.refresh, color: AppColors.icon),
                    const SizedBox(width: 12),
                    Text(_l10n.regenerate),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _OutfitMenuAction.delete,
                enabled: !_isDeleting,
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: AppColors.icon),
                    const SizedBox(width: 12),
                    Text(
                      _l10n.delete,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  PopupMenuItem<_OutfitMenuAction> _menuItem(
    _OutfitMenuAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppColors.icon),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _handleMenuAction(_OutfitMenuAction action) {
    switch (action) {
      case _OutfitMenuAction.rename:
        _showEditNameDialog();
        break;
      case _OutfitMenuAction.share:
        _shareOutfit();
        break;
      case _OutfitMenuAction.regenerate:
        _regenerateOutfit();
        break;
      case _OutfitMenuAction.delete:
        _deleteOutfit();
        break;
    }
  }

  Widget _buildScaffold(BuildContext context) {
    return PopScope(
      canPop: !_shouldConfirmLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showLeaveDialog();
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        extendBody: true,
        appBar: _buildAppBar(),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            _buildOutfitImage(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 12),
            if (widget.outfit.garmentIds.isNotEmpty) ...[
              _buildGarmentSection(),
            ],
            _buildCreateDateFooter(),
            if (_showsBottomActionButton) const SizedBox(height: 60),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (_resolvingSavedStatus) return const SizedBox.shrink();

    if (widget.isNew && !_isSaved) {
      return BottomActionButton(
        label: _l10n.saveOutfit,
        onPressed: _isSaving ? null : _saveOutfit,
        isLoading: _isSaving,
      );
    }

    if (!_showSavedOutfitActions) return const SizedBox.shrink();

    return BottomActionButton(
      label: _l10n.createAnotherVersion,
      leading: const Icon(Icons.edit_outlined),
      onPressed: _openCreateAnotherVersion,
    );
  }

  /// True whenever [_buildBottomBar] actually renders a [BottomActionButton]
  /// (as opposed to a shrunk placeholder) — used to only reserve the extra
  /// bottom clearance in the scrollable body when there's a real bar
  /// underneath it that could otherwise cover the date footer.
  bool get _showsBottomActionButton =>
      !_resolvingSavedStatus &&
      ((widget.isNew && !_isSaved) || _showSavedOutfitActions);

  /// Mirrors the old bottom-bar visibility rule: only once the outfit is
  /// actually saved (either opened as an existing outfit, or freshly
  /// saved), and not for entry points that opt out via
  /// [OutfitDetailsPage.showEditOutfitWhenSaved].
  bool get _showSavedOutfitActions =>
      !_resolvingSavedStatus &&
      !(widget.isNew && !_isSaved) &&
      !(_isSaved && !widget.showEditOutfitWhenSaved);

  /// Opens Add Outfit in "Create Another Version" mode — its bottom button
  /// calls `createLook` on this same outfit instead of creating a new one
  /// (see [AddOutfitPage.existingOutfit]). Never touches this outfit/look
  /// directly; the returned image (if any) is appended to [_outfitImages]
  /// as a new carousel entry.
  Future<void> _openCreateAnotherVersion() async {
    setState(() => _openingTryOn = true);
    try {
      final closetGarments = await ref.read(garmentsProvider.future);
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (!context.mounted) return;
      final result = await Navigator.push<OutfitVersionResult>(
        context,
        MaterialPageRoute(
          builder: (_) => AddOutfitPage(
            // Carries the live (possibly renamed this session) name — see
            // AddOutfitPage's title, which shows it in existingOutfit mode.
            existingOutfit: widget.outfit.copyWith(name: _name),
            initialGarments: _garments ?? const [],
            preloadedGarments: closetGarments,
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() {
        _outfitImages.add(
          _OutfitLookEntry(
            result.imageUrl,
            lookId: result.lookId,
            accessoryGarmentIds: result.accessoryGarmentIds,
          ),
        );
        _currentImageIndex = _outfitImages.length - 1;
      });
      _loadGarments();
      await _outfitImagePageController.animateToPage(
        _currentImageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToLoadGarments)));
      }
    }
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Widget _buildInfoCard() {
    final seasons = _effectiveSeasons.map(_titleCase).toList();
    final styles = _effectiveStyle.map(_titleCase).toList();
    final hasTags = seasons.isNotEmpty || styles.isNotEmpty;
    final tagStyle = AppTextStyle.regular14.copyWith(
      color: AppColors.textSecondary,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: hasTags
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (seasons.isNotEmpty)
                  Text(seasons.join(' • '), style: tagStyle),
                if (seasons.isNotEmpty && styles.isNotEmpty)
                  const SizedBox(height: 4),
                if (styles.isNotEmpty)
                  Text(styles.join(' • '), style: tagStyle),
              ],
            )
          : Text(_l10n.myCollection, style: tagStyle),
    );
  }

  Widget _buildCreateDateFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          _l10n.createdOnDate(_formattedDate),
          style: AppTextStyle.bold14.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _shareOutfit() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.shareComingSoon)));
  }

  Future<String?> _refreshOutfitImageUrl() async {
    final fresh = await fetchFreshOutfitImageUrl(widget.outfit.id);
    if (mounted) setState(() => _outfitImages[0] = _OutfitLookEntry(fresh));
    return fresh;
  }

  /// Deletes a single generated look from the carousel. Only entries with a
  /// [_OutfitLookEntry.lookId] are deletable (see [_buildOutfitImage]).
  Future<void> _deleteLook(int index) async {
    // Look 0 (the outfit's primary/original look) is never deletable —
    // only later regenerated variants are.
    if (index == 0) return;
    final lookId = _outfitImages[index].lookId;
    if (lookId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.deleteLookTitle,
        body: _l10n.deleteLookConfirmation,
        primaryLabel: _l10n.delete,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await OutfitService().deleteLook(widget.outfit.id, lookId);
      if (!mounted) return;
      setState(() {
        _outfitImages.removeAt(index);
        if (_currentImageIndex >= _outfitImages.length) {
          _currentImageIndex = _outfitImages.length - 1;
        }
      });
      _loadGarments();
      if (_outfitImagePageController.hasClients) {
        await _outfitImagePageController.animateToPage(
          _currentImageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
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

  Widget _buildOutfitImage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _outfitImagePageController,
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                    // Different looks can have different accessories — keep
                    // the Garment list in sync with whichever is shown now.
                    _loadGarments();
                  },
                  itemCount: _outfitImages.length,
                  // Only the outfit's own image (index 0) can refresh its
                  // signed URL by re-fetching the outfit — appended Look
                  // images don't have an equivalent lookup yet.
                  itemBuilder: (_, index) => RefreshableNetworkImage(
                    imageUrl: _outfitImages[index].imageUrl,
                    // Only index 0 has a stable id (the outfit itself) to
                    // key by — same re-signed-URL-defeats-cache reasoning as
                    // OutfitImage/GarmentImage. Appended images (index > 0)
                    // fall back to the default URL-keyed cache.
                    cacheKey: index == 0
                        ? 'outfit-job-${widget.outfit.id}'
                        : null,
                    fit: BoxFit.cover,
                    placeholderBuilder: (_) =>
                        const Center(child: CircularProgressIndicator()),
                    errorLabel: _l10n.failedToLoadImage,
                    onRefreshUrl: index == 0 ? _refreshOutfitImageUrl : null,
                  ),
                ),
                // Look 0 (the outfit's primary/original look) is never
                // deletable — only later regenerated variants are.
                if (_currentImageIndex != 0 &&
                    _outfitImages[_currentImageIndex].lookId != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: CardCornerBadge(
                      icon: Icons.close,
                      backgroundColor: AppColors.primary,
                      iconColor: AppColors.textOnPrimary,
                      onTap: () => _deleteLook(_currentImageIndex),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildImagePageIndicator(),
      ],
    );
  }

  /// Dots marking which outfit/look photo is shown.
  Widget _buildImagePageIndicator() {
    if (_outfitImages.length < 2) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_outfitImages.length, (index) {
        final isActive = index == _currentImageIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.accent : AppColors.borderSubtle,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildGarmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledDivider(
          label: _l10n.garmentsCount(
            _garments?.length ?? widget.outfit.garmentIds.length,
          ),
        ),
        const SizedBox(height: 16),
        if (_loadingGarments)
          const Center(child: CircularProgressIndicator())
        else if (_garments != null)
          ..._garments!.map(_buildGarmentCard),
      ],
    );
  }

  Widget _buildGarmentCard(Garment g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GarmentListCard(
        garment: g,
        onTap: () => GarmentDetailDialog.show(context, g),
      ),
    );
  }

  Future<void> _fetchOutfitDetails() async {
    try {
      final data = await OutfitService().getOutfit(widget.outfit.id);
      if (!mounted) return;
      setState(() {
        _name = (data['name'] as String?)?.isNotEmpty == true
            ? data['name'] as String
            : _name;
        _seasons = _parseStringList(data['season']);
        _style = _parseStringList(data['style']);
        _isSaved = data['is_saved'] == true || data['is_saved'] == 1;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _resolvingSavedStatus = false);
    }
  }

  List<String> _parseStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return [];
  }

  Map<int, Garment> _indexGarmentsById(List<Garment> garments) {
    return {
      for (final g in garments)
        if (g.id != null) g.id!: g,
    };
  }

  Future<void> _loadGarments() async {
    setState(() => _loadingGarments = true);
    try {
      // Reuse whatever My Closet has already loaded into garmentsProvider
      // instead of always hitting the network per garment — but skip stale
      // cache entries whose signed image URL has expired, so photos don't
      // render as broken images.
      final cached = ref.read(garmentsProvider).valueOrNull ?? const [];
      final cachedById = _indexGarmentsById(cached);
      // Core garments (fixed) + whichever look is currently shown in the
      // carousel's accessories — not every accessory across all looks.
      final currentAccessoryIds = _currentImageIndex < _outfitImages.length
          ? _outfitImages[_currentImageIndex].accessoryGarmentIds
          : const <int>[];
      final idsToLoad = {...widget.outfit.garmentIds, ...currentAccessoryIds};

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
      if (mounted) setState(() => _loadingGarments = false);
    }
  }

  /// Creates a fresh try-on job from the same garments, waits for it to
  /// finish, then deletes the original job — the old outfit is only
  /// removed once the replacement has actually succeeded.
  Future<void> _regenerateOutfit() async {
    if (_isRegenerating) return;
    final garmentIds = widget.outfit.garmentIds;
    if (garmentIds.isEmpty) return;

    setState(() => _isRegenerating = true);
    try {
      final jobResponse = await OutfitService().createOutfit(
        garmentIds: garmentIds,
        type: 'general',
      );
      final newJobId =
          (jobResponse['outfit_id'] ?? jobResponse['job_id']) as int;

      final newOutfitData = await _waitForOutfitCompletion(newJobId);
      if (newOutfitData == null) {
        throw Exception('Regenerate timed out or failed.');
      }

      if (widget.outfit.isSaved) {
        await OutfitService().setSaved(newJobId, isSaved: true);
      }
      // The old job's custom name doesn't carry over server-side, so the
      // new job needs it re-applied explicitly — otherwise it reverts to
      // whatever default the backend assigns a fresh outfit.
      final name = _name;
      if (name != null && name.isNotEmpty) {
        await OutfitService().setName(newJobId, name: name);
      }
      await OutfitService().deleteOutfit(widget.outfit.id);
      await ref.read(outfitsProvider.notifier).refresh();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OutfitDetailsPage(
            outfit: Outfit(
              id: newJobId,
              name: name,
              imageUrl:
                  primaryLookOf(newOutfitData)?['result_image_url'] ??
                  newOutfitData['result_image_url'] ??
                  '',
              garmentIds: garmentIds,
              seasons: _parseStringList(newOutfitData['season']),
              style: _parseStringList(newOutfitData['style']),
              advice:
                  primaryLookOf(newOutfitData)?['ai_notes'] ??
                  newOutfitData['ai_notes'],
              isSaved: widget.outfit.isSaved,
            ),
            navigateToOutfitsTabOnSave: widget.navigateToOutfitsTabOnSave,
            showEditOutfitWhenSaved: widget.showEditOutfitWhenSaved,
          ),
        ),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToRegenerateOutfit)));
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  /// Polls a freshly-created job until it completes (or fails/times out),
  /// mirroring TryOnMixin's polling without pulling in its unrelated state.
  Future<Map<String, dynamic>?> _waitForOutfitCompletion(int jobId) async {
    for (var attempt = 0; attempt < 180; attempt++) {
      final data = await OutfitService().getOutfit(jobId);
      final status = primaryLookOf(data)?['status'] ?? data['status'];
      if (status == 'completed') return data;
      if (status == 'failed') return null;
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<void> _saveOutfit() async {
    setState(() => _isSaving = true);
    try {
      await OutfitService().setSaved(widget.outfit.id, isSaved: true);
      await ref.read(outfitsProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _isSaved = true);
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showLeaveDialog() async {
    if (_isSaved) {
      Navigator.pop(context);
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.saveThisOutfitTitle,
        body: _l10n.saveThisOutfitBody,
        primaryLabel: _l10n.save,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.discard,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (!mounted || save == null) return;

    try {
      if (save) {
        await OutfitService().setSaved(widget.outfit.id, isSaved: true);
        await ref.read(outfitsProvider.notifier).refresh();
      } else {
        await OutfitService().deleteOutfit(widget.outfit.id);
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteOutfit() async {
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
      await OutfitService().deleteOutfit(widget.outfit.id);
      ref.read(outfitsProvider.notifier).removeById(widget.outfit.id);
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

  String get _title {
    if (_name != null && _name!.isNotEmpty) return _name!;
    final parts = [..._effectiveSeasons, ..._effectiveStyle];
    if (parts.isEmpty) return _l10n.myOutfit;
    final word = parts.first;
    final capitalized = word.isEmpty
        ? word
        : '${word[0].toUpperCase()}${word.substring(1)}';
    return _l10n.outfitTitle(capitalized);
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.renameOutfit,
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyle.bold16,
          decoration: appInputDecoration(hint: _l10n.outfitNameLabel),
        ),
        primaryLabel: _l10n.save,
        onPrimary: () => Navigator.pop(ctx, controller.text.trim()),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (result == null || result.isEmpty || !mounted) return;
    try {
      await OutfitService().setName(widget.outfit.id, name: result);
      if (!mounted) return;
      setState(() => _name = result);
      ref
          .read(outfitsProvider.notifier)
          .updateName(widget.outfit.id, name: result);
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

  String get _formattedDate =>
      DateFormat('MMM d, yyyy').format(widget.outfit.createdAt);
}
