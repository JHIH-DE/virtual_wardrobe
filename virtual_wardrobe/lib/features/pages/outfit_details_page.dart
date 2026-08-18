import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
import 'add_outfit_page.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/fields/app_text_field.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/cards/category_tag.dart';
import '../widgets/common/floating_nav_bar.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/images/refreshable_network_image.dart';
import '../widgets/common/fields/selectable_chip.dart';
import '../widgets/garment/garment_detail_dialog.dart';
import '../widgets/garment/garment_list_card.dart';
import '../widgets/outfit/outfit_image.dart';

enum _OutfitMenuAction { rename, share, delete }

/// One image shown in Outfit Details' carousel. [lookId] is only null
/// before the real look history has loaded — until then, delete/regenerate
/// stay disabled.
class _OutfitLookEntry {
  final String imageUrl;
  final int? lookId;
  // This specific look's accessories — not the outfit's fixed core combo,
  // since accessories are picked per-look. Drives the Garment list so it
  // reflects whichever look is currently shown, not every look ever
  // generated.
  final List<int> accessoryGarmentIds;
  final bool isFavorite;
  const _OutfitLookEntry(
    this.imageUrl, {
    this.lookId,
    this.accessoryGarmentIds = const [],
    this.isFavorite = false,
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
  bool _resolvingSavedStatus = false;
  String? _name;
  List<String>? _seasons;
  List<String>? _style;
  List<Garment>? _garments;
  bool _loadingGarments = false;
  bool _openingTryOn = false;
  // Index into _outfitImages currently re-running its AI render via
  // OutfitService.regenerateLook, or null if none is in flight.
  int? _regeneratingLookIndex;
  // True while a look-delete undo SnackBar is showing (see _deleteLook) —
  // blocks starting a second one until the first resolves.
  bool _hasPendingLookDelete = false;

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
    // The backend no longer has an is_saved concept — every outfit is
    // persisted the moment it's created. isNew is what actually means
    // "not yet confirmed kept" here: fresh outfits start unconfirmed (so
    // Save/leave-without-saving can still offer to delete it), anything
    // opened from elsewhere is already real and treated as kept.
    _isSaved = !widget.isNew;
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
              isFavorite:
                  look['is_favorite'] == true || look['is_favorite'] == 1,
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
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            _showsBottomActionButton ? AppDimens.bottomActionBtnClearance : 30,
          ),
          children: [
            _buildInfoCard(),
            const SizedBox(height: 12),
            _buildOutfitImage(),
            const SizedBox(height: 16),
            if (widget.outfit.garmentIds.isNotEmpty) ...[
              _buildGarmentSection(),
            ],
            _buildCreateDateFooter(),
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
  /// [OutfitService.setSeason]/[OutfitService.setStyle] on confirm.
  Future<void> _openEditTagsSheet() async {
    final selectedSeasons = _effectiveSeasons.map(_titleCase).toSet();
    final selectedStyles = _effectiveStyle.map(_titleCase).toSet();

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
                        style: const TextStyle(color: AppColors.textOnPrimary),
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
      // Sequential, not Future.wait — both PATCH the same outfit resource,
      // and firing them concurrently risks a lost update if the backend's
      // handler isn't a true partial-field merge (whichever write lands
      // second could silently clobber the other's field).
      await OutfitService().setSeason(widget.outfit.id, season: seasons);
      await OutfitService().setStyle(widget.outfit.id, style: styles);
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        _style = styles;
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

  Widget _buildCreateDateFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          _l10n.createdOnDate(_formattedDate),
          style: AppTextStyle.bold14.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
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
  /// [_OutfitLookEntry.lookId] are deletable (see [_buildOutfitImage]), and
  /// the last remaining look can never be deleted.
  ///
  /// No confirmation dialog, no visible countdown — the look disappears
  /// from the carousel immediately and a lightweight "Look deleted"
  /// SnackBar offers an Undo for a few seconds. Only an explicit Undo tap
  /// ([SnackBarClosedReason.action]) restores it; letting the SnackBar time
  /// out, swiping it away, or navigating elsewhere all commit the delete to
  /// the backend once it resolves.
  Future<void> _deleteLook(int index) async {
    if (_outfitImages.length <= 1 || _hasPendingLookDelete) return;
    final lookId = _outfitImages[index].lookId;
    if (lookId == null) return;

    final removedEntry = _outfitImages[index];
    final previousImageIndex = _currentImageIndex;

    setState(() {
      _hasPendingLookDelete = true;
      _outfitImages.removeAt(index);
      if (_currentImageIndex >= _outfitImages.length) {
        _currentImageIndex = _outfitImages.length - 1;
      }
    });
    _bumpPrimaryLookCacheIfPromoted(index);
    _loadGarments();
    if (_outfitImagePageController.hasClients) {
      _outfitImagePageController.jumpToPage(_currentImageIndex);
    }

    final reason = await ScaffoldMessenger.of(
      context,
    ).showSnackBar(_buildLookDeletedSnackBar()).closed;
    if (!mounted) return;
    setState(() => _hasPendingLookDelete = false);

    if (reason == SnackBarClosedReason.action) {
      setState(() {
        _outfitImages.insert(index, removedEntry);
        _currentImageIndex = previousImageIndex.clamp(
          0,
          _outfitImages.length - 1,
        );
      });
      _bumpPrimaryLookCacheIfPromoted(index);
      _loadGarments();
      if (_outfitImagePageController.hasClients) {
        _outfitImagePageController.jumpToPage(_currentImageIndex);
      }
      return;
    }

    try {
      await OutfitService().deleteLook(widget.outfit.id, lookId);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      // The backend delete failed after it was already removed from the
      // UI — put it back so the two don't drift out of sync.
      setState(() {
        _outfitImages.insert(index, removedEntry);
        _currentImageIndex = index;
      });
      _bumpPrimaryLookCacheIfPromoted(index);
      _loadGarments();
      if (_outfitImagePageController.hasClients) {
        _outfitImagePageController.jumpToPage(_currentImageIndex);
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// The carousel's position 0 always renders under the fixed
  /// `outfit-job-$outfitId` cache key (see [_buildOutfitImage]'s
  /// `itemBuilder`), not the occupying look's own identity — because
  /// that's the same key Home/Outfits/Trip use for this outfit's primary
  /// image. That's fine as long as position 0 always holds the same look,
  /// but [_deleteLook] can promote a *different* look into position 0 (or
  /// demote+restore one back), and without bumping the version here, the
  /// promoted look would render with stale bytes still cached under that
  /// key from whichever look occupied position 0 before it.
  void _bumpPrimaryLookCacheIfPromoted(int mutatedIndex) {
    if (mutatedIndex != 0) return;
    ImageCacheBust.bump('outfit-job-${widget.outfit.id}');
  }

  /// Lightweight "Look deleted" undo prompt — margins align with the page's
  /// own content padding (see [_buildScaffold]'s `ListView` padding) and
  /// the Undo action uses the app's purple accent instead of Material's
  /// default action color.
  SnackBar _buildLookDeletedSnackBar() {
    return SnackBar(
      duration: const Duration(seconds: 5),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      content: Text(
        _l10n.lookDeleted,
        style: AppTextStyle.regular14.copyWith(color: AppColors.textOnPrimary),
      ),
      action: SnackBarAction(
        label: _l10n.undo,
        textColor: AppColors.accent,
        onPressed: () {},
      ),
    );
  }

  /// Re-runs the AI render for a single look in place (see
  /// [OutfitService.regenerateLook]) — same accessories/background, new
  /// image, no new history entry.
  Future<void> _regenerateLook(int index) async {
    if (_regeneratingLookIndex != null) return;
    final lookId = _outfitImages[index].lookId;
    if (lookId == null) return;

    setState(() => _regeneratingLookIndex = index);
    try {
      await OutfitService().regenerateLook(widget.outfit.id, lookId);
      final look = await _waitForLookCompletion(widget.outfit.id, lookId);
      final freshUrl = look?['result_image_url'] as String?;
      if (freshUrl == null || freshUrl.isEmpty) {
        throw Exception('Regenerate timed out or failed.');
      }
      // regenerateLook overwrites the image at its existing URL in place,
      // so the URL never changes — bump the same base key every consumer
      // of this look/outfit's image reads (this page's own carousel on a
      // future instance, and OutfitImage elsewhere for index 0's primary
      // look — see ImageCacheBust), so they all move to a cache key that's
      // never been seen before instead of keep serving pre-regenerate
      // bytes from a stable key's cache entry.
      final baseKey = index == 0
          ? 'outfit-job-${widget.outfit.id}'
          : 'look-$lookId';
      ImageCacheBust.bump(baseKey);

      if (!mounted) return;
      setState(() {
        final old = _outfitImages[index];
        _outfitImages[index] = _OutfitLookEntry(
          freshUrl,
          lookId: lookId,
          accessoryGarmentIds: old.accessoryGarmentIds,
          isFavorite: old.isFavorite,
        );
      });
      // Index 0 is this outfit's primary look — also shown (via
      // OutfitImage) in the Outfits list, Home, and Trip pages. Refreshing
      // makes them rebuild now (picking up the just-bumped version above)
      // instead of only whenever something else happens to rebuild them.
      if (index == 0) {
        await ref.read(outfitsProvider.notifier).refresh();
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
      if (mounted) setState(() => _regeneratingLookIndex = null);
    }
  }

  void _setLookFavorite(int index, bool isFavorite) {
    setState(() {
      final old = _outfitImages[index];
      _outfitImages[index] = _OutfitLookEntry(
        old.imageUrl,
        lookId: old.lookId,
        accessoryGarmentIds: old.accessoryGarmentIds,
        isFavorite: isFavorite,
      );
    });
  }

  Future<void> _toggleLookFavorite(int index) async {
    final lookId = _outfitImages[index].lookId;
    if (lookId == null) return;

    final next = !_outfitImages[index].isFavorite;
    _setLookFavorite(index, next);
    try {
      await OutfitService().setLookFavorite(
        widget.outfit.id,
        lookId,
        isFavorite: next,
      );
    } catch (e) {
      if (!mounted) return;
      _setLookFavorite(index, !next);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateFavorite)));
    }
  }

  /// Polls a specific look (as opposed to [_waitForOutfitCompletion], which
  /// always watches the outfit's primary look) until it completes, fails,
  /// or times out.
  Future<Map<String, dynamic>?> _waitForLookCompletion(
    int outfitId,
    int lookId,
  ) async {
    for (var attempt = 0; attempt < 180; attempt++) {
      final data = await OutfitService().getOutfit(outfitId);
      final look = lookById(data, lookId);
      final status = look?['status'];
      if (status == 'completed') return look;
      if (status == 'failed') return null;
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
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
                  itemBuilder: (_, index) {
                    final entry = _outfitImages[index];
                    // Stable base id (survives signed-URL re-signing) plus
                    // ImageCacheBust's live version — bumped by
                    // _regenerateLook, and read fresh by every page
                    // instance/widget that shows this same look/outfit
                    // image, so nothing (this carousel on a future page
                    // instance, OutfitImage elsewhere, ...) keeps serving
                    // pre-regenerate bytes.
                    final baseKey = index == 0
                        ? 'outfit-job-${widget.outfit.id}'
                        : entry.lookId != null
                        ? 'look-${entry.lookId}'
                        : null;
                    final cacheKey = baseKey == null
                        ? null
                        : '$baseKey-v${ImageCacheBust.versionOf(baseKey)}';
                    return RefreshableNetworkImage(
                      key: ValueKey(cacheKey ?? entry.imageUrl),
                      imageUrl: entry.imageUrl,
                      cacheKey: cacheKey,
                      fit: BoxFit.cover,
                      errorLabel: _l10n.failedToLoadImage,
                      onRefreshUrl: index == 0 ? _refreshOutfitImageUrl : null,
                    );
                  },
                ),
                if (_outfitImages[_currentImageIndex].lookId != null &&
                    _regeneratingLookIndex == null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: CardCornerBadge(
                      icon: _outfitImages[_currentImageIndex].isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      backgroundColor: AppColors.surfaceTranslucent,
                      iconColor: _outfitImages[_currentImageIndex].isFavorite
                          ? AppColors.favorite
                          : AppColors.icon,
                      size: 36,
                      iconSize: 20,
                      onTap: () => _toggleLookFavorite(_currentImageIndex),
                    ),
                  ),
                if (_regeneratingLookIndex == _currentImageIndex)
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
        _buildLookActionsBar(),
      ],
    );
  }

  /// Dots marking which outfit/look photo is shown, plus a "current / total"
  /// counter trailing them.
  Widget _buildImagePageIndicator() {
    if (_outfitImages.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          // Centered on the full row width — not the space left over after
          // the counter — so the active dot stays exactly centered
          // regardless of how wide the "current / total" text is.
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
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
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_currentImageIndex + 1} / ${_outfitImages.length}',
              style: AppTextStyle.regular13.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Regenerate/Delete for whichever look is currently shown — replaces the
  /// old on-image corner badges with a row below the photo so the image
  /// itself stays clean (only the favorite heart remains on it).
  Widget _buildLookActionsBar() {
    final current = _outfitImages[_currentImageIndex];
    final canAct = current.lookId != null && _regeneratingLookIndex == null;
    if (!canAct) return const SizedBox.shrink();

    final regenerateButton = _buildLookActionButton(
      icon: const Icon(Icons.refresh, size: 20, color: AppColors.textPrimary),
      label: _l10n.regenerate,
      onTap: () => _regenerateLook(_currentImageIndex),
    );

    // The last remaining look can never be deleted (see _deleteLook) — the
    // button shows disabled instead of prompting anything.
    final canDeleteLook = _outfitImages.length > 1;
    final deleteButton = _buildLookActionButton(
      icon: Image.asset('assets/images/delete.png', width: 20, height: 20),
      label: _l10n.deleteLook,
      onTap: canDeleteLook ? () => _deleteLook(_currentImageIndex) : null,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(child: regenerateButton),
            const VerticalDivider(width: 1, color: AppColors.borderSubtle),
            Expanded(child: deleteButton),
          ],
        ),
      ),
    );
  }

  Widget _buildLookActionButton({
    required Widget icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon,
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyle.regular13.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
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
