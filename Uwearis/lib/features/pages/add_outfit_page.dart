import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/services/match_look_service.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/signed_url.dart';
import '../../core/utils/try_on_mixin.dart';
import '../../data/garment.dart';
import '../../data/image_edit_result.dart';
import '../../data/match_a_look.dart';
import '../../data/outfit.dart';
import '../../data/background_option.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/edge_fade_scrim.dart';
import '../widgets/common/expand_arrow_icon.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_image.dart';
import 'image_editor_page.dart';
import 'outfit_details_page.dart';
import 'select_accessory_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;

/// The page's own identity for each garment slot — distinct from
/// [GarmentCategory] because Top and Mid Layer share [GarmentCategory.top]
/// but are two different slots. Used to key Match a Look's per-slot state
/// ([_AddOutfitPageState._aiPopulatedSlots], [_AddOutfitPageState._noCloseMatchSlots]).
enum _Slot { top, middle, outer, bottom, onePiece, shoes }

/// Where the Match a Look flow currently stands. There's no persisted
/// "error" state — a failed match just reports itself via a SnackBar and
/// drops back to [idle] so the card stays usable (see
/// [_AddOutfitPageState._runMatchALook]).
enum _MatchALookStatus { idle, analyzing, matched }

enum _MatchALookCardAction { remove }

/// The user's in-progress slot-by-slot garment picks for this page's manual
/// try-on flow. Purely local UI state (no fromJson/toJson) — not a synced
/// domain model, so it lives here rather than in lib/data/.
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

class AddOutfitPage extends StatefulWidget {
  final List<Garment> initialGarments;
  final List<Garment>? preloadedGarments;
  final VoidCallback? onBack;

  /// When true, the bottom bar becomes a "Confirm" button that pops the
  /// selected garment ids back to the caller instead of starting a try-on —
  /// used when this page is reused as a picker (e.g. editing a trip day's
  /// outfit) rather than for its own create-an-outfit flow.
  final bool selectOnly;

  /// In [selectOnly] mode, garment ids NOT in this set get a warning badge
  /// on their slot (e.g. an outfit item that's since been removed from the
  /// trip's suitcase). Ignored outside [selectOnly] mode.
  final Set<int>? validGarmentIds;

  /// When set, this page creates a *new* outfit inside this outfit's group
  /// instead of starting a fresh group (Outfit Details' "Create Another
  /// Version") — core garment slot edits and accessory picks work exactly
  /// like the normal create flow, the only difference is which group the
  /// result lands in. Pops the newly created [Outfit] on success.
  final Outfit? existingOutfit;

  const AddOutfitPage({
    super.key,
    this.initialGarments = const [],
    this.preloadedGarments,
    this.onBack,
    this.selectOnly = false,
    this.validGarmentIds,
    this.existingOutfit,
  });

  @override
  State<AddOutfitPage> createState() => _AddOutfitPageState();
}

class _AddOutfitPageState extends State<AddOutfitPage> with TryOnMixin {
  final List<Garment> _allGarments = [];
  late _OutfitSelection _outfit;
  late _OutfitSelection _initialOutfit;
  late Set<int> _initialAccessoryIds;
  bool _isLoadingGarments = false;

  // Match a Look session state — see clearMatchALookSession-equivalent
  // _clearMatchALookSession below for what "clearing" actually resets.
  _MatchALookStatus _matchALookStatus = _MatchALookStatus.idle;
  String? _referenceImagePath;
  Map<MatchALookRole, RoleMatch> _roleMatches = {};
  // Slots currently filled by Match a Look's #1 pick rather than a manual
  // choice — this is this page's selectionSource tracking: a slot in this
  // set is "referenceMatch", everything else (including slots the user
  // manually cleared or replaced) is implicitly "manual".
  final Set<_Slot> _aiPopulatedSlots = {};
  // Slots where the reference photo showed this role but nothing in the
  // closet was a close enough match — rendered as "No close match" instead
  // of "Not selected" while still empty.
  final Set<_Slot> _noCloseMatchSlots = {};

  static const int _maxAccessories = 4;
  static const double _accessoryTileSize = 72;

  // Customization block state — held here until Create Outfit sends
  // everything to the backend together.
  bool _customizationExpanded = false;
  // Always exactly one trailing empty ("+") slot until the max is reached.
  final List<Garment?> _accessories = [null];
  BackgroundOption _background = BackgroundOption.all.first;
  // Whether the user actually touched the background picker — [_background] always
  // has a concrete default, so this is the only way to tell "picked
  // Fitting Room on purpose" apart from "never opened the picker".
  bool _backgroundCustomized = false;

  late final ScrollController _backgroundScrollController = ScrollController()
    ..addListener(_updateBackgroundScrollArrows);
  bool _canScrollBackgroundLeft = false;
  // Optimistic default so the right-edge hint isn't briefly missing before
  // the first frame lets us measure whether the list actually overflows.
  bool _canScrollBackgroundRight = true;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  // In selectOnly mode, a category whose only occurrence is in the
  // pre-existing selection (e.g. its category has since vanished from the
  // pool entirely) still gets a slot — otherwise a stale pick would
  // disappear silently instead of showing its warning badge. Categories
  // with nothing in the pool AND nothing currently assigned stay hidden.
  late final Set<GarmentCategory> _initialCategories = widget.initialGarments
      .map((g) => g.category)
      .toSet();

  bool _hasCategory(GarmentCategory category) =>
      _allGarments.any((g) => g.category == category) ||
      ((widget.selectOnly || widget.existingOutfit != null) &&
          _initialCategories.contains(category));

  Future<void> _ensureFreshGarments() async {
    final stale = _allGarments.any((g) {
      final url = g.imageUrl;
      return url != null && url.isNotEmpty && isSignedUrlExpired(url);
    });
    if (stale) await _loadGarments();
  }

  /// Ids of whichever accessory slots are actually filled — [_accessories]
  /// always keeps one trailing `null` "+" slot, which this excludes.
  Set<int> get _accessoryIds => _accessories
      .whereType<Garment>()
      .map((g) => g.id)
      .whereType<int>()
      .toSet();

  bool get _hasSelection =>
      _outfit.top != null ||
      _outfit.middle != null ||
      _outfit.outer != null ||
      _outfit.bottom != null ||
      _outfit.onePiece != null ||
      _outfit.shoes != null ||
      _accessoryIds.isNotEmpty;

  // Minimum garments to generate an outfit render — Create Outfit stays
  // hidden until all three are picked. A category the closet has none of
  // (its slot row isn't even shown, see _hasCategory) doesn't block this —
  // otherwise a closet with no bottoms could never create an outfit.
  bool get _hasCoreSlots =>
      (!_hasCategory(GarmentCategory.top) || _outfit.top != null) &&
      (!_hasCategory(GarmentCategory.bottom) || _outfit.bottom != null) &&
      (!_hasCategory(GarmentCategory.shoes) || _outfit.shoes != null);

  bool get _isModified {
    bool sameSlot(Garment? a, Garment? b) => a?.id == b?.id;
    return !(sameSlot(_outfit.top, _initialOutfit.top) &&
        sameSlot(_outfit.middle, _initialOutfit.middle) &&
        sameSlot(_outfit.outer, _initialOutfit.outer) &&
        sameSlot(_outfit.bottom, _initialOutfit.bottom) &&
        sameSlot(_outfit.onePiece, _initialOutfit.onePiece) &&
        sameSlot(_outfit.shoes, _initialOutfit.shoes) &&
        setEquals(_accessoryIds, _initialAccessoryIds));
  }

  @override
  void initState() {
    super.initState();
    _outfit = widget.initialGarments.isNotEmpty
        ? _buildInitialOutfit(widget.initialGarments)
        : const _OutfitSelection();
    _initialOutfit = _outfit;
    if (widget.initialGarments.isNotEmpty) {
      _accessories
        ..clear()
        ..addAll(_buildInitialAccessories(widget.initialGarments));
    }
    _initialAccessoryIds = _accessoryIds;
    if (widget.preloadedGarments != null) {
      _allGarments.addAll(widget.preloadedGarments!);
    } else {
      _loadGarments();
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateBackgroundScrollArrows(),
    );
  }

  @override
  void dispose() {
    _backgroundScrollController.dispose();
    super.dispose();
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

  /// Mirrors [_buildInitialOutfit] for the accessory slots — preserves the
  /// "one trailing null add-slot until [_maxAccessories]" invariant that
  /// [_pickAccessoryAt] otherwise maintains.
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

  // Match a Look's `accessory` role has no corresponding _Slot — Accessories
  // & Background stay out of scope per the feature spec, so that role's match is
  // simply never applied.
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

  /// A manual pick (or clear) always wins over Match a Look — the slot
  /// drops out of both tracking sets regardless of what's now in it.
  void _markSlotManual(_Slot slot) {
    _aiPopulatedSlots.remove(slot);
    _noCloseMatchSlots.remove(slot);
  }

  List<int> _rankedIdsFor(_Slot slot) {
    for (final entry in _roleMatches.entries) {
      if (_slotFor(entry.key) == slot) return entry.value.rankedGarmentIds;
    }
    return const [];
  }

  Future<void> _startMatchALookFlow() async {
    final result = await Navigator.push<ImageEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ImageEditorPage(showAnalysis: false, title: _l10n.matchALookTitle),
      ),
    );
    if (result == null || !mounted) return;
    await _runMatchALook(result.imagePath);
  }

  Future<void> _runMatchALook(String imagePath) async {
    setState(() => _matchALookStatus = _MatchALookStatus.analyzing);
    try {
      // Two backend calls: analyze the reference photo, then separately
      // search the closet against whatever it just stored — see
      // match-look-api.md's numbered flow.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_matchLookErrorMessage(e))));
    } catch (e, st) {
      debugLog('Match a Look failed: $e', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _matchALookStatus = _MatchALookStatus.idle);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.matchALookFailed)));
    }
  }

  /// Most backend error codes (upload/AI-pipeline failures) are system
  /// noise the user can't act on — those fall back to the generic message.
  /// Only the handful describing something about the *photo itself* get a
  /// specific string worth showing.
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
    final newNoCloseMatchSlots = <_Slot>{};

    for (final match in result.roles) {
      final slot = _slotFor(match.role);
      if (slot == null) continue;
      if (match.matched) {
        final garment = result.garments[match.selectedGarmentId];
        // A matched role with a stale/unknown garment id is treated the
        // same as no match — nothing to fill the slot with, so it isn't
        // counted as AI-populated either.
        if (garment != null) {
          next = _applyToSlot(next, slot, garment);
          newAiSlots.add(slot);
        }
      } else if (match.matchStatus == MatchStatus.noCloseMatch) {
        newNoCloseMatchSlots.add(slot);
      }
    }

    setState(() {
      _outfit = next;
      _referenceImagePath = imagePath;
      _roleMatches = {for (final m in result.roles) m.role: m};
      _aiPopulatedSlots
        ..clear()
        ..addAll(newAiSlots);
      _noCloseMatchSlots
        ..clear()
        ..addAll(newNoCloseMatchSlots);
      _matchALookStatus = _MatchALookStatus.matched;
    });
  }

  /// Clears the whole Match a Look session — not just the reference image.
  /// Every slot Match a Look filled reverts to unselected; slots the user
  /// manually replaced afterward are untouched. Best-effort on the backend
  /// side: if the DELETE fails, the local state still clears so the page
  /// stays usable — the next upload/match overwrites whatever's left
  /// server-side anyway.
  Future<void> _clearMatchALookSession() async {
    var next = _outfit;
    for (final slot in _aiPopulatedSlots) {
      next = _clearSlotValue(next, slot);
    }
    setState(() {
      _outfit = next;
      _aiPopulatedSlots.clear();
      _noCloseMatchSlots.clear();
      _roleMatches = {};
      _referenceImagePath = null;
      _matchALookStatus = _MatchALookStatus.idle;
    });
    try {
      await MatchLookService().removeReference();
    } catch (_) {
      // Ignored — see doc comment above.
    }
  }

  Future<void> _changeReferenceLook() async {
    await _clearMatchALookSession();
    if (!mounted) return;
    await _startMatchALookFlow();
  }

  Future<void> _loadGarments() async {
    setState(() => _isLoadingGarments = true);
    try {
      final list = await GarmentService().getGarments();
      if (mounted) {
        setState(
          () => _allGarments
            ..clear()
            ..addAll(list),
        );
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingGarments = false);
    }
  }

  /// Every selected garment id — core slots (top/middle/outer/bottom/
  /// onePiece/shoes) and accessories together as one flat list. The backend
  /// has no separate accessory concept, just one `garment_ids` list, so
  /// there's no reason to keep them apart client-side either — this is the
  /// single source callers (Create Outfit's generate call, selectOnly
  /// mode's Confirm button) both read from.
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
    final ids = _selectedGarmentIds();
    if (ids.isEmpty) return;
    if (tryOnOutfitId != 0) {
      await deleteOutfitJob(tryOnGroupId, tryOnOutfitId);
    }

    await performTryOn(
      ids,
      // existingOutfit mode: land the new outfit in that outfit's group
      // instead of starting a fresh one (Outfit Details' "Create Another
      // Version").
      groupId: widget.existingOutfit?.groupId,
      backgroundId: _backgroundCustomized ? _background.backgroundId : null,
    );
    if (!mounted) return;

    if (tryOnResultUrl != null) {
      if (widget.existingOutfit != null) {
        Navigator.pop(context, tryOnOutfit);
      } else {
        await _showTryOnResult(ids);
      }
    } else if (tryOnErrorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tryOnErrorMessage!)));
      resetTryOnState();
    }
  }

  Future<void> _showTryOnResult(List<int> garmentIds) async {
    await Navigator.push<void>(
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
    if (mounted) {
      resetTryOnState();
      setState(() {
        _accessories
          ..clear()
          ..add(null);
        _background = BackgroundOption.all.first;
        _backgroundCustomized = false;
        _customizationExpanded = false;
      });
    }
  }

  AppToolBar _buildAppBar() {
    final existingOutfit = widget.existingOutfit;
    return AppToolBar(
      title: widget.selectOnly
          ? _l10n.selectGarmentsTitle
          : existingOutfit != null
          ? (existingOutfit.name?.isNotEmpty == true
                ? existingOutfit.name!
                : _l10n.createAnotherVersion)
          : _l10n.quickActionAddOutfit,
      onBack: widget.onBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          extendBody: true,
          appBar: _buildAppBar(),
          body: ListView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              24,
              20,
              _showsBottomActionButton
                  ? AppDimens.bottomActionBtnClearance
                  : 24,
            ),
            children: [
              _buildInstructions(),
              const SizedBox(height: AppDimens.sectionSpacing),
              if (!widget.selectOnly) ...[
                _MatchALookCard(
                  referenceImagePath: _referenceImagePath,
                  matchedSlotCount: _aiPopulatedSlots.length,
                  onStart: _startMatchALookFlow,
                  onChange: _changeReferenceLook,
                  onRemove: _clearMatchALookSession,
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
              ],
              ..._buildTopSlots(),
              ..._buildOuterSlot(),
              ..._buildBottomSlot(),
              ..._buildOnePieceSlot(),
              ..._buildShoesSlot(),
              _buildCustomizationBlock(),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(),
        ),
        if (isOutfitLoading)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.creatingOutfitsEllipsis),
          ),
        if (_isLoadingGarments)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingClosetEllipsis),
          ),
        if (_matchALookStatus == _MatchALookStatus.analyzing)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.matchingLookEllipsis),
          ),
      ],
    );
  }

  Widget _buildInstructions() {
    return Text(
      widget.selectOnly
          ? _l10n.editDayOutfitInstruction
          : _l10n.selectCombinationsInstruction,
      textAlign: TextAlign.left,
      style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
    );
  }

  List<Widget> _buildTopSlots() {
    if (!_hasCategory(GarmentCategory.top)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.top.localizedLabel(context),
        iconAsset: 'assets/images/top.png',
        value: _outfit.top,
        category: GarmentCategory.top,
        noCloseMatch: _noCloseMatchSlots.contains(_Slot.top),
        rankedGarmentIds: _rankedIdsFor(_Slot.top),
        onPicked: (g) => setState(() {
          _outfit = _outfit.copyWith(top: g);
          _markSlotManual(_Slot.top);
        }),
        onClear: _outfit.top == null
            ? null
            : () => setState(() {
                _outfit = _outfit.copyWith(clearTop: true);
                _markSlotManual(_Slot.top);
              }),
      ),
      const SizedBox(height: 24),
      _slotRow(
        title: _l10n.midLayer,
        optional: true,
        showNoneOption: true,
        iconAsset: 'assets/images/outer.png',
        value: _outfit.middle,
        category: GarmentCategory.top,
        noCloseMatch: _noCloseMatchSlots.contains(_Slot.middle),
        rankedGarmentIds: _rankedIdsFor(_Slot.middle),
        onPicked: (g) => setState(() {
          _outfit = _outfit.copyWith(middle: g);
          _markSlotManual(_Slot.middle);
        }),
        onClear: _outfit.middle == null
            ? null
            : () => setState(() {
                _outfit = _outfit.copyWith(clearMiddle: true);
                _markSlotManual(_Slot.middle);
              }),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildOuterSlot() {
    if (!_hasCategory(GarmentCategory.outer)) return const [];
    return [
      _slotRow(
        title: _l10n.outerwear,
        optional: true,
        showNoneOption: true,
        iconAsset: 'assets/images/outer.png',
        value: _outfit.outer,
        category: GarmentCategory.outer,
        noCloseMatch: _noCloseMatchSlots.contains(_Slot.outer),
        rankedGarmentIds: _rankedIdsFor(_Slot.outer),
        onPicked: (g) => setState(() {
          _outfit = _outfit.copyWith(outer: g);
          _markSlotManual(_Slot.outer);
        }),
        onClear: _outfit.outer == null
            ? null
            : () => setState(() {
                _outfit = _outfit.copyWith(clearOuter: true);
                _markSlotManual(_Slot.outer);
              }),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildBottomSlot() {
    if (!_hasCategory(GarmentCategory.bottom)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.bottom.localizedLabel(context),
        iconAsset: 'assets/images/buttom.png',
        value: _outfit.bottom,
        category: GarmentCategory.bottom,
        noCloseMatch: _noCloseMatchSlots.contains(_Slot.bottom),
        rankedGarmentIds: _rankedIdsFor(_Slot.bottom),
        onPicked: (g) => setState(() {
          _outfit = _outfit.copyWith(bottom: g);
          _markSlotManual(_Slot.bottom);
        }),
        onClear: _outfit.bottom == null
            ? null
            : () => setState(() {
                _outfit = _outfit.copyWith(clearBottom: true);
                _markSlotManual(_Slot.bottom);
              }),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildOnePieceSlot() {
    if (!_hasCategory(GarmentCategory.onePiece)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.onePiece.localizedLabel(context),
        optional: true,
        iconData: Icons.checkroom,
        value: _outfit.onePiece,
        category: GarmentCategory.onePiece,
        noCloseMatch: _noCloseMatchSlots.contains(_Slot.onePiece),
        rankedGarmentIds: _rankedIdsFor(_Slot.onePiece),
        onPicked: (g) => setState(() {
          _outfit = _outfit.copyWith(onePiece: g);
          _markSlotManual(_Slot.onePiece);
        }),
        onClear: _outfit.onePiece == null
            ? null
            : () => setState(() {
                _outfit = _outfit.copyWith(clearOnePiece: true);
                _markSlotManual(_Slot.onePiece);
              }),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildShoesSlot() {
    if (!_hasCategory(GarmentCategory.shoes)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.shoes.localizedLabel(context),
        iconAsset: 'assets/images/shoes.png',
        value: _outfit.shoes,
        category: GarmentCategory.shoes,
        noCloseMatch: _noCloseMatchSlots.contains(_Slot.shoes),
        rankedGarmentIds: _rankedIdsFor(_Slot.shoes),
        onPicked: (g) => setState(() {
          _outfit = _outfit.copyWith(shoes: g);
          _markSlotManual(_Slot.shoes);
        }),
        onClear: _outfit.shoes == null
            ? null
            : () => setState(() {
                _outfit = _outfit.copyWith(clearShoes: true);
                _markSlotManual(_Slot.shoes);
              }),
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Collapsible panel (collapsed by default) holding the Accessories and
  /// Background pickers. In [selectOnly] mode the Background picker is
  /// hidden — that mode just picks garment ids for a caller and has no
  /// generate step to apply a background to — but Accessories still shows,
  /// since accessory picks are now just more ids in [_selectedGarmentIds].
  Widget _buildCustomizationBlock() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(
              () => _customizationExpanded = !_customizationExpanded,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/accessories.png',
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(
                      widget.selectOnly
                          ? _l10n.accessoriesLabel
                          : _l10n.customizationOptional,
                      style: AppTextStyle.regular16,
                    ),
                  ),
                  ExpandArrowIcon(expanded: _customizationExpanded),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _customizationExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppDivider(
                    topSpacing: 0,
                    bottomSpacing: AppDimens.sectionSpacing,
                  ),
                  FieldLabel(_l10n.accessoriesLabel.toUpperCase()),
                  const SizedBox(height: AppDimens.cardHeaderGap),
                  _buildAccessoriesRow(),
                  if (!widget.selectOnly) ...[
                    const SizedBox(height: AppDimens.cardHeaderGap),
                    FieldLabel(_l10n.backgroundLabel.toUpperCase()),
                    const SizedBox(height: AppDimens.cardHeaderGap),
                    _buildBackgroundSelector(),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  List<Garment> get _accessoryCandidates => _allGarments
      .where(
        (g) =>
            g.category == GarmentCategory.accessory ||
            g.category == GarmentCategory.socks,
      )
      .toList();

  /// Normalizes an accessory's AI-assigned `subCategory` into the slot it
  /// occupies for exclusivity purposes — "Hat" and "Cap" are both
  /// headwear, so picking one in one slot should rule out the other in
  /// every other slot even though the raw strings differ. `subCategory`
  /// has no fixed enum (it's freeform per garment), so this only merges
  /// pairs known to collide; extend the set here if more turn up.
  String _accessorySlotKey(String subCategory) {
    final normalized = subCategory.toLowerCase();
    const headwear = {'hat', 'cap'};
    if (headwear.contains(normalized)) return 'headwear';
    return normalized;
  }

  /// Candidates for [index]'s slot, minus whatever *type* of accessory is
  /// already picked in the *other* slots (grouped by [_accessorySlotKey]).
  List<Garment> _accessoryCandidatesFor(int index) {
    final pickedTypesElsewhere = <String>{};
    final pickedIdsElsewhere = <int>{};
    for (var i = 0; i < _accessories.length; i++) {
      if (i == index) continue;
      final picked = _accessories[i];
      if (picked == null) continue;
      if (picked.subCategory.isNotEmpty) {
        pickedTypesElsewhere.add(_accessorySlotKey(picked.subCategory));
      } else if (picked.id != null) {
        pickedIdsElsewhere.add(picked.id!);
      }
    }
    return _accessoryCandidates.where((g) {
      if (g.subCategory.isNotEmpty &&
          pickedTypesElsewhere.contains(_accessorySlotKey(g.subCategory))) {
        return false;
      }
      return g.id == null || !pickedIdsElsewhere.contains(g.id);
    }).toList();
  }

  Future<void> _pickAccessoryAt(int index) async {
    await _ensureFreshGarments();
    if (!mounted) return;
    final result = await Navigator.push<SelectGarmentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectAccessoryPage(
          title: _l10n.selectItemTitle('Accessory'),
          garments: _accessoryCandidatesFor(index),
          selected: _accessories[index],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _accessories[index] = result.garment;
      _accessories.removeWhere((g) => g == null);
      if (_accessories.length < _maxAccessories) _accessories.add(null);
    });
  }

  Widget _buildAccessoriesRow() {
    return SizedBox(
      height: _accessoryTileSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _accessories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => SizedBox(
          width: _accessoryTileSize,
          height: _accessoryTileSize,
          child: _buildAccessoryTile(i),
        ),
      ),
    );
  }

  Widget _buildAccessoryTile(int index) {
    final accessory = _accessories[index];
    if (accessory == null) {
      return GestureDetector(
        onTap: isOutfitLoading ? null : () => _pickAccessoryAt(index),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CustomPaint(
            painter: const DashedBorderPainter(
              color: AppColors.borderStrong,
              radius: 10,
            ),
            child: const Center(
              child: Icon(Icons.add, size: 18, color: AppColors.icon),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: isOutfitLoading ? null : () => _pickAccessoryAt(index),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: SizedBox.expand(
            child: GarmentImage(
              url: accessory.imageUrl,
              garmentId: accessory.id,
              fit: BoxFit.cover,
              borderRadius: 10,
            ),
          ),
        ),
      ),
    );
  }

  /// Only the edge a user could actually scroll toward shows its arrow —
  /// re-checked on every scroll update (and once after first layout, since
  /// the controller has no metrics until then).
  void _updateBackgroundScrollArrows() {
    if (!_backgroundScrollController.hasClients) return;
    final position = _backgroundScrollController.position;
    final canLeft = position.pixels > 4;
    final canRight = position.pixels < position.maxScrollExtent - 4;
    if (canLeft == _canScrollBackgroundLeft &&
        canRight == _canScrollBackgroundRight) {
      return;
    }
    setState(() {
      _canScrollBackgroundLeft = canLeft;
      _canScrollBackgroundRight = canRight;
    });
  }

  /// Horizontally swipeable row of bundled background photos — tapping one
  /// selects it immediately, no separate picker page needed since there
  /// are only a handful of backgrounds.
  Widget _buildBackgroundSelector() {
    return EdgeFadeScrim(
      edgeWidth: 28,
      leftIcon: Icons.chevron_left,
      rightIcon: Icons.chevron_right,
      leftVisible: _canScrollBackgroundLeft,
      rightVisible: _canScrollBackgroundRight,
      child: SizedBox(
        height: 170,
        child: ListView.separated(
          controller: _backgroundScrollController,
          scrollDirection: Axis.horizontal,
          itemCount: BackgroundOption.all.length,
          separatorBuilder: (_, _) =>
              const SizedBox(width: _backgroundCardSpacing),
          itemBuilder: (context, i) =>
              _buildBackgroundCard(BackgroundOption.all[i], i),
        ),
      ),
    );
  }

  static const _backgroundCardWidth = 120.0;
  static const _backgroundCardSpacing = AppDimens.sectionSpacing;

  /// Scrolls so the just-selected background at [index] is fully in view,
  /// centered in the row — tapping a card near either edge would otherwise
  /// leave it half cut off under the fade scrim.
  void _centerBackgroundCard(int index) {
    if (!_backgroundScrollController.hasClients) return;
    final position = _backgroundScrollController.position;
    final itemStart = index * (_backgroundCardWidth + _backgroundCardSpacing);
    final target =
        itemStart - (position.viewportDimension - _backgroundCardWidth) / 2;
    _backgroundScrollController.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Selected-state treatment (foreground border + checkmark badge) mirrors
  /// `GarmentCard`'s selected styling, so the same "picked" affordance reads
  /// consistently across the app.
  Widget _buildBackgroundCard(BackgroundOption background, int index) {
    final isSelected = background.id == _background.id;
    return GestureDetector(
      onTap: isOutfitLoading
          ? null
          : () {
              setState(() {
                _background = background;
                _backgroundCustomized = true;
              });
              _centerBackgroundCard(index);
            },
      child: SizedBox(
        width: _backgroundCardWidth,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Painted after the child (unlike `decoration`), so this stays
          // visible over the photo instead of being covered by it.
          foregroundDecoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderStrong, width: 1.5),
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(background.assetPath, fit: BoxFit.cover),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.scrimBackdrop],
                      ),
                    ),
                    child: Text(
                      background.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.bold12.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.styleSelected
                          : AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowResting,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: AppColors.textOnPrimary,
                            size: 14,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _showsBottomActionButton => widget.selectOnly
      ? (_hasSelection && _isModified)
      : (!isOutfitLoading &&
            _hasCoreSlots &&
            (widget.existingOutfit != null || _isModified));

  Widget _buildBottomBar() {
    if (widget.selectOnly) {
      return BottomActionButton(
        label: _l10n.confirm,
        onPressed: () => Navigator.pop(context, _selectedGarmentIds().toSet()),
        enabled: _hasSelection && _isModified,
      );
    }
    return BottomActionButton(
      label: _l10n.createOutfit,
      leading: Image.asset(
        'assets/images/ai_process_inv.png',
        width: 18,
        height: 18,
      ),
      onPressed: _startTryOn,
      // existingOutfit mode has no "nothing changed" case to guard against —
      // it's a fresh AI render either way, so it's worth allowing even with
      // the exact same garments (a same-garments variant is a legitimate
      // reason to hit "Create Another Version").
      enabled:
          !isOutfitLoading &&
          _hasCoreSlots &&
          (widget.existingOutfit != null || _isModified),
    );
  }

  Widget _slotRow({
    required String title,
    bool optional = false,
    bool showNoneOption = false,
    String? iconAsset,
    IconData? iconData,
    required Garment? value,
    required GarmentCategory category,
    required void Function(Garment g) onPicked,
    VoidCallback? onClear,
    // Match a Look extras — both no-ops for slots it doesn't touch.
    bool noCloseMatch = false,
    List<int> rankedGarmentIds = const [],
  }) {
    assert(iconAsset != null || iconData != null);
    final detail = value == null
        ? null
        : (value.color?.isNotEmpty == true ? value.color! : value.subCategory);
    final isInvalid =
        widget.selectOnly &&
        widget.validGarmentIds != null &&
        value != null &&
        value.id != null &&
        !widget.validGarmentIds!.contains(value.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              FieldLabel(title.toUpperCase()),
              if (optional) ...[
                const SizedBox(width: 4),
                Text(
                  '(${_l10n.optionalLabel.toUpperCase()})',
                  style: AppTextStyle.regular12.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        AppListCard(
          onTap: (isOutfitLoading || _isLoadingGarments)
              ? null
              : () async {
                  await _ensureFreshGarments();
                  if (!mounted) return;
                  final result = await Navigator.push<SelectGarmentResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SelectGarmentPage(
                        title: title,
                        category: category,
                        garments: _allGarments,
                        selected: value,
                        showNoneOption: showNoneOption,
                        rankedGarmentIds: rankedGarmentIds,
                      ),
                    ),
                  );
                  if (result == null) return;
                  if (result.garment != null) {
                    onPicked(result.garment!);
                  } else {
                    onClear?.call();
                  }
                },
          showArrow: true,
          // Matches the Customize header's height — only for the empty
          // placeholder state; a selected garment's image + detail line
          // still wants the taller default. 32 is as big as the leading
          // icon can get without the card growing past that same 56 (32 +
          // the 24 of vertical padding baked into AppListCard).
          minHeight: value == null ? 56 : 82,
          leadingSize: value == null ? 32 : 56,
          leadingAsset: (value == null && iconData == null) ? iconAsset : null,
          leading: value != null
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GarmentImage(
                      url: value.imageUrl,
                      garmentId: value.id,
                      width: 56,
                      height: 56,
                      memCacheWidth: 112,
                      memCacheHeight: 112,
                      borderRadius: 8,
                      fit: BoxFit.cover,
                    ),
                    if (isInvalid)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Icon(
                          Icons.error,
                          size: 16,
                          color: AppColors.error,
                          shadows: [
                            Shadow(color: AppColors.surface, blurRadius: 3),
                          ],
                        ),
                      ),
                  ],
                )
              : (iconData != null
                    ? Icon(iconData, size: 32, color: AppColors.icon)
                    : null),
          summary: detail?.isNotEmpty == true ? detail : null,
          child: Text(
            value != null
                ? value.name
                : (noCloseMatch ? _l10n.noCloseMatch : _l10n.notSelected),
            style: value == null
                ? AppTextStyle.regular16.copyWith(
                    color: AppColors.textSecondary,
                  )
                : AppTextStyle.bold16,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// "Upload a photo, match it to closet items" entry point — idle before a
/// reference photo has been matched ([referenceImagePath] null), the
/// active reference readout once one has. Same AI call-out treatment as
/// [UwearisInsightCard] (gradient tint, sparkle badge, "AI" tag).
class _MatchALookCard extends StatelessWidget {
  final String? referenceImagePath;
  final int matchedSlotCount;
  final VoidCallback onStart;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  const _MatchALookCard({
    required this.referenceImagePath,
    required this.matchedSlotCount,
    required this.onStart,
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
    return referenceImagePath != null ? _active(context) : _idle(context);
  }

  Widget _idle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onStart,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.uwearisCardTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Image.asset(
                'assets/images/camera.png',
                width: 28,
                height: 28,
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
                      SectionTitle(l10n.matchALookTitle),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          l10n.aiTag,
                          style: AppTextStyle.bold12.copyWith(
                            color: AppColors.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.matchALookSubtitle,
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Image.asset(
              'assets/images/page_arrow_right.png',
              width: AppDimens.iconSmallSize,
              height: AppDimens.iconSmallSize,
            ),
          ],
        ),
      ),
    );
  }

  /// Replaces [_idle] once a reference photo has been matched — same card
  /// chrome, now showing the reference thumbnail and how many slots it
  /// filled, plus Change/Remove actions instead of the whole card being one
  /// big tap target. No destructive-looking button: "Remove Reference Look"
  /// lives in the overflow menu per the design brief.
  Widget _active(BuildContext context) {
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
              File(referenceImagePath!),
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
          AppPopupMenu<_MatchALookCardAction>(
            onSelected: (action) {
              switch (action) {
                case _MatchALookCardAction.remove:
                  onRemove();
              }
            },
            items: [
              AppPopupMenu.item(
                value: _MatchALookCardAction.remove,
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
