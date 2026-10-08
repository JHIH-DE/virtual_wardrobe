import 'dart:io';

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
import '../widgets/common/field_label.dart';
import '../widgets/common/fields/number_stepper.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/feedback_overlay.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/occasion_picker_sheet.dart';
import '../widgets/common/overlays/photo_source_dialog.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_image.dart';
import '../widgets/outfit/outfit_background_section.dart';
import 'camera_capture_page.dart' show CameraFrameRatio;
import 'outfit_details_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;

/// The page's own identity for each garment slot — distinct from
/// [GarmentCategory] because Top and Mid Layer share [GarmentCategory.top]
/// but are two different slots. Used to key Match a Look's per-slot state
/// ([_AddOutfitPageState._aiPopulatedSlots]).
enum _Slot { top, middle, outer, bottom, onePiece, shoes }

/// Where the Match a Look flow currently stands. There's no persisted
/// "error" state — a failed match just reports itself via a dialog and
/// drops back to [idle] so the card stays usable (see
/// [_AddOutfitPageState._runMatchALook]).
enum _MatchALookStatus { idle, analyzing, matched }

enum _ReferenceLookCardAction { remove }

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
  final VoidCallback? onBack;

  /// Set by `SharedMediaHandler` when this page was opened from a photo
  /// shared in from another app — runs the Match a Look flow with that
  /// photo automatically on open, the same continuation
  /// [_AddOutfitPageState._startMatchALookFlow] otherwise only reaches once
  /// the user taps the Match a Look card and picks a photo themselves.
  final String? initialMatchALookImagePath;

  const AddOutfitPage({
    super.key,
    this.initialGarments = const [],
    this.onBack,
    this.initialMatchALookImagePath,
  });

  @override
  ConsumerState<AddOutfitPage> createState() => _AddOutfitPageState();
}

class _AddOutfitPageState extends ConsumerState<AddOutfitPage> with TryOnMixin {
  late _OutfitSelection _outfit;

  /// The garment pool the picker draws from — the app-wide closet straight
  /// from [garmentsProvider], same source every other garment-picking
  /// screen uses, no local copy. `build` watches the provider so this stays
  /// current; callers read it via `ref.read`. `.active`: a soft-deleted
  /// garment can't be picked for a new outfit.
  List<Garment> get _garmentPool =>
      (ref.read(garmentsProvider).value ?? const []).active;

  bool get _garmentPoolLoading => ref.read(garmentsProvider).isLoading;

  // Match a Look session state — see clearMatchALookSession-equivalent
  // _clearMatchALookSession below for what "clearing" actually resets.
  _MatchALookStatus _matchALookStatus = _MatchALookStatus.idle;
  String? _referenceImagePath;
  // Slots currently filled by Match a Look's #1 pick rather than a manual
  // choice — this is this page's selectionSource tracking: a slot in this
  // set is "referenceMatch", everything else (including slots the user
  // manually cleared or replaced) is implicitly "manual".
  final Set<_Slot> _aiPopulatedSlots = {};

  static const int _maxAccessories = 4;

  // Always exactly one trailing empty ("+") slot until the max is reached.
  final List<Garment?> _accessories = [null];
  BackgroundOption _background = BackgroundOption.all.first;
  // Whether the user actually touched the background picker — [_background] always
  // has a concrete default, so this is the only way to tell "picked
  // Fitting Room on purpose" apart from "never opened the picker".
  bool _backgroundCustomized = false;

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
  /// wear a second pair of trousers), an accessory type already worn drops
  /// out (no second pair of sunglasses), and a base-layer top already worn
  /// drops out its alternatives the same way (wearing a T-shirt hides Polo
  /// shirt too — see [baseTopSlotKey]; a genuine mid-layer piece like a
  /// cardigan is a different key and still offered). Core garments already
  /// in the outfit don't reappear either. [keepCategory] / [keepSlot] /
  /// [keepAccessoryIndex] re-admit whatever the user is currently swapping.
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

  /// Called before opening the picker: nudge [garmentsProvider] to re-fetch
  /// if its list is empty or its image URLs are stale (a no-op otherwise).
  Future<void> _ensureFreshGarments() async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
  }

  /// Ids of whichever accessory slots are actually filled — [_accessories]
  /// always keeps one trailing `null` "+" slot, which this excludes.
  Set<int> get _accessoryIds => _accessories
      .whereType<Garment>()
      .map((g) => g.id)
      .whereType<int>()
      .toSet();

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
    // Same as every other garment screen: lean on garmentsProvider and let
    // it re-fetch only when its own list is empty or its image URLs are
    // stale (a no-op if My Closet just refreshed). Deferred to post-frame —
    // `refreshIfNeeded` synchronously flips the provider to AsyncLoading,
    // which Riverpod forbids during a build/initState (matches how
    // closet_page / outfits_page / trip_suitcase_page schedule it).
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
  /// drops out of the tracking set regardless of what's now in it.
  void _markSlotManual(_Slot slot) {
    _aiPopulatedSlots.remove(slot);
  }

  /// [initialImagePath] uses a photo already in hand (from
  /// `SharedMediaHandler`) instead of opening the camera/album picker.
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
      showErrorDialog(context, message: _matchLookErrorMessage(e));
    } catch (e, st) {
      debugLog('Match a Look failed: $e', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() => _matchALookStatus = _MatchALookStatus.idle);
      showErrorDialog(context, message: _l10n.matchALookFailed);
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
  /// there's no reason to keep them apart client-side either — this is what
  /// Create Outfit's generate call reads from.
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
      // If any core slot (Top / Bottom / Shoes) is still empty, ask before
      // letting AI fill the gaps — "No" leaves the user to pick them. A
      // closet with none of those three categories skips this (AI can't
      // help there).
      if (_coreChecklist.isNotEmpty && !_coreComplete) {
        final missing = _coreChecklist.where((c) => !_coreSlotMet(c)).toList();
        final proceed = await _showOutfitIncompleteDialog(missing);
        if (proceed != true || !mounted) return;
        // Only the missing slots get filled — everything already picked
        // stays, locked or not (Match a Look's picks are unlocked).
        await _completeWithAi(keepGarmentIds: _selectedGarmentIds().toSet());
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
        backgroundId: _backgroundCustomized ? _background.backgroundId : null,
      );
      if (!mounted) return;

      if (tryOnResultUrl != null) {
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
    if (saved == true) {
      showFeedbackOverlay(context, message: _l10n.outfitSaved);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _l10n.quickActionAddOutfit,
      onBack: widget.onBack,
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: AppDimens.toolbarHeight,
            minHeight: AppDimens.toolbarHeight,
          ),
          tooltip: _l10n.matchALookTitle,
          icon: Image.asset(
            'assets/images/camera.png',
            width: AppDimens.toolbarActionIconSize,
            height: AppDimens.toolbarActionIconSize,
          ),
          // With a reference already matched this swaps it out, same as
          // the reference card's "Change".
          onPressed: _referenceImagePath != null
              ? _changeReferenceLook
              : _startMatchALookFlow,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the closet changes (loads, or a garment is added/edited
    // elsewhere). _garmentPool / _garmentPoolLoading read it via ref.read.
    ref.watch(garmentsProvider);
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          extendBody: true,
          appBar: _buildAppBar(),
          body: ListView(
            physics: const ClampingScrollPhysics(),
            // Edge-to-edge so the horizontal card rows can scroll flush to
            // the screen edges; non-scrolling children re-apply the inset
            // via [_hInset]. Create Outfit is always present (it just
            // toggles enabled — see _buildBottomBar), so this clearance is
            // unconditional.
            padding: const EdgeInsets.fromLTRB(
              0,
              24,
              0,
              AppDimens.bottomActionBtnClearance,
            ),
            children: _buildCreateFlowBody(),
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

  /// The default "New Outfit" layout: the Match a Look reference card (once
  /// matched), the collapsible BACKGROUND section, then the "Outfit Items"
  /// header (with the Auto-Complete action) and a vertical list of the
  /// picked garments (+ an "Add garment" row). Occasion/temperature live in
  /// the Auto-Complete dialog.
  List<Widget> _buildCreateFlowBody() {
    return [
      // The app bar's Match a Look icon is the entry point; this card only
      // appears once a reference photo has been matched.
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
      OutfitBackgroundSection(
        selected: _background,
        horizontalInset: _createFlowInset,
        onSelected: isOutfitLoading
            ? null
            : (background) => setState(() {
                _background = background;
                _backgroundCustomized = true;
              }),
      ),
      const SizedBox(height: AppDimens.sectionSpacing),
      _hInset(
        Row(
          children: [
            FieldLabel(_l10n.outfitItemsLabel.toUpperCase()),
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

  // Fixed row height so the "Add garment" row and every garment row are
  // always exactly the same height — a garment row's name can wrap to 2
  // lines (long product names), which would otherwise make that row taller
  // than "Add garment"'s fixed 2-line (title + hint) content.
  static const double _outfitRowHeight = 84;
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
      child: SizedBox(
        height: _outfitRowHeight,
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
        height: _outfitRowHeight,
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
                      // between two tightly-packed badges, but the row is a
                      // fixed _outfitRowHeight tall.
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
  /// no-duplicate-id. A second top that's just another base-layer
  /// alternative to the one already worn (see [baseTopSlotKey] — e.g. a
  /// Polo shirt picked while a T-shirt is already the top) replaces it
  /// instead of stacking into mid layer; only a genuinely different piece
  /// (a sweater/cardigan) is a real mid layer. Shared by the manual "Add
  /// garment" flow ([_assignGarment], `lock: true`) and applying a
  /// Complete-with-AI result ([_applyCompletedOutfit], `lock: false`) —
  /// call inside `setState`.
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
  ///
  /// [keepGarmentIds] overrides which ids count as "locked" for this one
  /// application (see [_completeWithAi]).
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
                    style: AppTextStyle.medium16,
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

  /// Shown when Create Outfit is tapped with core slots ([missing]) still
  /// empty: explains why it can't render yet and asks whether AI should
  /// fill them in. `true` = Yes; "No" / dismiss leaves the user to edit.
  Future<bool?> _showOutfitIncompleteDialog(List<GarmentCategory> missing) {
    final parts = missing
        .map((c) => c.localizedLabel(context))
        .join(_l10n.listSeparator);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AppDialog(
        title: _l10n.outfitIncompleteTitle,
        body: _l10n.outfitIncompleteBody(parts),
        primaryLabel: _l10n.yes,
        onPrimary: () => Navigator.pop(dialogContext, true),
        secondaryLabel: _l10n.no,
        onSecondary: () => Navigator.pop(dialogContext, false),
      ),
    );
  }

  /// Calls [GarmentRecommendationService.completeOutfit] with the currently
  /// locked garments + occasion + weather (best-effort). Style comes from
  /// the user's own Style Taste analysis, resolved silently on the backend
  /// — nothing to fetch or send from here. Text-only: no Try-On image is
  /// generated here, only [_startTryOn] (behind "Create Outfit") does that.
  ///
  /// [keepGarmentIds] defaults to the locked garments (the Finish Outfit
  /// pill: unlocked picks may be swapped). Create Outfit passes every
  /// selected id so the AI only fills what's missing.
  Future<void> _completeWithAi({Set<int>? keepGarmentIds}) async {
    if (_isCompletingWithAi) return;
    setState(() => _isCompletingWithAi = true);
    try {
      // The user's explicit override wins; otherwise the live reading (or
      // null when there's neither — the backend then decides on its own).
      final temperatureC =
          _weatherTempOverrideC ?? (await _fetchWeatherBestEffort())?.temp;
      final keep = keepGarmentIds ?? {..._lockedGarmentIds};
      final ids = await GarmentRecommendationService().completeOutfit(
        garmentIds: keep.toList(),
        excludeGarmentIds: _excludedGarmentIds.toList(),
        occasion: _completeWithAiOccasion,
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

  Widget _buildBottomBar() {
    return BottomActionButton(
      label: _l10n.createOutfit,
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

/// The active Match a Look reference readout — the reference thumbnail and
/// how many slots it filled, plus Change/Remove. Same AI call-out treatment
/// as [UwearisInsightCard] (gradient tint, sparkle). No destructive-looking
/// button: "Remove Reference Look" lives in the overflow menu per the
/// design brief.
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
