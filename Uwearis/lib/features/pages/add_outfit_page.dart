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
import '../../data/image_edit_result.dart';
import '../../data/match_a_look.dart';
import '../../data/occasion_type.dart';
import '../../data/outfit.dart';
import '../../data/background_option.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/occasion_type_localization.dart';
import '../widgets/common/app_divider.dart';
import '../widgets/common/app_popup_menu.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/edge_fade_mask.dart';
import '../widgets/common/expand_arrow_icon.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/fields/number_stepper.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/occasion_picker_sheet.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_image.dart';
import 'image_editor_page.dart';
import 'outfit_details_page.dart';
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

/// One garment shown in the create flow's "Your Outfit" list — either a
/// core slot pick ([slot] set) or an accessory ([accessoryIndex] set).
/// [category] is the label shown in the row's subtitle.
typedef _OutfitEntry = ({
  Garment garment,
  GarmentCategory category,
  _Slot? slot,
  int? accessoryIndex,
});

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

class AddOutfitPage extends ConsumerStatefulWidget {
  final List<Garment> initialGarments;

  /// In [selectOnly] mode, the fixed garment pool the picker draws from (a
  /// trip's suitcase). In the normal create flow it's unused — the pool is
  /// the app-wide closet from [garmentsProvider].
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
  ConsumerState<AddOutfitPage> createState() => _AddOutfitPageState();
}

class _AddOutfitPageState extends ConsumerState<AddOutfitPage> with TryOnMixin {
  late _OutfitSelection _outfit;
  late _OutfitSelection _initialOutfit;
  late Set<int> _initialAccessoryIds;

  /// The garment pool the picker draws from. In selectOnly mode it's the
  /// fixed subset the caller passed (a trip's suitcase); otherwise it's the
  /// app-wide closet straight from [garmentsProvider] — same source every
  /// other garment-picking screen uses, no local copy. `build` watches the
  /// provider so this stays current; callers read it via `ref.read`.
  List<Garment> get _garmentPool => widget.selectOnly
      ? (widget.preloadedGarments ?? const [])
      : (ref.read(garmentsProvider).value ?? const []);

  bool get _garmentPoolLoading =>
      !widget.selectOnly && ref.read(garmentsProvider).isLoading;

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

  // Whether the collapsible section below "Your Outfit" is open — the
  // create flow's "BACKGROUND" header ([_buildBackgroundSectionHeader]) and
  // the selectOnly/edit flow's "Accessories & Background" panel
  // ([_buildCustomizationBlock]) share this single flag since a page
  // instance only ever renders one of those two bodies.
  bool _customizationExpanded = false;
  // Always exactly one trailing empty ("+") slot until the max is reached.
  final List<Garment?> _accessories = [null];
  BackgroundOption _background = BackgroundOption.all.first;
  // Whether the user actually touched the background picker — [_background] always
  // has a concrete default, so this is the only way to tell "picked
  // Fitting Room on purpose" apart from "never opened the picker".
  bool _backgroundCustomized = false;

  final ScrollController _backgroundScrollController = ScrollController();

  // "Complete with AI" state — garment ids the user has locked (AI must keep
  // them), ids the AI has already recommended and the user then moved past
  // (a fresh run should try something else instead of repeating them — see
  // `_applyCompletedOutfit`), the occasion this outfit is for (independent
  // of Lifestyle's per-weekday routine), and whether a completion request is
  // in flight.
  final Set<int> _lockedGarmentIds = {};
  final Set<int> _excludedGarmentIds = {};
  OccasionType _completeWithAiOccasion = OccasionType.casual;
  // Absolute temperature (°C) Finish Outfit should dress for. null = follow
  // the live weather reading (the stepper still shows that reading as its
  // starting value); set once the user nudges the stepper, then it wins for
  // this outfit only (not persisted).
  double? _weatherTempOverrideC;
  bool _isCompletingWithAi = false;
  // Synchronous re-entrancy guards for the two costly AI actions on this
  // page — set before the first `await` in their handlers and cleared in a
  // `finally`, so a double-tap during a pre-flight `await` (a delete
  // round-trip, the Finish Outfit dialog) can't start a second AI render.
  // See CLAUDE.md "Guarding costly / mutating actions against
  // double-invocation".
  bool _tryOnRequested = false;
  bool _completeWithAiInFlight = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Whether this page renders the vertical "Your Outfit" list layout — the
  /// default "New Outfit" flow (reached from the Home quick action) and
  /// [AddOutfitPage.existingOutfit] ("Create Another Version") both use it;
  /// only [AddOutfitPage.selectOnly] (trip day editor) keeps the older
  /// per-category slot layout ([_buildSlotFlowBody]), since that mode has no
  /// generate step and a different bottom action ("Confirm", not "Create
  /// Outfit"). This is purely a layout switch — submission gating for
  /// existingOutfit vs. a fresh outfit is decided separately by
  /// `widget.existingOutfit == null` where it actually matters
  /// ([_showsBottomActionButton], [_buildBottomBar]), not by this flag.
  bool get _isCreateFlow => !widget.selectOnly;

  /// Stable display order for the "Add garment" picker's category tabs.
  static const List<GarmentCategory> _addCategoryOrder = [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outer,
    GarmentCategory.onePiece,
    GarmentCategory.shoes,
    GarmentCategory.socks,
    GarmentCategory.accessory,
  ];

  /// Garments the "Add garment" picker should offer, given what the outfit
  /// already has: a category with no free slot drops out entirely (you can't
  /// wear a second pair of trousers), and an accessory type already worn
  /// drops out (no second pair of sunglasses). Core garments already in the
  /// outfit don't reappear either. [keepCategory] / [keepAccessoryIndex]
  /// re-admit whatever the user is currently swapping.
  List<Garment> _addGarmentCandidates({
    GarmentCategory? keepCategory,
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
        wornAccessoryKeys.add(_accessorySlotKey(a.subCategory));
      }
    }

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
            wornAccessoryKeys.contains(_accessorySlotKey(g.subCategory))) {
          return false;
        }
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

  // In selectOnly mode, a category whose only occurrence is in the
  // pre-existing selection (e.g. its category has since vanished from the
  // pool entirely) still gets a slot — otherwise a stale pick would
  // disappear silently instead of showing its warning badge. Categories
  // with nothing in the pool AND nothing currently assigned stay hidden.
  late final Set<GarmentCategory> _initialCategories = widget.initialGarments
      .map((g) => g.category)
      .toSet();

  bool _hasCategory(GarmentCategory category) =>
      _garmentPool.any((g) => g.category == category) ||
      ((widget.selectOnly || widget.existingOutfit != null) &&
          _initialCategories.contains(category));

  /// Called before opening the picker: nudge [garmentsProvider] to re-fetch
  /// if its list is empty or its image URLs are stale (a no-op otherwise).
  /// Skipped in selectOnly mode (that pool is a fixed subset).
  Future<void> _ensureFreshGarments() async {
    if (widget.selectOnly) return;
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
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

  /// The Top/Bottom/Shoes core categories a complete try-on needs — only
  /// the ones the closet actually has, in that order. Drives whether
  /// [_startTryOn] runs Finish Outfit first to fill the gaps.
  List<GarmentCategory> get _coreChecklist => const [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.shoes,
  ].where(_hasCategory).toList();

  /// Whether a core checklist slot is satisfied. A one-piece counts for both
  /// Top and Bottom.
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
    if (!widget.selectOnly) {
      // Same as every other garment screen: lean on garmentsProvider and let
      // it re-fetch only when its own list is empty or its image URLs are
      // stale (a no-op if My Closet just refreshed). Deferred to post-frame —
      // `refreshIfNeeded` synchronously flips the provider to AsyncLoading,
      // which Riverpod forbids during a build/initState (matches how
      // closet_page / outfits_page / trip_suitcase_page schedule it).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(garmentsProvider.notifier).refreshIfNeeded();
      });
    }
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
    // Synchronous re-entrancy guard — set before any `await`. The
    // `deleteOutfitJob` path below yields before `performTryOn` raises
    // `isOutfitLoading` (and `BottomActionButton`'s hide animation keeps the
    // old button tappable for ~200ms), so a double-tap could otherwise fire
    // two AI renders.
    if (_tryOnRequested || isOutfitLoading || _isCompletingWithAi) return;
    setState(() => _tryOnRequested = true);
    try {
      // If any core slot (Top / Bottom / Shoes) is still empty, run Finish
      // Outfit first to fill the gaps, then render. A closet with none of
      // those three categories skips this (Finish Outfit can't help there).
      if (_isCreateFlow &&
          widget.existingOutfit == null &&
          _coreChecklist.isNotEmpty &&
          !_coreComplete) {
        await _completeWithAi();
        if (!mounted) return;
        // Finish Outfit couldn't complete the core slots — it already
        // surfaced the failure, so just stop here.
        if (!_coreComplete) return;
      }

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
    } finally {
      if (mounted) setState(() => _tryOnRequested = false);
    }
  }

  Future<void> _showTryOnResult(List<int> garmentIds) async {
    // OutfitDetailsPage pops `true` when the user keeps the outfit ("Save"),
    // `false`/null when they discard it or back out.
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
    setState(() {
      _accessories
        ..clear()
        ..add(null);
      _background = BackgroundOption.all.first;
      _backgroundCustomized = false;
      _customizationExpanded = false;
    });
    if (saved == true) {
      showFeedbackOverlay(context, message: _l10n.outfitSaved);
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
                : _l10n.newVersion)
          : _l10n.quickActionAddOutfit,
      onBack: widget.onBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the closet changes (loads, or a garment is added/edited
    // elsewhere). _garmentPool / _garmentPoolLoading read it via ref.read.
    if (!widget.selectOnly) ref.watch(garmentsProvider);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          extendBody: true,
          appBar: _buildAppBar(),
          body: ListView(
            physics: const ClampingScrollPhysics(),
            // Create flow goes edge-to-edge so its horizontal card rows can
            // scroll flush to the screen edges; its non-scrolling children
            // re-apply the inset via [_hInset].
            padding: EdgeInsets.fromLTRB(
              _isCreateFlow ? 0 : 20,
              24,
              _isCreateFlow ? 0 : 20,
              _showsBottomActionButton
                  ? AppDimens.bottomActionBtnClearance
                  : 24,
            ),
            children: _isCreateFlow
                ? _buildCreateFlowBody()
                : _buildSlotFlowBody(),
          ),
          bottomNavigationBar: _buildBottomBar(),
        ),
        if (isOutfitLoading)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.creatingOutfitsEllipsis),
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

  /// The per-category slot layout — [AddOutfitPage.selectOnly] (trip day
  /// editor) only now; every other mode uses [_buildCreateFlowBody].
  List<Widget> _buildSlotFlowBody() {
    return [
      _buildInstructions(),
      const SizedBox(height: AppDimens.sectionSpacing),
      ..._buildTopSlots(),
      ..._buildOuterSlot(),
      ..._buildBottomSlot(),
      ..._buildOnePieceSlot(),
      ..._buildShoesSlot(),
      _buildCustomizationBlock(),
    ];
  }

  /// The default "New Outfit" layout: Match a Look, the collapsible
  /// BACKGROUND section, then the "Your Outfit" header (with the Finish
  /// Outfit action) and a vertical list of the picked garments (+ an "Add
  /// garment" row). Occasion/temperature live in the Finish Outfit dialog.
  List<Widget> _buildCreateFlowBody() {
    return [
      _hInset(
        _MatchALookCard(
          referenceImagePath: _referenceImagePath,
          matchedSlotCount: _aiPopulatedSlots.length,
          onStart: _startMatchALookFlow,
          onChange: _changeReferenceLook,
          onRemove: _clearMatchALookSession,
        ),
      ),
      const SizedBox(height: AppDimens.sectionSpacing),
      _hInset(_buildBackgroundSectionHeader()),
      AnimatedCrossFade(
        key: const ValueKey('backgroundSection'),
        duration: const Duration(milliseconds: 150),
        crossFadeState: _customizationExpanded
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        firstChild: Column(
          children: [
            const SizedBox(height: AppDimens.cardHeaderGap),
            _buildBackgroundSelector(),
          ],
        ),
        secondChild: const SizedBox.shrink(),
      ),
      const SizedBox(height: AppDimens.sectionSpacing),
      _hInset(
        Row(
          children: [
            FieldLabel(_l10n.yourOutfitLabel.toUpperCase()),
            const Spacer(),
            AccentPillButton(
              label: _l10n.finishOutfit,
              icon: Icons.auto_awesome,
              // Finish Outfit works with 0, 1, or many locked garments —
              // it never requires a selection first.
              enabled:
                  !isOutfitLoading &&
                  !_isCompletingWithAi &&
                  !_completeWithAiInFlight &&
                  !_garmentPoolLoading,
              onPressed: _handleCompleteWithAiTap,
            ),
          ],
        ),
      ),
      const SizedBox(height: AppDimens.cardHeaderGap),
      _hInset(_buildYourOutfitRow()),
    ];
  }

  static const double _createFlowInset = 20;

  Widget _hInset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _createFlowInset),
    child: child,
  );

  // Shared row sizing so the "Add garment" row and every garment row line up.
  static const double _outfitRowMinHeight = 64;
  // The "Add garment" row's dashed placeholder icon — unrelated to the real
  // garment thumbnail width below, which bleeds edge-to-edge instead.
  static const double _addGarmentIconSize = 56;
  static const double _outfitThumbnailWidth = 78;

  /// Vertical list: a pinned "Add garment" row on top, then one row per
  /// current pick (core slots first, then accessories — see
  /// [_outfitEntries]).
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
    // Every category/type is already covered — nothing left worth adding.
    final exhausted =
        _garmentPool.isNotEmpty && _addGarmentCandidates().isEmpty;
    final enabled = !isOutfitLoading && !_garmentPoolLoading && !exhausted;
    final iconColor = enabled ? AppColors.icon : AppColors.hintText;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AppListCard(
        onTap: enabled ? () => _pickGarmentForOutfit() : null,
        showArrow: true,
        minHeight: _outfitRowMinHeight,
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

  /// Unlike [_buildAddGarmentRow] (built on the padded [AppListCard] shell),
  /// this hand-rolls its container so the thumbnail can bleed edge-to-edge
  /// with the row's top/bottom — [AppListCard]'s uniform padding wraps its
  /// `leading` slot too, which would leave a gap around the image.
  Widget _buildOutfitGarmentRow(_OutfitEntry entry) {
    final g = entry.garment;
    final locked = _isLocked(g);
    final categoryLabel = entry.category.localizedLabel(context);
    final subtitle = g.subCategory.isNotEmpty
        ? '$categoryLabel · ${g.subCategory}'
        : categoryLabel;

    return GestureDetector(
      // opaque so the whole row opens the picker — the Container has a
      // `decoration`, not a `color`, and the contained thumbnail leaves a
      // lot of transparent padding. The Lock/✕ badges are deeper and still
      // win their own area.
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
        constraints: const BoxConstraints(minHeight: _outfitRowMinHeight),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
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
                      ),
                      const SizedBox(width: 8),
                      // Discs stay exactly where they were (24px, 8px apart,
                      // hard against the row's right edge); the hit target
                      // only grows vertically — there's no horizontal room
                      // between two tightly-packed badges, but the row is
                      // >=64px tall.
                      CardCornerBadge(
                        icon: locked ? Icons.lock : Icons.lock_open,
                        backgroundColor: locked
                            ? AppColors.primary
                            : AppColors.placeholderSurface,
                        iconColor: locked
                            ? AppColors.textOnPrimary
                            : AppColors.icon,
                        hitTargetSize: const Size(24, AppDimens.minTouchTarget),
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
            ],
          ),
        ),
      ),
    );
  }

  /// Flat, ordered view of the current picks (core slots first, then
  /// accessories) that the "Your Outfit" row renders. Middle layer keeps the
  /// [GarmentCategory.top] label since a mid layer *is* a top.
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

  /// Opens the tab-mode [SelectGarmentPage] and files whatever the user picks
  /// into the matching slot (or accessory list). [replaceSlot] /
  /// [replaceAccessoryIndex] pin the result to that exact slot when swapping
  /// an existing card, and keep that slot's category/type available in the
  /// otherwise smart-filtered picker. [current] is the garment being
  /// swapped — it shows up marked as selected so the user can see what's
  /// already in that slot.
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

  /// Manual "Add garment" pick — always locked (the user chose it on
  /// purpose, so "Complete with AI" must keep it; see [_placeGarment]).
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

  /// Auto-places [g] into whichever slot its category maps to — an empty
  /// top before middle, single-slot categories overwrite outright, and
  /// accessory categories append respecting `_maxAccessories` and
  /// no-duplicate-id. Shared by the manual "Add garment" flow
  /// ([_assignGarment], `lock: true`) and applying a Complete-with-AI
  /// result ([_applyCompletedOutfit], `lock: false`) — call inside
  /// `setState`.
  void _placeGarment(Garment g, {required bool lock}) {
    switch (g.category) {
      case GarmentCategory.top:
        final slot = _outfit.top == null
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

  /// Applies [GarmentRecommendationService.completeOutfit]'s result — the
  /// full desired outfit, locked ids included verbatim. Locked
  /// slots/accessories are left untouched; everything unlocked is cleared
  /// first (so a completion that changes its mind about an unlocked slot
  /// actually removes what was there), then the recommended garments are
  /// placed, unlocked, so the user can still adjust or lock them further.
  ///
  /// The ids the AI actually chose (i.e. everything returned that wasn't
  /// already locked in by the user) are remembered in
  /// [_excludedGarmentIds], so a later "Complete with AI" tap asks for
  /// something different instead of risking the same suggestion again.
  void _applyCompletedOutfit(List<int> garmentIds) {
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
        garmentIds.where((id) => !_lockedGarmentIds.contains(id)),
      );
      if (!_isLocked(_outfit.top)) _outfit = _outfit.copyWith(clearTop: true);
      if (!_isLocked(_outfit.middle)) {
        _outfit = _outfit.copyWith(clearMiddle: true);
      }
      if (!_isLocked(_outfit.outer)) {
        _outfit = _outfit.copyWith(clearOuter: true);
      }
      if (!_isLocked(_outfit.bottom)) {
        _outfit = _outfit.copyWith(clearBottom: true);
      }
      if (!_isLocked(_outfit.onePiece)) {
        _outfit = _outfit.copyWith(clearOnePiece: true);
      }
      if (!_isLocked(_outfit.shoes)) {
        _outfit = _outfit.copyWith(clearShoes: true);
      }
      for (var i = 0; i < _accessories.length; i++) {
        if (!_isLocked(_accessories[i])) _accessories[i] = null;
      }
      _accessories.removeWhere((g) => g == null);
      if (_accessories.length < _maxAccessories) _accessories.add(null);

      for (final g in recommended) {
        if (_isLocked(g)) continue; // already kept in place above
        _placeGarment(g, lock: false);
      }
    });
  }

  static const double _defaultTemperatureC = 20;

  /// "Occasion   [icon] Casual  ›" row shown in the Finish Outfit dialog —
  /// same layout as Lifestyle's weekday rows; tapping it opens the shared
  /// [showOccasionPickerSheet]. [onChanged] rebuilds the host dialog after a
  /// pick (page `setState` alone doesn't reach the dialog route).
  Widget _buildOccasionPickerRow({VoidCallback? onChanged}) {
    return InkWell(
      onTap: () async {
        final selected = await showOccasionPickerSheet(
          context,
          current: _completeWithAiOccasion,
          title: _l10n.occasionFieldLabel,
        );
        if (selected == null || !mounted) return;
        setState(() => _completeWithAiOccasion = selected);
        onChanged?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _l10n.occasionFieldLabel,
                style: AppTextStyle.semibold16,
              ),
            ),
            Icon(_completeWithAiOccasion.icon, size: 18, color: AppColors.icon),
            const SizedBox(width: 6),
            Text(
              _completeWithAiOccasion.localizedLabel(context),
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Image.asset(
              'assets/images/page_arrow_right.png',
              width: 20,
              height: 20,
              color: AppColors.textSecondary,
              colorBlendMode: BlendMode.srcIn,
            ),
          ],
        ),
      ),
    );
  }

  /// Best-effort current weather — used both to seed the temperature
  /// stepper and, unless the user has overridden it, as the value sent to
  /// [GarmentRecommendationService.completeOutfit]. Never throws.
  Future<WeatherData?> _fetchWeatherBestEffort() async {
    try {
      return await ref
          .read(weatherProvider.future)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  Future<void> _handleCompleteWithAiTap() async {
    // Re-entrancy guard — the dialog and `_completeWithAi` both run before
    // `_isCompletingWithAi` is raised, so a double-tap could otherwise stack
    // two dialogs / fire two recommendation requests.
    if (_isCompletingWithAi || _completeWithAiInFlight) return;
    setState(() => _completeWithAiInFlight = true);
    try {
      final proceed = await _showFinishOutfitDialog();
      if (proceed == true && mounted) await _completeWithAi();
    } finally {
      if (mounted) setState(() => _completeWithAiInFlight = false);
    }
  }

  /// The "Finish Outfit" dialog opened from the header pill — a short
  /// explainer plus the Occasion / Weather knobs, confirmed with "Finish
  /// with AI". Shown every time (no first-use gating). Wrapped in a
  /// [Consumer] so the stepper seeds from the live weather reading, and a
  /// [StatefulBuilder] so occasion/temperature edits rebuild it. Returns
  /// `true` when the user confirms.
  Future<bool?> _showFinishOutfitDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Consumer(
          builder: (context, ref, _) {
            final liveTemp = ref
                .watch(weatherProvider)
                .maybeWhen(data: (w) => w.temp, orElse: () => null);
            final tempC =
                _weatherTempOverrideC ?? liveTemp ?? _defaultTemperatureC;
            return AppDialog(
              title: _l10n.finishOutfit,
              contentToPrimarySpacing: 8,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _l10n.finishOutfitPromptBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildOccasionPickerRow(
                    onChanged: () => setDialogState(() {}),
                  ),
                  const AppDivider(topSpacing: 0, bottomSpacing: 0),
                  NumberStepper(
                    variant: NumberStepperVariant.row,
                    label: _l10n.temperatureFieldLabel,
                    valueLabel: '${tempC.round()}°C',
                    onDecrement: () {
                      setState(() => _weatherTempOverrideC = tempC - 1);
                      setDialogState(() {});
                    },
                    onIncrement: () {
                      setState(() => _weatherTempOverrideC = tempC + 1);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              primaryLabel: _l10n.finishWithAi,
              primaryIcon: Icons.auto_awesome,
              onPrimary: () => Navigator.pop(dialogContext, true),
              secondaryLabel: _l10n.cancel,
              onSecondary: () => Navigator.pop(dialogContext),
            );
          },
        ),
      ),
    );
  }

  /// Calls [GarmentRecommendationService.completeOutfit] with the currently
  /// locked garments + occasion + weather (best-effort). Style comes from
  /// the user's own Style Taste analysis, resolved silently on the backend
  /// — nothing to fetch or send from here. Text-only: no Try-On image is
  /// generated here, only [_startTryOn] (behind "Create Outfit") does that.
  Future<void> _completeWithAi() async {
    if (_isCompletingWithAi) return;
    setState(() => _isCompletingWithAi = true);
    try {
      // The user's explicit override wins; otherwise the live reading (or
      // null when there's neither — the backend then decides on its own).
      final temperatureC =
          _weatherTempOverrideC ?? (await _fetchWeatherBestEffort())?.temp;
      final ids = await GarmentRecommendationService().completeOutfit(
        garmentIds: _lockedGarmentIds.toList(),
        excludeGarmentIds: _excludedGarmentIds.toList(),
        occasion: _completeWithAiOccasion,
        temperatureC: temperatureC,
      );
      if (!mounted) return;
      _applyCompletedOutfit(ids);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('Complete with AI failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.completeWithAiUnavailable)));
    } finally {
      if (mounted) setState(() => _isCompletingWithAi = false);
    }
  }

  // Only ever shown in selectOnly mode — see _buildSlotFlowBody.
  Widget _buildInstructions() {
    return Text(
      _l10n.editDayOutfitInstruction,
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

  /// Collapsible panel (collapsed by default) holding the Accessories
  /// picker — selectOnly mode only now (see [_buildSlotFlowBody]); that mode
  /// just picks garment ids for a caller and has no generate step to apply
  /// a background to, so unlike the create flow's own collapsible Background
  /// section ([_buildBackgroundSectionHeader]), this one never shows
  /// Background at all.
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
                      _l10n.accessoriesLabel,
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
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  List<Garment> get _accessoryCandidates => _garmentPool
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
        builder: (_) => SelectGarmentPage(
          title: _l10n.selectItemTitle('Accessory'),
          category: null,
          garments: _accessoryCandidatesFor(index),
          selected: _accessories[index],
          showNoneOption: true,
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
        // opaque so the whole 72px tile responds — CustomPaint only strokes
        // a dashed border, leaving just the centered "+" glyph tappable.
        behavior: HitTestBehavior.opaque,
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
      // opaque so the 6px margin around the thumbnail is tappable too.
      behavior: HitTestBehavior.opaque,
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

  /// Tappable "BACKGROUND" header for the create flow — collapsed by
  /// default, reusing [_customizationExpanded] (the same flag the
  /// [selectOnly]/edit flow's [_buildCustomizationBlock] uses; the two
  /// bodies are mutually exclusive per page instance, so sharing it doesn't
  /// conflict).
  Widget _buildBackgroundSectionHeader() => _collapsibleSectionHeader(
    label: _l10n.backgroundLabel.toUpperCase(),
    expanded: _customizationExpanded,
    onToggle: () =>
        setState(() => _customizationExpanded = !_customizationExpanded),
    trailing: _customizationExpanded
        ? null
        : _sectionSummaryText(_background.label),
  );

  /// The grey one-line summary shown in a collapsed
  /// [_collapsibleSectionHeader] — OUTFIT CONTEXT's "Casual · 16°C",
  /// BACKGROUND's selected preset name.
  Widget _sectionSummaryText(String text) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AppTextStyle.regular12.copyWith(color: AppColors.textSecondary),
  );

  /// Shared "FieldLabel + expand arrow" tappable header behind the create
  /// flow's two collapsible sections (OUTFIT CONTEXT and BACKGROUND).
  /// [trailing] sits just before the arrow — used for each section's
  /// collapsed-state summary.
  Widget _collapsibleSectionHeader({
    required String label,
    required bool expanded,
    required VoidCallback onToggle,
    Widget? trailing,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: Row(
        children: [
          FieldLabel(label),
          const SizedBox(width: 12),
          Expanded(
            child: trailing == null
                ? const SizedBox.shrink()
                : Align(alignment: Alignment.centerRight, child: trailing),
          ),
          const SizedBox(width: 8),
          ExpandArrowIcon(expanded: expanded),
        ],
      ),
    );
  }

  /// Horizontally swipeable row of bundled background photos — tapping one
  /// selects it immediately, no separate picker page needed since there
  /// are only a handful of backgrounds.
  Widget _buildBackgroundSelector() {
    return SizedBox(
      height: 170,
      child: EdgeFadeMask(
        controller: _backgroundScrollController,
        child: ListView.separated(
          controller: _backgroundScrollController,
          scrollDirection: Axis.horizontal,
          // In the create flow the row is full-bleed; keep the first/last card
          // at the page inset. The customization block already pads it.
          padding: _isCreateFlow
              ? const EdgeInsets.symmetric(horizontal: _createFlowInset)
              : EdgeInsets.zero,
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
  // Matched to the "Your Outfit" row's card gap.
  static const _backgroundCardSpacing = AppDimens.cardSpacing;

  /// Scrolls so the just-selected background at [index] is fully in view,
  /// centered in the row — tapping a card near either edge would otherwise
  /// leave it half cut off under the fade scrim.
  void _centerBackgroundCard(int index) {
    if (!_backgroundScrollController.hasClients) return;
    final position = _backgroundScrollController.position;
    final leadingPad = _isCreateFlow ? _createFlowInset : 0.0;
    final itemStart =
        leadingPad + index * (_backgroundCardWidth + _backgroundCardSpacing);
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
                      color: isSelected ? AppColors.accent : AppColors.surface,
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

  /// Create Outfit is always shown in the create flow now — if Top/Bottom/
  /// Shoes aren't all picked, [_startTryOn] runs Finish Outfit to fill the
  /// gaps before rendering. It's only *disabled* while a costly AI action is
  /// already running, or — for a closet with none of those three categories,
  /// where Finish Outfit can't help — until at least 2 garments are picked.
  bool get _createFlowReady {
    if (isOutfitLoading ||
        _garmentPoolLoading ||
        _tryOnRequested ||
        _isCompletingWithAi ||
        _completeWithAiInFlight) {
      return false;
    }
    if (_coreChecklist.isEmpty) return _selectedGarmentIds().length >= 2;
    return true;
  }

  bool get _showsBottomActionButton {
    if (widget.selectOnly) return _hasSelection && _isModified;
    // Create Outfit is always present in the create flow (it just toggles
    // enabled — see _buildBottomBar), so its clearance stays reserved.
    // "Create Another Version" keeps its own readiness rule.
    if (widget.existingOutfit == null) return true;
    return !isOutfitLoading &&
        !_tryOnRequested &&
        _hasCoreSlots &&
        (widget.existingOutfit != null || _isModified);
  }

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
      // reason to hit "Create Another Version"). Keyed on existingOutfit,
      // not _isCreateFlow — see _showsBottomActionButton.
      enabled: widget.existingOutfit == null
          ? _createFlowReady
          : (!isOutfitLoading &&
                !_tryOnRequested &&
                _hasCoreSlots &&
                (widget.existingOutfit != null || _isModified)),
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
          onTap: (isOutfitLoading || _garmentPoolLoading)
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
                        garments: _garmentPool,
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
      // opaque so the whole card opens Match a Look — the gradient
      // `_cardDecoration` doesn't absorb hits, leaving only the icon/text/
      // arrow tappable.
      behavior: HitTestBehavior.opaque,
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
