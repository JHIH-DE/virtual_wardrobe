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
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/cards/category_tag.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/fields/selectable_chip.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/images/petal_loader.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_list_card.dart';
import '../widgets/outfit/outfit_image.dart';
import 'add_outfit_page.dart';

enum _OutfitMenuAction { rename, share, delete }

enum _VersionMenuAction { regenerate, delete }

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
  // Editorial tag catalog for the Edit Tags sheet — same options
  // outfits_page.dart/garment_outfits_page.dart offer as filters (minus
  // their 'All' sentinel, which doesn't apply to editing an outfit's own
  // tags).
  static const List<String> _seasonOptions = [
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];
  static const List<String> _styleOptions = [
    'Minimal',
    'Street',
    'Classic',
    'Sporty',
  ];
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isSaved = false;
  // True while we're waiting on _fetchOutfitDetails for entry points that
  // hide the action bar once saved — avoids flashing the "Save Outfit"
  // button before the rest of the outfit's details have loaded.
  bool _isResolvingSavedStatus = false;
  List<Garment>? _garments;
  bool _isLoadingGarments = false;
  bool _isOpeningTryOn = false;
  // True while regenerateOutfit's AI render is in flight.
  bool _isRegenerating = false;

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

  /// [_versions] first entry — the app bar title/tags always reflect this
  /// one regardless of which version is currently swiped to, so the header
  /// reads as this outfit *group*'s identity rather than flickering
  /// per-version as the user swipes.
  Outfit get _primary => _versions[0];

  List<String> get _effectiveSeasons => _current.seasons;
  List<String> get _effectiveStyle => _current.style;
  bool get _shouldConfirmLeave => widget.isNew && widget.confirmLeaveOnBack;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    // The backend no longer has an is_saved concept — every outfit is
    // persisted the moment it's created. isNew is what actually means
    // "not yet confirmed kept" here: fresh outfits start unconfirmed (so
    // Save/leave-without-saving can still offer to delete it), anything
    // opened from elsewhere is already real and treated as kept.
    _isSaved = !widget.isNew;
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
      setState(() {
        _versions
          ..clear()
          ..addAll(outfits);
        _currentIndex = 0;
      });
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
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                _showsBottomActionButton
                    ? AppDimens.bottomActionBtnClearance
                    : 30,
              ),
              children: [
                _buildInfoCard(),
                const SizedBox(height: 12),
                _buildOutfitImage(),
                const SizedBox(height: 16),
                if (_current.garmentIds.isNotEmpty) ...[_buildGarmentSection()],
                const SizedBox(height: 8),
              ],
            ),
            bottomNavigationBar: _buildBottomBar(),
          ),
        ),
        if (_isOpeningTryOn)
          Positioned.fill(child: LoadingOverlay(label: _l10n.loadingGarments)),
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
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _OutfitMenuAction.delete,
                enabled: !_isDeleting,
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: AppColors.icon),
                    const SizedBox(width: 12),
                    Text(
                      _l10n.deleteOutfitTitle,
                      style: AppTextStyle.regular14.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
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
          Text(
            label,
            style: AppTextStyle.regular14.copyWith(fontWeight: FontWeight.w500),
          ),
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
      case _OutfitMenuAction.delete:
        _deleteOutfit();
        break;
    }
  }

  Widget _buildBottomBar() {
    if (_isResolvingSavedStatus) return const SizedBox.shrink();

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
      !_isResolvingSavedStatus &&
      ((widget.isNew && !_isSaved) || _showSavedOutfitActions);

  /// Mirrors the old bottom-bar visibility rule: only once the outfit is
  /// actually saved (either opened as an existing outfit, or freshly
  /// saved), and not for entry points that opt out via
  /// [OutfitDetailsPage.showEditOutfitWhenSaved].
  bool get _showSavedOutfitActions =>
      !_isResolvingSavedStatus &&
      !(widget.isNew && !_isSaved) &&
      !(_isSaved && !widget.showEditOutfitWhenSaved);

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOpeningTryOn = false);
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
    final tags = [
      ..._effectiveSeasons.map(_titleCase),
      ..._effectiveStyle.map(_titleCase),
    ];
    final tagStyle = AppTextStyle.regular14.copyWith(
      color: AppColors.textSecondary,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: tags.isEmpty
                ? Text(_l10n.myCollection, style: tagStyle)
                : _buildTagsRow(tags),
          ),
        ],
      ),
    );
  }

  /// Lays out [tags] on a single line, collapsing whatever doesn't fit into
  /// a trailing "+N" tag instead of wrapping to another line.
  Widget _buildTagsRow(List<String> tags) {
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
                  chipGroup(_seasonOptions, selectedSeasons),
                  const SizedBox(height: 24),
                  Text(_l10n.styleLabel, style: AppTextStyle.bold16),
                  const SizedBox(height: 12),
                  chipGroup(_styleOptions, selectedStyles),
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
    final styles = result.styles.map((s) => s.toLowerCase()).toList();
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _versions[index] = target);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateFavorite)));
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
      ImageCacheBust.bump('outfit-job-${target.id}');
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
                    final baseKey = 'outfit-job-${outfit.id}';
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
                if (!_isRegenerating) ...[
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
        _buildImagePageIndicator(),
      ],
    );
  }

  /// Dots marking which version's photo is shown, plus a "current / total"
  /// counter trailing them — hidden entirely when there's only one version.
  Widget _buildImagePageIndicator() {
    if (_versions.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_versions.length, (index) {
                final isActive = index == _currentIndex;
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
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_currentIndex + 1} / ${_versions.length}',
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The photo's own "..." corner menu — Regenerate and Delete this
  /// version for whichever version is currently shown (see
  /// [_deleteThisOutfit] for what "delete" actually does depending on
  /// whether this outfit has siblings in its group).
  Widget _buildVersionMenuButton() {
    return PopupMenuButton<_VersionMenuAction>(
      padding: EdgeInsets.zero,
      color: AppColors.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Narrower than the default 112-280 range — this menu's items are
      // both short, so the default min width leaves a lot of empty space.
      constraints: const BoxConstraints(minWidth: 0, maxWidth: 150),
      // Default menuPadding is 8px vertical around the whole item list, on
      // top of each item's own height — shrink it since this menu only
      // has two short items.
      menuPadding: const EdgeInsets.symmetric(vertical: 4),
      onSelected: _handleVersionMenuAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _VersionMenuAction.regenerate,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.refresh, size: 20, color: AppColors.icon),
              const SizedBox(width: 8),
              Text(
                _l10n.regenerate,
                style: AppTextStyle.regular14.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: _VersionMenuAction.delete,
          enabled: !_isDeleting,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 20, color: AppColors.icon),
              const SizedBox(width: 8),
              Text(
                _l10n.deleteThisVersion,
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
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
        const SizedBox(height: 16),
        if (_isLoadingGarments)
          const Center(child: PetalLoader())
        else if (_garments != null)
          ..._garments!.map(_buildGarmentCard),
      ],
    );
  }

  Widget _buildGarmentCard(Garment g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.cardSpacing),
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
      final cached = ref.read(garmentsProvider).valueOrNull ?? const [];
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

  Future<void> _saveOutfit() async {
    setState(() => _isSaving = true);
    try {
      // The outfit is already persisted (created it as soon as the try-on
      // job was made) — "saving" is purely local: mark it confirmed-kept so
      // leaving the page from here on doesn't offer to delete it.
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
        // Already persisted — nothing to call, just stop offering to
        // delete it.
        await ref.read(outfitsProvider.notifier).refresh();
      } else {
        await OutfitService().deleteOutfit(
          widget.outfit.groupId,
          widget.outfit.id,
        );
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
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
        ref.read(outfitsProvider.notifier).removeById(version.id);
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

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _primary.name ?? '');
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
      await OutfitService().updateOutfit(
        _primary.groupId,
        _primary.id,
        name: result,
      );
      if (!mounted) return;
      setState(() => _versions[0] = _primary.copyWith(name: result));
      ref.read(outfitsProvider.notifier).updateName(_primary.id, name: result);
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
