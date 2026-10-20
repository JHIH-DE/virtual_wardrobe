import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/providers/weather_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_recommendation_service.dart';
import '../../core/services/match_look_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/try_on_mixin.dart';
import '../../data/garment.dart';
import '../../data/match_a_look.dart';
import '../../data/outfit.dart';
import '../../data/style_type.dart';
import '../../data/background_option.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/style_type_localization.dart';
import '../widgets/common/buttons/action_disc_button.dart';
import '../widgets/common/adaptive_side_layout.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/buttons/circle_icon_button.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/fields/number_stepper.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/photo_source_dialog.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_image.dart';
import '../widgets/outfit/outfit_background_field.dart';
import 'camera_capture_page.dart' show CameraFrameRatio;
import 'outfit_details_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;

/// Garment slots — not [GarmentCategory], since Top and Mid Layer are two
/// slots sharing [GarmentCategory.top].
enum _Slot { top, middle, outer, bottom, onePiece, shoes }

/// No error state: a failed match shows a dialog and drops back to [idle].
enum _MatchALookStatus { idle, analyzing, matched }

enum _ReferenceLookCardAction { remove }

/// One "Outfit Items" row: a core slot pick ([slot] set) or an accessory
/// ([accessoryIndex] set).
typedef _OutfitEntry = ({
  Garment garment,
  GarmentCategory category,
  _Slot? slot,
  int? accessoryIndex,
});

/// In-progress slot picks — local UI state, not a domain model.
class _OutfitSelection {
  final Garment? top;
  final Garment? middle;
  final Garment? outer;
  final Garment? bottom;
  final Garment? onePiece;
  final Garment? shoes;

  const _OutfitSelection({
    this.top,
    this.middle,
    this.outer,
    this.bottom,
    this.onePiece,
    this.shoes,
  });

  _OutfitSelection copyWith({
    Garment? top,
    Garment? middle,
    Garment? outer,
    Garment? bottom,
    Garment? onePiece,
    Garment? shoes,
    bool clearTop = false,
    bool clearMiddle = false,
    bool clearOuter = false,
    bool clearBottom = false,
    bool clearOnePiece = false,
    bool clearShoes = false,
  }) {
    return _OutfitSelection(
      top: clearTop ? null : (top ?? this.top),
      middle: clearMiddle ? null : (middle ?? this.middle),
      outer: clearOuter ? null : (outer ?? this.outer),
      bottom: clearBottom ? null : (bottom ?? this.bottom),
      onePiece: clearOnePiece ? null : (onePiece ?? this.onePiece),
      shoes: clearShoes ? null : (shoes ?? this.shoes),
    );
  }
}

class AddOutfitPage extends ConsumerStatefulWidget {
  final List<Garment> initialGarments;
  final VoidCallback? onBack;

  /// A photo shared in from another app (via `SharedMediaHandler`); Match a
  /// Look runs on it automatically on open.
  final String? initialMatchALookImagePath;

  /// Version mode (Outfit Details' Add Version): renders into this existing
  /// group and pops the new [Outfit] back, rather than opening it as a new
  /// outfit — whose "Don't Save" would delete the whole group.
  final int? targetGroupId;

  /// Version mode's starting background: the source version's, kept unless
  /// the user changes it.
  final int? initialBackgroundId;

  const AddOutfitPage({
    super.key,
    this.initialGarments = const [],
    this.onBack,
    this.initialMatchALookImagePath,
    this.targetGroupId,
    this.initialBackgroundId,
  });

  @override
  ConsumerState<AddOutfitPage> createState() => _AddOutfitPageState();
}

class _AddOutfitPageState extends ConsumerState<AddOutfitPage> with TryOnMixin {
  late _OutfitSelection _outfit;

  /// `.active`: a soft-deleted garment can't be picked for a new outfit.
  List<Garment> get _garmentPool =>
      (ref.read(garmentsProvider).value ?? const []).active;

  bool get _garmentPoolLoading => ref.read(garmentsProvider).isLoading;

  _MatchALookStatus _matchALookStatus = _MatchALookStatus.idle;
  String? _referenceImagePath;
  // Slots still holding Match a Look's pick; a manual pick or clear removes
  // the slot from this set.
  final Set<_Slot> _aiPopulatedSlots = {};

  static const int _maxAccessories = 4;

  // Always exactly one trailing empty ("+") slot until the max is reached.
  final List<Garment?> _accessories = [null];
  // Null when [AddOutfitPage.initialBackgroundId] is unset or unknown.
  BackgroundOption? _initialBackground;
  late BackgroundOption _background;
  // [_background] always has a default; this tells an explicit pick apart
  // from "never touched" (only an explicit pick, or version mode's initial
  // background, is sent).
  bool _backgroundCustomized = false;
  // Version mode only enables Create once the pick differs from these.
  late final Set<int> _initialGarmentIds;

  // Finish Outfit: locked ids are kept; excluded ids are past AI picks so a
  // re-run suggests something else. A null style lets the backend infer it.
  final Set<int> _lockedGarmentIds = {};
  final Set<int> _excludedGarmentIds = {};
  StyleType? _completeWithAiStyle;
  // null = follow `WeatherData.todayMeanTemp`; set once the user nudges the
  // stepper (this outfit only, not persisted).
  double? _weatherTempOverrideC;
  bool _finishOutfitExpanded = false;
  bool _isCompletingWithAi = false;
  // Create Outfit's re-entrancy guard; Finish Outfit's is
  // [_isCompletingWithAi].
  bool _tryOnRequested = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  static const List<GarmentCategory> _addCategoryOrder = [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outer,
    GarmentCategory.onePiece,
    GarmentCategory.shoes,
    GarmentCategory.socks,
    GarmentCategory.accessory,
  ];

  /// Drops full categories, accessory types already worn, base-layer tops
  /// interchangeable with one already worn ([baseTopSlotKey]) and garments
  /// already picked. The `keep*` args re-admit whatever is being swapped.
  List<Garment> _addGarmentCandidates({
    GarmentCategory? keepCategory,
    _Slot? keepSlot,
    int? keepAccessoryIndex,
  }) {
    bool categoryFull(GarmentCategory c) {
      if (c == keepCategory) return false;
      switch (c) {
        case GarmentCategory.top:
          return _outfit.top != null && _outfit.middle != null;
        case GarmentCategory.outer:
          return _outfit.outer != null;
        case GarmentCategory.bottom:
          return _outfit.bottom != null;
        case GarmentCategory.onePiece:
          return _outfit.onePiece != null;
        case GarmentCategory.shoes:
          return _outfit.shoes != null;
        case GarmentCategory.socks:
        case GarmentCategory.accessory:
          return _accessories.whereType<Garment>().length >= _maxAccessories;
      }
    }

    final wornAccessoryKeys = <String>{};
    for (var i = 0; i < _accessories.length; i++) {
      if (i == keepAccessoryIndex) continue;
      final a = _accessories[i];
      if (a != null && a.subCategory.isNotEmpty) {
        wornAccessoryKeys.add(accessorySlotKey(a.subCategory));
      }
    }

    final wornTopKeys = <String>{
      for (final entry in [
        (_outfit.top, _Slot.top),
        (_outfit.middle, _Slot.middle),
      ])
        if (entry.$1 != null &&
            entry.$2 != keepSlot &&
            entry.$1!.subCategory.isNotEmpty)
          baseTopSlotKey(entry.$1!.subCategory),
    };

    final coreIds = <int>{
      for (final g in [
        _outfit.top,
        _outfit.middle,
        _outfit.outer,
        _outfit.bottom,
        _outfit.onePiece,
        _outfit.shoes,
      ])
        if (g?.id != null) g!.id!,
    };

    return _garmentPool.where((g) {
      if (categoryFull(g.category)) return false;
      final isAccessory =
          g.category == GarmentCategory.accessory ||
          g.category == GarmentCategory.socks;
      if (isAccessory) {
        if (g.id != null && _accessoryIds.contains(g.id)) return false;
        if (g.subCategory.isNotEmpty &&
            wornAccessoryKeys.contains(accessorySlotKey(g.subCategory))) {
          return false;
        }
      } else if (g.category == GarmentCategory.top &&
          g.subCategory.isNotEmpty &&
          wornTopKeys.contains(baseTopSlotKey(g.subCategory))) {
        return false;
      } else if (g.id != null &&
          coreIds.contains(g.id) &&
          g.category != keepCategory) {
        return false;
      }
      return true;
    }).toList();
  }

  List<GarmentCategory> _addGarmentTabs(List<Garment> candidates) {
    final tabs = _addCategoryOrder
        .where((c) => candidates.any((g) => g.category == c))
        .toList();
    return tabs.isEmpty ? const [GarmentCategory.top] : tabs;
  }

  bool _hasCategory(GarmentCategory category) =>
      _garmentPool.any((g) => g.category == category);

  Future<void> _ensureFreshGarments() async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
  }

  Set<int> get _accessoryIds => _accessories
      .whereType<Garment>()
      .map((g) => g.id)
      .whereType<int>()
      .toSet();

  /// Top/Bottom/Shoes, limited to the categories the closet actually has.
  List<GarmentCategory> get _coreChecklist => const [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.shoes,
  ].where(_hasCategory).toList();

  /// A one-piece counts for both Top and Bottom.
  bool _coreSlotMet(GarmentCategory c) {
    switch (c) {
      case GarmentCategory.top:
        return _outfit.top != null || _outfit.onePiece != null;
      case GarmentCategory.bottom:
        return _outfit.bottom != null || _outfit.onePiece != null;
      case GarmentCategory.shoes:
        return _outfit.shoes != null;
      default:
        return true;
    }
  }

  bool get _coreComplete =>
      _coreChecklist.isNotEmpty && _coreChecklist.every(_coreSlotMet);

  @override
  void initState() {
    super.initState();
    _outfit = widget.initialGarments.isNotEmpty
        ? _buildInitialOutfit(widget.initialGarments)
        : const _OutfitSelection();
    if (widget.initialGarments.isNotEmpty) {
      _accessories
        ..clear()
        ..addAll(_buildInitialAccessories(widget.initialGarments));
    }
    _initialGarmentIds = _selectedGarmentIds().toSet();
    _initialBackground = BackgroundOption.all
        .where((b) => b.backgroundId == widget.initialBackgroundId)
        .firstOrNull;
    _background = _initialBackground ?? BackgroundOption.all.first;
    // Post-frame: refreshIfNeeded synchronously sets AsyncLoading, which
    // Riverpod forbids during initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(garmentsProvider.notifier).refreshIfNeeded();
      final sharedPath = widget.initialMatchALookImagePath;
      if (sharedPath != null && mounted) {
        _startMatchALookFlow(initialImagePath: sharedPath);
      }
    });
  }

  _OutfitSelection _buildInitialOutfit(List<Garment> garments) {
    final tops = garments
        .where((g) => g.category == GarmentCategory.top)
        .toList();
    return _OutfitSelection(
      top: tops.isNotEmpty ? tops[0] : null,
      middle: tops.length > 1 ? tops[1] : null,
      outer: garments
          .where((g) => g.category == GarmentCategory.outer)
          .firstOrNull,
      bottom: garments
          .where((g) => g.category == GarmentCategory.bottom)
          .firstOrNull,
      onePiece: garments
          .where((g) => g.category == GarmentCategory.onePiece)
          .firstOrNull,
      shoes: garments
          .where((g) => g.category == GarmentCategory.shoes)
          .firstOrNull,
    );
  }

  /// Keeps the "one trailing null add-slot until [_maxAccessories]"
  /// invariant.
  List<Garment?> _buildInitialAccessories(List<Garment> garments) {
    final picked = garments
        .where(
          (g) =>
              g.category == GarmentCategory.accessory ||
              g.category == GarmentCategory.socks,
        )
        .take(_maxAccessories)
        .toList();
    return [...picked, if (picked.length < _maxAccessories) null];
  }

  // Accessories are out of Match a Look's scope, so that role is never
  // applied.
  _Slot? _slotFor(MatchALookRole role) {
    switch (role) {
      case MatchALookRole.top:
        return _Slot.top;
      case MatchALookRole.midLayer:
        return _Slot.middle;
      case MatchALookRole.outer:
        return _Slot.outer;
      case MatchALookRole.bottom:
        return _Slot.bottom;
      case MatchALookRole.onePiece:
        return _Slot.onePiece;
      case MatchALookRole.shoes:
        return _Slot.shoes;
      case MatchALookRole.accessory:
        return null;
    }
  }

  _OutfitSelection _applyToSlot(_OutfitSelection sel, _Slot slot, Garment g) {
    switch (slot) {
      case _Slot.top:
        return sel.copyWith(top: g);
      case _Slot.middle:
        return sel.copyWith(middle: g);
      case _Slot.outer:
        return sel.copyWith(outer: g);
      case _Slot.bottom:
        return sel.copyWith(bottom: g);
      case _Slot.onePiece:
        return sel.copyWith(onePiece: g);
      case _Slot.shoes:
        return sel.copyWith(shoes: g);
    }
  }

  _OutfitSelection _clearSlotValue(_OutfitSelection sel, _Slot slot) {
    switch (slot) {
      case _Slot.top:
        return sel.copyWith(clearTop: true);
      case _Slot.middle:
        return sel.copyWith(clearMiddle: true);
      case _Slot.outer:
        return sel.copyWith(clearOuter: true);
      case _Slot.bottom:
        return sel.copyWith(clearBottom: true);
      case _Slot.onePiece:
        return sel.copyWith(clearOnePiece: true);
      case _Slot.shoes:
        return sel.copyWith(clearShoes: true);
    }
  }

  void _markSlotManual(_Slot slot) {
    _aiPopulatedSlots.remove(slot);
  }

  /// [initialImagePath] skips the camera/album picker.
  Future<void> _startMatchALookFlow({String? initialImagePath}) async {
    final imagePath =
        initialImagePath ??
        await showPhotoSourceDialog(
          context,
          title: _l10n.matchALookTitle,
          subtitle: _l10n.matchALookSubtitle,
          cameraFrameRatio: CameraFrameRatio.portrait,
        );
    if (imagePath == null || !mounted) return;
    await _runMatchALook(imagePath);
  }

  Future<void> _runMatchALook(String imagePath) async {
    setState(() => _matchALookStatus = _MatchALookStatus.analyzing);
    try {
      // Two calls: upload/analyze the reference, then match the closet
      // against what the backend stored.
      await MatchLookService().uploadReference(imagePath);
      final result = await MatchLookService().matchLook();
      if (!mounted) return;
      _applyMatchResult(imagePath, result);
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => _matchALookStatus = _MatchALookStatus.idle);
      await AuthExpiredHandler.handle(context);
    } on MatchLookException catch (e) {
      debugLog('Match a Look failed: ${e.errorCode} — ${e.message}');
      if (!mounted) return;
      setState(() => _matchALookStatus = _MatchALookStatus.idle);
      showErrorDialog(context, message: _matchLookErrorMessage(e));
    } catch (e, st) {
      debugLog('Match a Look failed: $e', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _matchALookStatus = _MatchALookStatus.idle);
      showErrorDialog(context, message: _l10n.matchALookFailed);
    }
  }

  /// Only codes about the photo itself get specific copy; the rest are
  /// pipeline failures the user can't act on.
  String _matchLookErrorMessage(MatchLookException e) {
    switch (e.errorCode) {
      case 'MATCH_LOOK_NO_PERSON':
        return _l10n.matchALookNoPerson;
      case 'MATCH_LOOK_MULTIPLE_PEOPLE':
        return _l10n.matchALookMultiplePeople;
      case 'MATCH_LOOK_OUTFIT_UNCLEAR':
        return _l10n.matchALookOutfitUnclear;
      case 'INSUFFICIENT_WARDROBE_DATA':
        return _l10n.matchALookInsufficientCloset;
      default:
        return _l10n.matchALookFailed;
    }
  }

  void _applyMatchResult(String imagePath, MatchALookResult result) {
    var next = _outfit;
    final newAiSlots = <_Slot>{};

    for (final match in result.roles) {
      final slot = _slotFor(match.role);
      if (slot == null) continue;
      if (match.matched) {
        final garment = result.garments[match.selectedGarmentId];
        // An unknown garment id counts as no match.
        if (garment != null) {
          next = _applyToSlot(next, slot, garment);
          newAiSlots.add(slot);
        }
      }
    }

    setState(() {
      _outfit = next;
      _referenceImagePath = imagePath;
      _aiPopulatedSlots
        ..clear()
        ..addAll(newAiSlots);
      _matchALookStatus = _MatchALookStatus.matched;
    });
  }

  /// Also clears the slots Match a Look still holds (manual picks stay).
  /// The backend DELETE is best-effort: the next upload overwrites it.
  Future<void> _clearMatchALookSession() async {
    var next = _outfit;
    for (final slot in _aiPopulatedSlots) {
      next = _clearSlotValue(next, slot);
    }
    setState(() {
      _outfit = next;
      _aiPopulatedSlots.clear();
      _referenceImagePath = null;
      _matchALookStatus = _MatchALookStatus.idle;
    });
    try {
      await MatchLookService().removeReference();
    } catch (_) {
      // Best-effort.
    }
  }

  Future<void> _changeReferenceLook() async {
    await _clearMatchALookSession();
    if (!mounted) return;
    await _startMatchALookFlow();
  }

  /// Core slots and accessories as one list — the backend takes a single
  /// `garment_ids`.
  List<int> _selectedGarmentIds() {
    final coreIds = [
      _outfit.top,
      _outfit.middle,
      _outfit.outer,
      _outfit.bottom,
      _outfit.onePiece,
      _outfit.shoes,
    ].whereType<Garment>().map((g) => g.id).whereType<int>();
    final accessoryIds = _accessories
        .whereType<Garment>()
        .map((g) => g.id)
        .whereType<int>();
    return {...coreIds, ...accessoryIds}.toList();
  }

  Future<void> _startTryOn() async {
    if (_tryOnRequested || isOutfitLoading || _isCompletingWithAi) return;
    setState(() => _tryOnRequested = true);
    try {
      final ids = _selectedGarmentIds();
      if (ids.isEmpty) return;

      if (tryOnOutfitId != 0) {
        await deleteOutfitJob(tryOnGroupId, tryOnOutfitId);
      }

      final outfit = await performTryOn(
        ids,
        groupId: widget.targetGroupId,
        backgroundId: _backgroundCustomized || _initialBackground != null
            ? _background.backgroundId
            : null,
      );
      if (!mounted) return;

      if (outfit != null && _isVersionMode) {
        Navigator.pop<Outfit>(context, outfit);
      } else if (tryOnResultUrl != null) {
        await _showTryOnResult(ids);
      } else if (tryOnErrorMessage != null) {
        showErrorDialog(context, message: tryOnErrorMessage!);
        resetTryOnState();
      }
    } finally {
      if (mounted) setState(() => _tryOnRequested = false);
    }
  }

  Future<void> _showTryOnResult(List<int> garmentIds) async {
    // OutfitDetailsPage pops `true` only when the user saves the outfit.
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OutfitDetailsPage(
          outfit: Outfit(
            id: tryOnOutfitId,
            groupId: tryOnGroupId,
            imageUrl: tryOnResultUrl!,
            garmentIds: garmentIds,
          ),
          isNew: true,
        ),
      ),
    );
    if (!mounted) return;
    resetTryOnState();
    if (saved == true) {
      showFeedbackOverlay(context, message: _l10n.outfitSaved);
    }
  }

  bool get _isVersionMode => widget.targetGroupId != null;

  /// A new version identical to its source would just be a re-render —
  /// Regenerate already covers that.
  bool get _isUnchangedVersion =>
      _isVersionMode &&
      setEquals(_selectedGarmentIds().toSet(), _initialGarmentIds) &&
      _background.id == (_initialBackground ?? BackgroundOption.all.first).id;

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _isVersionMode
          ? _l10n.addVersionTitle
          : _l10n.quickActionAddOutfit,
      onBack: widget.onBack,
      actions: [
        ActionDiscButton(
          tooltip: _l10n.matchALookTitle,
          icon: Image.asset(
            'assets/images/camera.png',
            width: ActionDisc.iconSize,
            height: ActionDisc.iconSize,
          ),
          onPressed: _referenceImagePath != null
              ? _changeReferenceLook
              : _startMatchALookFlow,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // _garmentPool / _garmentPoolLoading read it via ref.read.
    ref.watch(garmentsProvider);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          extendBody: true,
          appBar: _buildAppBar(),
          body: Builder(
            builder: (bodyContext) => ListView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                0,
                24,
                0,
                _showsBottomActionButton
                    ? BottomActionButton.scrollClearance(bodyContext)
                    : 24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: _buildCreateFlowBody(),
            ),
          ),
          bottomNavigationBar: _buildBottomBar(),
        ),
        if (isOutfitLoading)
          Positioned.fill(
            child: LoadingOverlay(
              label: _isVersionMode
                  ? _l10n.generatingEllipsis
                  : _l10n.creatingOutfitsEllipsis,
            ),
          ),
        if (_garmentPoolLoading)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingClosetEllipsis),
          ),
        if (_matchALookStatus == _MatchALookStatus.analyzing)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.matchingLookEllipsis),
          ),
        if (_isCompletingWithAi)
          Positioned.fill(child: LoadingOverlay(label: _l10n.thinkingEllipsis)),
      ],
    );
  }

  List<Widget> _buildCreateFlowBody() {
    return [
      if (_referenceImagePath != null) ...[
        _hInset(
          _ReferenceLookCard(
            referenceImagePath: _referenceImagePath!,
            matchedSlotCount: _aiPopulatedSlots.length,
            onChange: _changeReferenceLook,
            onRemove: _clearMatchALookSession,
          ),
        ),
        const SizedBox(height: AppDimens.sectionSpacing),
      ],
      _hInset(_buildFinishOutfitCard()),
      const SizedBox(height: AppDimens.sectionSpacing),
      _hInset(FieldLabel(_l10n.outfitItemsLabel.toUpperCase())),
      const SizedBox(height: AppDimens.cardHeaderGap),
      _hInset(_buildYourOutfitRow()),
      _hInset(const AppDivider(spacing: AppDimens.sectionSpacing)),
      _hInset(
        OutfitBackgroundField(
          selected: _background,
          onSelected: isOutfitLoading
              ? null
              : (background) => setState(() {
                  _background = background;
                  _backgroundCustomized = true;
                }),
        ),
      ),
    ];
  }

  static const double _createFlowInset = 20;

  Widget _hInset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _createFlowInset),
    child: child,
  );

  static const double _outfitRowHeight = 84;
  static const double _addGarmentIconSize = 56;
  static const double _outfitThumbnailWidth = 78;

  Widget _buildYourOutfitRow() {
    final entries = _outfitEntries();
    return Column(
      children: [
        _buildAddGarmentRow(),
        for (final entry in entries) ...[
          const SizedBox(height: AppDimens.cardSpacing),
          _buildOutfitGarmentRow(entry),
        ],
      ],
    );
  }

  Widget _buildAddGarmentRow() {
    final exhausted =
        _garmentPool.isNotEmpty && _addGarmentCandidates().isEmpty;
    final enabled = !isOutfitLoading && !_garmentPoolLoading && !exhausted;
    final iconColor = enabled ? AppColors.icon : AppColors.hintText;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AppListCard(
        onTap: enabled ? () => _pickGarmentForOutfit() : null,
        showArrow: true,
        minHeight: _outfitRowHeight,
        leading: SizedBox(
          width: _addGarmentIconSize,
          height: _addGarmentIconSize,
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: enabled ? AppColors.borderStrong : AppColors.hintText,
              radius: AppDimens.cardRadius,
            ),
            child: Center(child: Icon(Icons.add, size: 22, color: iconColor)),
          ),
        ),
        title: _l10n.addGarment,
        child: Text(
          _l10n.browseYourClosetHint,
          style: AppTextStyle.regular12.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitGarmentRow(_OutfitEntry entry) {
    final g = entry.garment;
    final locked = _isLocked(g);
    final categoryLabel = entry.category.localizedLabel(context);
    final subtitle = g.subCategory.isNotEmpty
        ? '$categoryLabel · ${g.subCategory}'
        : categoryLabel;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: (isOutfitLoading || _garmentPoolLoading)
          ? null
          : () => _pickGarmentForOutfit(
              initial: entry.category,
              replaceSlot: entry.slot,
              replaceAccessoryIndex: entry.accessoryIndex,
              current: g,
            ),
      child: Container(
        constraints: const BoxConstraints(minHeight: _outfitRowHeight),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(AppDimens.cardRadius),
                ),
                child: SizedBox(
                  width: _outfitThumbnailWidth,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GarmentImage(
                      url: g.imageUrl,
                      garmentId: g.id,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(width: 1, color: AppColors.borderSubtle),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                  child: AdaptiveSideLayout(
                    sideEdge: AdaptiveSide.trailing,
                    gap: 8,
                    stackedGap: 4,
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.name,
                          style: AppTextStyle.bold14,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AppTextStyle.regular12.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    side: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CardCornerBadge(
                          icon: locked ? Icons.lock : Icons.lock_open,
                          backgroundColor: locked
                              ? AppColors.primary
                              : AppColors.placeholderSurface,
                          iconColor: locked
                              ? AppColors.textOnPrimary
                              : AppColors.icon,
                          hitTargetSize: const Size(
                            24,
                            AppDimens.minTouchTarget,
                          ),
                          onTap: isOutfitLoading ? null : () => _toggleLock(g),
                        ),
                        if (!isOutfitLoading) ...[
                          const SizedBox(width: 8),
                          CardCornerBadge(
                            icon: Icons.close,
                            backgroundColor: AppColors.placeholderSurface,
                            iconColor: AppColors.icon,
                            hitTargetSize: const Size(
                              24,
                              AppDimens.minTouchTarget,
                            ),
                            onTap: () => _removeOutfitEntry(entry),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Core slots first, then accessories. Mid layer is labelled as a top.
  List<_OutfitEntry> _outfitEntries() {
    final list = <_OutfitEntry>[];
    void addSlot(Garment? g, _Slot slot, GarmentCategory category) {
      if (g != null) {
        list.add((
          garment: g,
          category: category,
          slot: slot,
          accessoryIndex: null,
        ));
      }
    }

    addSlot(_outfit.top, _Slot.top, GarmentCategory.top);
    addSlot(_outfit.middle, _Slot.middle, GarmentCategory.top);
    addSlot(_outfit.outer, _Slot.outer, GarmentCategory.outer);
    addSlot(_outfit.bottom, _Slot.bottom, GarmentCategory.bottom);
    addSlot(_outfit.onePiece, _Slot.onePiece, GarmentCategory.onePiece);
    addSlot(_outfit.shoes, _Slot.shoes, GarmentCategory.shoes);
    for (var i = 0; i < _accessories.length; i++) {
      final g = _accessories[i];
      if (g != null) {
        list.add((
          garment: g,
          category: g.category,
          slot: null,
          accessoryIndex: i,
        ));
      }
    }
    return list;
  }

  void _removeOutfitEntry(_OutfitEntry entry) {
    setState(() {
      final slot = entry.slot;
      if (slot != null) {
        _outfit = _clearSlotValue(_outfit, slot);
        _markSlotManual(slot);
      } else if (entry.accessoryIndex != null) {
        _accessories.removeAt(entry.accessoryIndex!);
        _accessories.removeWhere((g) => g == null);
        if (_accessories.length < _maxAccessories) _accessories.add(null);
      }
      if (entry.garment.id != null) {
        _lockedGarmentIds.remove(entry.garment.id);
      }
    });
  }

  bool _isLocked(Garment? g) =>
      g != null && g.id != null && _lockedGarmentIds.contains(g.id);

  void _lockGarment(Garment g) {
    if (g.id != null) _lockedGarmentIds.add(g.id!);
  }

  void _toggleLock(Garment g) {
    final id = g.id;
    if (id == null) return;
    setState(() {
      if (!_lockedGarmentIds.remove(id)) _lockedGarmentIds.add(id);
    });
  }

  GarmentCategory _categoryForSlot(_Slot slot) {
    switch (slot) {
      case _Slot.top:
      case _Slot.middle:
        return GarmentCategory.top;
      case _Slot.outer:
        return GarmentCategory.outer;
      case _Slot.bottom:
        return GarmentCategory.bottom;
      case _Slot.onePiece:
        return GarmentCategory.onePiece;
      case _Slot.shoes:
        return GarmentCategory.shoes;
    }
  }

  /// [replaceSlot] / [replaceAccessoryIndex] pin the pick to the row being
  /// swapped; [current] shows as selected in the picker.
  Future<void> _pickGarmentForOutfit({
    GarmentCategory? initial,
    _Slot? replaceSlot,
    int? replaceAccessoryIndex,
    Garment? current,
  }) async {
    await _ensureFreshGarments();
    if (!mounted) return;
    final candidates = _addGarmentCandidates(
      keepCategory: replaceSlot != null ? _categoryForSlot(replaceSlot) : null,
      keepSlot: replaceSlot,
      keepAccessoryIndex: replaceAccessoryIndex,
    );
    final tabs = _addGarmentTabs(candidates);
    final result = await Navigator.push<SelectGarmentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectGarmentPage(
          title: _l10n.addGarment,
          category: (initial != null && tabs.contains(initial))
              ? initial
              : null,
          categoryTabs: tabs,
          garments: candidates,
          selected: current,
        ),
      ),
    );
    final picked = result?.garment;
    if (picked == null || !mounted) return;
    _assignGarment(
      picked,
      replaceSlot: replaceSlot,
      replaceAccessoryIndex: replaceAccessoryIndex,
    );
  }

  /// Manual picks are always locked so Finish Outfit keeps them.
  void _assignGarment(
    Garment g, {
    _Slot? replaceSlot,
    int? replaceAccessoryIndex,
  }) {
    setState(() {
      if (replaceSlot != null && g.category == _categoryForSlot(replaceSlot)) {
        _outfit = _applyToSlot(_outfit, replaceSlot, g);
        _markSlotManual(replaceSlot);
        _lockGarment(g);
        return;
      }
      final isAccessory =
          g.category == GarmentCategory.accessory ||
          g.category == GarmentCategory.socks;
      if (replaceAccessoryIndex != null &&
          isAccessory &&
          replaceAccessoryIndex < _accessories.length) {
        _accessories[replaceAccessoryIndex] = g;
        _accessories.removeWhere((a) => a == null);
        if (_accessories.length < _maxAccessories) _accessories.add(null);
        _lockGarment(g);
        return;
      }
      _placeGarment(g, lock: true);
    });
  }

  /// Call inside `setState`. A top interchangeable with the current one
  /// ([baseTopSlotKey], e.g. Polo over T-shirt) replaces it instead of
  /// becoming the mid layer.
  void _placeGarment(Garment g, {required bool lock}) {
    switch (g.category) {
      case GarmentCategory.top:
        final existingTop = _outfit.top;
        final sameBaseLayer =
            existingTop != null &&
            baseTopSlotKey(existingTop.subCategory) ==
                baseTopSlotKey(g.subCategory);
        final slot = (_outfit.top == null || sameBaseLayer)
            ? _Slot.top
            : (_outfit.middle == null ? _Slot.middle : _Slot.top);
        _outfit = _applyToSlot(_outfit, slot, g);
        _markSlotManual(slot);
      case GarmentCategory.outer:
        _outfit = _applyToSlot(_outfit, _Slot.outer, g);
        _markSlotManual(_Slot.outer);
      case GarmentCategory.bottom:
        _outfit = _applyToSlot(_outfit, _Slot.bottom, g);
        _markSlotManual(_Slot.bottom);
      case GarmentCategory.onePiece:
        _outfit = _applyToSlot(_outfit, _Slot.onePiece, g);
        _markSlotManual(_Slot.onePiece);
      case GarmentCategory.shoes:
        _outfit = _applyToSlot(_outfit, _Slot.shoes, g);
        _markSlotManual(_Slot.shoes);
      case GarmentCategory.accessory:
      case GarmentCategory.socks:
        final filled = _accessories.whereType<Garment>().toList();
        if (filled.length >= _maxAccessories ||
            (g.id != null && _accessoryIds.contains(g.id))) {
          return;
        }
        filled.add(g);
        _accessories
          ..clear()
          ..addAll(filled);
        if (_accessories.length < _maxAccessories) _accessories.add(null);
    }
    if (lock) _lockGarment(g);
  }

  /// The result is the full outfit (locked ids included). Unlocked picks are
  /// cleared first so a dropped slot really empties. [keepGarmentIds] is the
  /// locked set at request time, so a lock toggled mid-request is ignored.
  void _applyCompletedOutfit(
    List<int> garmentIds, {
    required Set<int> keepGarmentIds,
  }) {
    bool kept(Garment? g) =>
        g != null && g.id != null && keepGarmentIds.contains(g.id);

    final byId = {
      for (final g in _garmentPool)
        if (g.id != null) g.id!: g,
    };
    final recommended = garmentIds
        .map((id) => byId[id])
        .whereType<Garment>()
        .toList();

    setState(() {
      _excludedGarmentIds.addAll(
        garmentIds.where((id) => !keepGarmentIds.contains(id)),
      );
      if (!kept(_outfit.top)) _outfit = _outfit.copyWith(clearTop: true);
      if (!kept(_outfit.middle)) {
        _outfit = _outfit.copyWith(clearMiddle: true);
      }
      if (!kept(_outfit.outer)) {
        _outfit = _outfit.copyWith(clearOuter: true);
      }
      if (!kept(_outfit.bottom)) {
        _outfit = _outfit.copyWith(clearBottom: true);
      }
      if (!kept(_outfit.onePiece)) {
        _outfit = _outfit.copyWith(clearOnePiece: true);
      }
      if (!kept(_outfit.shoes)) {
        _outfit = _outfit.copyWith(clearShoes: true);
      }
      for (var i = 0; i < _accessories.length; i++) {
        if (!kept(_accessories[i])) _accessories[i] = null;
      }
      _accessories.removeWhere((g) => g == null);
      if (_accessories.length < _maxAccessories) _accessories.add(null);

      for (final g in recommended) {
        if (kept(g)) continue; // already kept in place above
        _placeGarment(g, lock: false);
      }
    });
  }

  static const double _defaultTemperatureC = 20;

  Widget _buildFinishOutfitCard() {
    final liveTemp = ref
        .watch(weatherProvider)
        .maybeWhen(data: (w) => w.todayMeanTemp, orElse: () => null);
    final tempC = _weatherTempOverrideC ?? liveTemp ?? _defaultTemperatureC;
    final enabled =
        !isOutfitLoading && !_isCompletingWithAi && !_garmentPoolLoading;
    return AppCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 40),
                  child: SectionTitle(_l10n.finishOutfit),
                ),
                Positioned(
                  right: 0,
                  child: CircleIconButton(
                    icon: _finishOutfitExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    iconSize: 24,
                    discAlignment: Alignment.centerRight,
                    onPressed: () => setState(
                      () => _finishOutfitExpanded = !_finishOutfitExpanded,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_finishOutfitExpanded) ...[
            const SizedBox(height: AppDimens.cardHeaderGap),
            LayoutBuilder(
              builder: (context, constraints) {
                final temperatureTile = _buildFinishOutfitTile(
                  label: _l10n.temperatureFieldLabel,
                  child: NumberStepper(
                    variant: NumberStepperVariant.tile,
                    valueLabel: '${tempC.round()}°C',
                    onDecrement: () =>
                        setState(() => _weatherTempOverrideC = tempC - 1),
                    onIncrement: () =>
                        setState(() => _weatherTempOverrideC = tempC + 1),
                  ),
                );
                final styleTile = _buildFinishOutfitTile(
                  label: _l10n.styleLabel,
                  onTap: _openStylePicker,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _completeWithAiStyle?.localizedName(context) ??
                              _l10n.styleAuto,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.bold16,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                );
                // Side by side only while half the row still fits a typical
                // temperature at full size (minus the tile's 12px padding).
                final tileContentWidth =
                    (constraints.maxWidth - AppDimens.cardSpacing) / 2 - 2 * 12;
                final sideBySide =
                    tileContentWidth >=
                    NumberStepper.tileWidthFor(
                      context,
                      '${_defaultTemperatureC.round()}°C',
                    );
                if (!sideBySide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      temperatureTile,
                      const SizedBox(height: AppDimens.cardSpacing),
                      styleTile,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: temperatureTile),
                    const SizedBox(width: AppDimens.cardSpacing),
                    Expanded(child: styleTile),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: AppDimens.cardSpacing),
          Center(
            child: AccentPillButton(
              label: _l10n.finishWithAi,
              icon: Icons.auto_awesome,
              enabled: enabled,
              onPressed: _completeWithAi,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishOutfitTile({
    required String label,
    required Widget child,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: const BorderSide(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label.toUpperCase()),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimens.minTouchTarget,
                ),
                child: Align(alignment: Alignment.centerLeft, child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Options are records so "Auto" (null style) differs from a dismissed
  /// sheet.
  Future<void> _openStylePicker() async {
    final picked = await showSingleChoiceSheet<({StyleType? style})>(
      context,
      title: _l10n.styleLabel,
      options: [
        (style: null),
        for (final style in StyleType.values) (style: style),
      ],
      selected: (style: _completeWithAiStyle),
      labelOf: (o) => o.style?.localizedName(context) ?? _l10n.styleAuto,
    );
    if (picked == null || !mounted) return;
    setState(() => _completeWithAiStyle = picked.style);
  }

  /// Never throws.
  Future<WeatherData?> _fetchWeatherBestEffort() async {
    try {
      return await ref
          .read(weatherProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Picks garments only — no try-on image (that's [_startTryOn]).
  Future<void> _completeWithAi() async {
    if (_isCompletingWithAi) return;
    setState(() => _isCompletingWithAi = true);
    try {
      // null lets the backend decide.
      final temperatureC =
          _weatherTempOverrideC ??
          (await _fetchWeatherBestEffort())?.todayMeanTemp;
      final keep = {..._lockedGarmentIds};
      final ids = await GarmentRecommendationService().completeOutfit(
        garmentIds: keep.toList(),
        excludeGarmentIds: _excludedGarmentIds.toList(),
        style: _completeWithAiStyle,
        temperatureC: temperatureC,
      );
      if (!mounted) return;
      _applyCompletedOutfit(ids, keepGarmentIds: keep);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Complete with AI failed: $e');
      if (!mounted) return;
      showErrorDialog(context, message: _l10n.completeWithAiUnavailable);
    } finally {
      if (mounted) setState(() => _isCompletingWithAi = false);
    }
  }

  /// Needs every core category the closet has; a closet with none of them
  /// falls back to "at least 2 garments".
  bool get _createFlowReady {
    if (isOutfitLoading ||
        _garmentPoolLoading ||
        _tryOnRequested ||
        _isCompletingWithAi ||
        _isUnchangedVersion) {
      return false;
    }
    if (_coreChecklist.isEmpty) return _selectedGarmentIds().length >= 2;
    return _coreComplete;
  }

  bool get _showsBottomActionButton => _createFlowReady;

  Widget _buildBottomBar() {
    return BottomActionButton(
      label: _isVersionMode ? _l10n.createVersion : _l10n.createOutfit,
      leading: Image.asset(
        'assets/images/ai_process_inv.png',
        width: 18,
        height: 18,
      ),
      onPressed: _startTryOn,
      enabled: _createFlowReady,
    );
  }
}

/// Remove lives in the overflow menu by design, not as a visible button.
class _ReferenceLookCard extends StatelessWidget {
  final String referenceImagePath;
  final int matchedSlotCount;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const _ReferenceLookCard({
    required this.referenceImagePath,
    required this.matchedSlotCount,
    required this.onChange,
    required this.onRemove,
  });

  static final BoxDecoration _cardDecoration = BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.surface, AppColors.uwearisCardTint],
    ),
    borderRadius: BorderRadius.circular(AppDimens.cardRadius),
    border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
    boxShadow: [
      BoxShadow(
        color: AppColors.primary.withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(referenceImagePath),
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: AppColors.icon,
                    ),
                    const SizedBox(width: 6),
                    SectionTitle(l10n.referenceLookLabel),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.piecesMatchedCount(matchedSlotCount),
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onChange,
                  child: Text(
                    l10n.change,
                    style: AppTextStyle.bold14.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          AppPopupMenu<_ReferenceLookCardAction>(
            onSelected: (action) {
              switch (action) {
                case _ReferenceLookCardAction.remove:
                  onRemove();
              }
            },
            items: [
              AppPopupMenu.item(
                value: _ReferenceLookCardAction.remove,
                label: l10n.removeReferenceLook,
                isDestructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
