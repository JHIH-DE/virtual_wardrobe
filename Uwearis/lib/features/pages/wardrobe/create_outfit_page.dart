import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_400.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/adjustment_options_provider.dart';
import '../../../core/providers/backgrounds_provider.dart';
import '../../../core/providers/points_provider.dart';
import '../../../core/providers/garments_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/outfits_provider.dart';
import '../../../core/providers/weather_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/services/base_service.dart';
import '../../../core/services/garment_recommendation_service.dart';
import '../../../core/services/match_look_service.dart';
import '../../../core/utils/debug_log.dart';
import '../../../core/utils/remaining_points.dart';
import '../../../core/utils/try_on_mixin.dart';
import '../../../data/background_option.dart';
import '../../../data/garment.dart';
import '../../../data/garment_adjustment.dart';
import '../../../data/match_a_look.dart';
import '../../../data/outfit.dart';
import '../../../data/style_type.dart';
import '../../../l10n/garment_localization.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/style_type_localization.dart';
import '../../widgets/common/app_divider.dart';
import '../../widgets/common/app_popup_menu.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/accent_pill_button.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/buttons/bottom_action_button.dart';
import '../../widgets/common/cards/app_card_shell.dart';
import '../../widgets/common/cards/app_list_card.dart';
import '../../widgets/common/cards/swipe_action_card.dart';
import '../../widgets/common/cards/category_tag.dart';
import '../../widgets/common/field_label.dart';
import '../../widgets/common/fields/number_stepper.dart';
import '../../widgets/common/images/dashed_border_painter.dart';
import '../../widgets/common/overlays/ai_consent_dialog.dart';
import '../../widgets/common/overlays/app_dialog.dart';
import '../../widgets/common/overlays/app_snack_bar.dart';
import '../../../core/utils/api_error_text.dart';
import '../../widgets/common/overlays/error_dialog.dart';
import '../../widgets/common/overlays/feedback_overlay.dart';
import '../../widgets/common/overlays/loading_overlay.dart';
import '../../widgets/common/overlays/photo_source_dialog.dart';
import '../../widgets/common/overlays/picker_sheet.dart';
import '../../widgets/common/overlays/try_on_dialogs.dart';
import '../../widgets/common/section_title.dart';
import '../../widgets/garment/garment_adjustment_sheet.dart';
import '../../widgets/garment/outfit_garment_row.dart';
import '../../widgets/outfit/outfit_background_field.dart';
import '../common/camera_capture_page.dart' show CameraFrameRatio;
import 'create_outfit_selection.dart';
import 'outfit_details_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;

/// No error state: a failed match shows a dialog and drops back to [idle].
enum _MatchALookStatus { idle, analyzing, matched }

enum _ReferenceLookCardAction { remove }

/// One "Outfit Items" row: a core slot pick ([slot] set; [topIndex] too for
/// a top) or an accessory ([accessoryIndex] set).
typedef _OutfitEntry = ({
  Garment garment,
  GarmentCategory category,
  OutfitSlot? slot,
  int? topIndex,
  int? accessoryIndex,
});

class CreateOutfitPage extends ConsumerStatefulWidget {
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

  const CreateOutfitPage({
    super.key,
    this.initialGarments = const [],
    this.onBack,
    this.initialMatchALookImagePath,
    this.targetGroupId,
    this.initialBackgroundId,
  });

  @override
  ConsumerState<CreateOutfitPage> createState() => _CreateOutfitPageState();
}

class _CreateOutfitPageState extends ConsumerState<CreateOutfitPage>
    with TryOnMixin {
  late OutfitSelection _outfit;

  /// `.active`: a soft-deleted garment can't be picked for a new outfit.
  List<Garment> get _garmentPool =>
      (ref.read(garmentsProvider).value ?? const []).active;

  bool get _garmentPoolLoading => ref.read(garmentsProvider).isLoading;

  _MatchALookStatus _matchALookStatus = _MatchALookStatus.idle;
  String? _referenceImagePath;
  // Match a Look's picks; a manual pick or removal drops the garment from
  // this set.
  final Set<int> _aiPickedIds = {};

  // An explicit pick; null = never touched, which shows (and sends) version
  // mode's initial background or the Fitting Room default.
  int? _pickedBackgroundId;
  // Ids generate answered BACKGROUND_NOT_FOUND for: never shown or sent
  // again, even while the list still holds them until its reload lands.
  final Set<int> _goneBackgroundIds = {};
  bool _backgroundPickerInFlight = false;
  // One list reload shared by every preview whose signed URL failed at once.
  Future<List<BackgroundOption>>? _backgroundRefresh;
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
  bool _isCompletingWithAi = false;
  // Bumped by a start or a Cancel, so a stale reply can't land.
  int _completeWithAiRun = 0;
  // Create Outfit's re-entrancy guard; Finish Outfit's is
  // [_isCompletingWithAi].
  bool _tryOnRequested = false;
  // Explicit picks only (garment id → key → code); anything absent gets the
  // backend's outfit-dependent default. Read through [_effectiveAdjustments].
  final GarmentAdjustments _garmentAdjustments = {};
  // Adjust Details' re-entrancy guard: a double tap while the table loads
  // would stack two sheets that overwrite each other's picks.
  bool _adjustSheetInFlight = false;
  bool _waitingForCloset = false;

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
    int? keepTopIndex,
    int? keepAccessoryIndex,
  }) {
    bool categoryFull(GarmentCategory c) {
      if (c == keepCategory) return false;
      switch (c) {
        case GarmentCategory.top:
          return _outfit.tops.length >= OutfitSelection.maxTops;
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
          return _outfit.accessoryGarments.length >=
              OutfitSelection.maxAccessories;
      }
    }

    final wornAccessoryKeys = <String>{};
    for (var i = 0; i < _outfit.accessories.length; i++) {
      if (i == keepAccessoryIndex) continue;
      final a = _outfit.accessories[i];
      if (a != null && a.subCategory.isNotEmpty) {
        wornAccessoryKeys.add(accessorySlotKey(a));
      }
    }

    final wornTopKeys = <String>{
      for (var i = 0; i < _outfit.tops.length; i++)
        if (i != keepTopIndex && _outfit.tops[i].subCategory.isNotEmpty)
          baseTopSlotKey(_outfit.tops[i].subCategory),
    };

    final coreIds = <int>{
      for (final g in _outfit.garments)
        if (g.id != null) g.id!,
    };

    return _garmentPool.where((g) {
      if (categoryFull(g.category)) return false;
      final isAccessory =
          g.category == GarmentCategory.accessory ||
          g.category == GarmentCategory.socks;
      if (isAccessory) {
        if (g.id != null && _outfit.accessoryIds.contains(g.id)) return false;
        if (g.subCategory.isNotEmpty &&
            wornAccessoryKeys.contains(accessorySlotKey(g))) {
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

  /// Brings the closet up to date before a pick. False when the picker
  /// shouldn't open (session expired).
  Future<bool> _ensureFreshGarments() async {
    setState(() => _waitingForCloset = true);
    try {
      await ref.read(garmentsProvider.notifier).refreshIfNeeded();
      // refreshIfNeeded doesn't wait for a load already running (the first
      // fetch, started by build's watch).
      if (ref.read(garmentsProvider).isLoading) {
        await ref.read(garmentsProvider.future);
      }
      return true;
    } on AuthExpiredException {
      if (!mounted) return false;
      await AuthExpiredHandler.handle(context);
      return false;
    } catch (e) {
      debugLog('_ensureFreshGarments failed: $e');
      return true;
    } finally {
      if (mounted) setState(() => _waitingForCloset = false);
    }
  }

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
        return _outfit.tops.isNotEmpty || _outfit.onePiece != null;
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
        ? OutfitSelection.fromGarments(widget.initialGarments)
        : OutfitSelection();
    _initialGarmentIds = _selectedGarmentIds().toSet();
    // No closet refresh here: Add Garment checks freshness itself, so
    // opening the page doesn't block on a reload.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sharedPath = widget.initialMatchALookImagePath;
      if (sharedPath != null && mounted) {
        _startMatchALookFlow(initialImagePath: sharedPath);
      }
    });
  }

  // Accessories are out of Match a Look's scope, so that role is never
  // applied.
  OutfitSlot? _slotFor(MatchALookRole role) {
    switch (role) {
      case MatchALookRole.top:
      case MatchALookRole.midLayer:
        return OutfitSlot.top;
      case MatchALookRole.outer:
        return OutfitSlot.outer;
      case MatchALookRole.bottom:
        return OutfitSlot.bottom;
      case MatchALookRole.onePiece:
        return OutfitSlot.onePiece;
      case MatchALookRole.shoes:
        return OutfitSlot.shoes;
      case MatchALookRole.accessory:
        return null;
    }
  }

  void _markManual(Garment g) {
    if (g.id != null) _aiPickedIds.remove(g.id);
  }

  int get _aiPickedCount =>
      _outfit.garments.where((g) => _aiPickedIds.contains(g.id)).length;

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
    if (!await ensureAiConsent(context) || !mounted) return;
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
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
      if (!mounted) return;
      setState(() => _matchALookStatus = _MatchALookStatus.idle);
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
        return sharedErrorCodeMessage(_l10n, e.errorCode) ??
            _l10n.matchALookFailed;
    }
  }

  void _applyMatchResult(String imagePath, MatchALookResult result) {
    var next = _outfit;
    final matchedTops = <Garment>[];
    final newAiIds = <int>{};

    for (final match in result.roles) {
      final slot = _slotFor(match.role);
      if (slot == null || !match.matched) continue;
      final garment = result.garments[match.selectedGarmentId];
      // An unknown garment id counts as no match.
      if (garment == null) continue;
      if (garment.id != null) newAiIds.add(garment.id!);
      if (slot == OutfitSlot.top) {
        matchedTops.add(garment);
      } else {
        next = next.withSlot(slot, garment);
      }
    }
    if (matchedTops.isNotEmpty) {
      // The look's tops lead; worn tops fill what's left unless the look
      // already has one interchangeable with them.
      String key(Garment g) => baseTopSlotKey(g.subCategory);
      final kept = next.tops.where(
        (t) => !matchedTops.any((m) => m.id == t.id || key(m) == key(t)),
      );
      next = next.copyWith(
        tops: [...matchedTops, ...kept].take(OutfitSelection.maxTops).toList(),
      );
    }

    setState(() {
      _outfit = next;
      _referenceImagePath = imagePath;
      _aiPickedIds
        ..clear()
        ..addAll(newAiIds);
      _matchALookStatus = _MatchALookStatus.matched;
    });
    _pruneGarmentAdjustments();
  }

  /// Also drops the garments Match a Look still holds (manual picks stay).
  /// The backend DELETE is best-effort: the next upload overwrites it.
  Future<void> _clearMatchALookSession() async {
    bool ai(Garment? g) => g != null && _aiPickedIds.contains(g.id);
    var next = _outfit.copyWith(
      tops: _outfit.tops.where((t) => !ai(t)).toList(),
    );
    for (final slot in [
      OutfitSlot.outer,
      OutfitSlot.bottom,
      OutfitSlot.onePiece,
      OutfitSlot.shoes,
    ]) {
      if (ai(next.garmentIn(slot))) next = next.withoutSlot(slot);
    }
    setState(() {
      _outfit = next;
      _aiPickedIds.clear();
      _referenceImagePath = null;
      _matchALookStatus = _MatchALookStatus.idle;
    });
    _pruneGarmentAdjustments();
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
    final coreIds = _outfit.garments.map((g) => g.id).whereType<int>();
    final accessoryIds = _outfit.accessoryGarments
        .map((g) => g.id)
        .whereType<int>();
    return {...coreIds, ...accessoryIds}.toList();
  }

  Future<void> _startTryOn() async {
    if (_tryOnRequested || isOutfitLoading || _isCompletingWithAi) return;
    setState(() => _tryOnRequested = true);
    // The result screen (or the outfit a version returns to) shows the balance.
    final overlay = Overlay.of(context, rootOverlay: true);
    final points = ref.read(pointsProvider.notifier);
    final l10n = _l10n;
    try {
      if (!await ensureAiConsent(context) || !mounted) return;
      final ids = _selectedGarmentIds();
      if (ids.isEmpty) return;

      if (tryOnOutfitId != 0) {
        await deleteOutfitJob(tryOnGroupId, tryOnOutfitId);
      }

      // Read before the await: the page may be gone when the render lands.
      final outfits = ref.read(outfitsProvider.notifier);
      final backgroundId = _resolveBackground().toSend;
      final outfit = await performTryOn(
        ids,
        groupId: widget.targetGroupId,
        backgroundId: backgroundId,
        adjustments: _effectiveAdjustments(),
        onLandedAfterLeave: (_) => unawaited(outfits.refresh()),
        confirmRetryWhileUnknown: () => showRetryWhileUnknownDialog(context),
      );
      if (outfit != null) {
        unawaited(announceRemainingPoints(overlay, l10n, points));
      }
      if (!mounted) return;

      if (outfit != null && _isVersionMode) {
        Navigator.pop<Outfit>(context, outfit);
      } else if (tryOnResultUrl != null) {
        await _showTryOnResult(ids);
      } else if (tryOnErrorMessage != null) {
        if (tryOnErrorCode == backgroundNotFoundErrorCode) {
          // Deleted after the list loaded: reload it, and drop a pick of it.
          ref.invalidate(backgroundsProvider);
          setState(() {
            if (backgroundId != null) _goneBackgroundIds.add(backgroundId);
            _pickedBackgroundId = null;
          });
        }
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

  /// Leaves mid-render. The render keeps going on the backend and, if it
  /// finishes, is kept and counted ([TryOnMixin]), so the user confirms.
  Future<void> _stopWaitingForRender() async {
    final stop = await showStopWaitingDialog(context);
    if (!stop || !mounted || !isOutfitLoading) return;
    final onBack = widget.onBack;
    if (onBack != null) {
      onBack();
    } else {
      Navigator.pop(context);
    }
  }

  bool get _isVersionMode => widget.targetGroupId != null;

  /// A new version identical to its source would just be a re-render —
  /// Regenerate already covers that. Version mode starts with no
  /// adjustment picks, so any pick is a change.
  bool get _isUnchangedVersion {
    if (!_isVersionMode) return false;
    final background = _resolveBackground();
    return setEquals(_selectedGarmentIds().toSet(), _initialGarmentIds) &&
        _effectiveAdjustments().isEmpty &&
        background.shown?.id == background.starting?.id;
  }

  /// The list for the displayed language (its labels follow it).
  FutureProvider<List<BackgroundOption>> get _backgroundsSource =>
      backgroundsFor(context);

  /// One read of the list: what the picker offers, what the field shows and
  /// what generate sends. Sent is always what's shown — the Fitting Room
  /// default included. Only until the list is in does version mode send its
  /// source's background unseen: a slow or failed list is no reason to lose
  /// that scene, and a deleted one comes back as BACKGROUND_NOT_FOUND.
  _BackgroundChoice _resolveBackground() {
    final loaded = ref.read(_backgroundsSource).value;
    final visible = loaded == null
        ? null
        : [
            for (final b in loaded)
              if (!_goneBackgroundIds.contains(b.id)) b,
          ];
    BackgroundOption? byId(int? id) =>
        id == null ? null : visible?.where((b) => b.id == id).firstOrNull;
    final starting =
        byId(widget.initialBackgroundId) ??
        (visible == null ? null : defaultBackground(visible));
    final shown = byId(_pickedBackgroundId) ?? starting;
    final initial = widget.initialBackgroundId;
    final toSend = visible != null
        ? shown?.id
        : _pickedBackgroundId ??
              (initial != null && !_goneBackgroundIds.contains(initial)
                  ? initial
                  : null);
    return (visible: visible, shown: shown, starting: starting, toSend: toSend);
  }

  /// Waits for the list only when there's none yet (a failed refresh keeps
  /// the one already shown); the guard covers that wait.
  Future<void> _openBackgroundPicker() async {
    if (_backgroundPickerInFlight) return;
    _backgroundPickerInFlight = true;
    try {
      if (_resolveBackground().visible == null) {
        try {
          await ref.read(_backgroundsSource.future);
        } on AuthExpiredException {
          if (!mounted) return;
          await AuthExpiredHandler.handle(context);
          return;
        } on SessionChangedException {
          return;
        } catch (e) {
          debugLog('CreateOutfitPage._openBackgroundPicker failed: $e');
          if (mounted) _showBackgroundsLoadFailed(e);
          return;
        }
      }
      // A render started during the wait owns the screen now.
      if (!mounted || isOutfitLoading) return;
      final background = _resolveBackground();
      final visible = background.visible ?? const [];
      if (visible.isEmpty) {
        _showBackgroundsLoadFailed(null);
        return;
      }
      final picked = await showBackgroundPickerSheet(
        context,
        options: visible,
        selectedId: background.shown?.id,
        onRefreshImageUrl: _refreshBackgroundImageUrl,
      );
      if (picked == null || !mounted || isOutfitLoading) return;
      setState(() => _pickedBackgroundId = picked.id);
    } finally {
      _backgroundPickerInFlight = false;
    }
  }

  /// [error] null: the list loaded but holds nothing to offer.
  void _showBackgroundsLoadFailed(Object? error) {
    showErrorDialog(
      context,
      message: error == null
          ? _l10n.backgroundsLoadFailed
          : apiErrorMessage(
              _l10n,
              error,
              fallback: _l10n.backgroundsLoadFailed,
            ),
      onRetry: () {
        // Runs after the dialog closes; the page may be gone by then.
        if (!mounted) return;
        ref.invalidate(_backgroundsSource);
        _openBackgroundPicker();
      },
    );
  }

  Future<String?> _refreshBackgroundImageUrl(
    BackgroundOption background,
  ) async {
    if (!mounted) return null;
    try {
      final backgrounds = await (_backgroundRefresh ??= ref
          .refresh(_backgroundsSource.future)
          .whenComplete(() => _backgroundRefresh = null));
      return backgrounds
          .where((b) => b.id == background.id)
          .firstOrNull
          ?.imageUrl;
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return null;
    } on SessionChangedException {
      return null;
    } catch (e) {
      debugLog('CreateOutfitPage._refreshBackgroundImageUrl failed: $e');
      return null;
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _isVersionMode
          ? _l10n.addVersionTitle
          : _l10n.quickActionAddOutfit,
      onBack: widget.onBack,
      actions: [
        ActionDiscButton(
          tooltip: _l10n.matchALookTitle,
          icon: const Icon(
            LucideIcons400.camera,
            size: ActionDisc.iconSize,
            color: AppColors.icon,
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
    // The background getters read it via ref.read; loaded up front so the
    // picker opens at once.
    ref.watch(_backgroundsSource);
    // Also prefetches, so Adjust Details opens without a wait.
    final adjustmentTable = ref.watch(_adjustmentOptions).value;
    // A system back mid-render takes the same Stop Waiting confirm.
    return PopScope(
      canPop: !isOutfitLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _stopWaitingForRender();
      },
      child: _buildPageStack(adjustmentTable),
    );
  }

  Widget _buildPageStack(Map<String, AdjustmentDefinition>? adjustmentTable) {
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
                BottomActionButton.scrollClearance(bodyContext),
              ),
              children: _buildCreateFlowBody(adjustmentTable),
            ),
          ),
          bottomNavigationBar: _buildBottomBar(),
        ),
        if (isOutfitLoading)
          Positioned.fill(
            child: LoadingOverlay(
              label: _l10n.generatingTryOnEllipsis,
              actionLabel: _l10n.stopWaiting,
              onAction: _stopWaitingForRender,
            ),
          ),
        // Only a pick waits on the closet; opening the page never does.
        if (_waitingForCloset && _garmentPoolLoading)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingClosetEllipsis),
          ),
        if (_matchALookStatus == _MatchALookStatus.analyzing)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.matchingLookEllipsis),
          ),
        if (_isCompletingWithAi)
          Positioned.fill(
            child: LoadingOverlay(
              label: _l10n.completingOutfitEllipsis,
              actionLabel: _l10n.cancel,
              onAction: _cancelCompleteWithAi,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildCreateFlowBody(
    Map<String, AdjustmentDefinition>? adjustmentTable,
  ) {
    return [
      if (_referenceImagePath != null) ...[
        _hInset(
          _ReferenceLookCard(
            referenceImagePath: _referenceImagePath!,
            matchedSlotCount: _aiPickedCount,
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
      _hInset(_buildYourOutfitRow(adjustmentTable)),
      _hInset(const AppDivider(spacing: AppDimens.sectionSpacing)),
      _hInset(
        OutfitBackgroundField(
          selected: _resolveBackground().shown,
          isLoading: ref.read(_backgroundsSource).isLoading,
          onTap: isOutfitLoading ? null : _openBackgroundPicker,
        ),
      ),
    ];
  }

  static const double _createFlowInset = 20;

  Widget _hInset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _createFlowInset),
    child: child,
  );

  static const double _addGarmentIconSize = 56;

  Widget _buildYourOutfitRow(
    Map<String, AdjustmentDefinition>? adjustmentTable,
  ) {
    final entries = _outfitEntries();
    return Column(
      children: [
        _buildAddGarmentRow(),
        for (final entry in entries) ...[
          const SizedBox(height: AppDimens.cardSpacing),
          _buildOutfitGarmentRow(entry, adjustmentTable),
        ],
      ],
    );
  }

  Widget _buildAddGarmentRow() {
    final exhausted =
        _garmentPool.isNotEmpty && _addGarmentCandidates().isEmpty;
    final enabled = !isOutfitLoading && !_waitingForCloset && !exhausted;
    final iconColor = enabled ? AppColors.icon : AppColors.hintText;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: AppListCard(
        onTap: enabled ? () => _pickGarmentForOutfit() : null,
        showArrow: true,
        minHeight: OutfitGarmentRow.minHeight,
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
          style: AppTextStyle.regular14.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitGarmentRow(
    _OutfitEntry entry,
    Map<String, AdjustmentDefinition>? adjustmentTable,
  ) {
    final g = entry.garment;
    final locked = _isLocked(g);
    final adjustedCount = _effectiveAdjustments()[g.id]?.length ?? 0;
    final canAdjust = _canAdjust(g, adjustmentTable);

    return SwipeActionCard(
      key: ValueKey((entry.slot, entry.topIndex, entry.accessoryIndex, g.id)),
      enabled: !isOutfitLoading,
      leadingActions: [
        if (canAdjust)
          SwipeAction(
            icon: Icons.tune,
            label: _l10n.adjustGarmentDetails,
            backgroundColor: AppColors.accent,
            onPressed: () => _showAdjustDetailsSheet(g),
          ),
      ],
      actions: [
        // The icon shows the current state; the label names the toggle.
        SwipeAction(
          icon: locked ? Icons.lock_outline : Icons.lock_open,
          label: locked ? _l10n.unlockGarment : _l10n.lockGarment,
          onPressed: () => _toggleLock(g),
        ),
        SwipeAction(
          icon: Icons.delete_outline,
          label: _l10n.remove,
          backgroundColor: AppColors.error,
          onPressed: () => _removeOutfitEntry(entry),
        ),
      ],
      child: OutfitGarmentRow(
        garment: g,
        category: entry.category,
        subtitleSuffix: adjustedCount > 0
            ? _l10n.garmentAdjustedCount(adjustedCount)
            : null,
        onTap: (isOutfitLoading || _waitingForCloset)
            ? null
            : () => _pickGarmentForOutfit(
                initial: entry.category,
                replaceSlot: entry.slot,
                replaceTopIndex: entry.topIndex,
                replaceAccessoryIndex: entry.accessoryIndex,
                current: g,
              ),
      ),
    );
  }

  /// Tops, then the other core slots, then accessories.
  List<_OutfitEntry> _outfitEntries() {
    final list = <_OutfitEntry>[
      for (var i = 0; i < _outfit.tops.length; i++)
        (
          garment: _outfit.tops[i],
          category: GarmentCategory.top,
          slot: OutfitSlot.top,
          topIndex: i,
          accessoryIndex: null,
        ),
    ];
    for (final slot in [
      OutfitSlot.outer,
      OutfitSlot.bottom,
      OutfitSlot.onePiece,
      OutfitSlot.shoes,
    ]) {
      final g = _outfit.garmentIn(slot);
      if (g != null) {
        list.add((
          garment: g,
          category: OutfitSelection.categoryFor(slot),
          slot: slot,
          topIndex: null,
          accessoryIndex: null,
        ));
      }
    }
    for (var i = 0; i < _outfit.accessories.length; i++) {
      final g = _outfit.accessories[i];
      if (g != null) {
        list.add((
          garment: g,
          category: g.category,
          slot: null,
          topIndex: null,
          accessoryIndex: i,
        ));
      }
    }
    return list;
  }

  void _removeOutfitEntry(_OutfitEntry entry) {
    setState(() {
      final slot = entry.slot;
      final topIndex = entry.topIndex;
      if (topIndex != null) {
        _outfit = _outfit.withoutTopAt(topIndex);
      } else if (slot != null) {
        _outfit = _outfit.withoutSlot(slot);
      } else if (entry.accessoryIndex != null) {
        _outfit = _outfit.withoutAccessoryAt(entry.accessoryIndex!);
      }
      _markManual(entry.garment);
      if (entry.garment.id != null) {
        _lockedGarmentIds.remove(entry.garment.id);
      }
    });
    _pruneGarmentAdjustments();
  }

  /// Whether [key] can be sent with the current outfit (generate answers 400
  /// otherwise): `hem` needs a bottom, `boots_pants` long trousers. A pick
  /// that can't is kept and applies once the outfit allows it.
  bool _keyFitsOutfit(String key) =>
      switch (GarmentAdjustmentKeyApi.fromApiValue(key)) {
        GarmentAdjustmentKey.hem => _outfit.bottom != null,
        GarmentAdjustmentKey.bootsPants =>
          _outfit.bottom?.isLongTrousers ?? false,
        _ => true,
      };

  /// The sheet's note for a pick waiting on the outfit. `hem` has none.
  String? _pendingNoteFor(String key) =>
      GarmentAdjustmentKeyApi.fromApiValue(key) ==
              GarmentAdjustmentKey.bootsPants &&
          !_keyFitsOutfit(key)
      ? _l10n.adjustmentNeedsLongTrousers
      : null;

  /// The table for the displayed locale.
  FutureProvider<Map<String, AdjustmentDefinition>> get _adjustmentOptions =>
      adjustmentOptionsProvider(
        LocaleNotifier.apiLocaleFor(Localizations.localeOf(context)),
      );

  /// Whether [g]'s row offers Adjust Details. Before [table] loads it goes by
  /// the garment's own keys; a tap then loads it or reports the failure.
  bool _canAdjust(Garment g, Map<String, AdjustmentDefinition>? table) =>
      table == null
      ? g.adjustmentOptions.isNotEmpty
      : _definitionsFor(g, table).isNotEmpty;

  List<AdjustmentDefinition> _definitionsFor(
    Garment g,
    Map<String, AdjustmentDefinition> definitions,
  ) {
    final keys = g.adjustmentOptions.toSet();
    return [
      for (final d in definitions.values)
        if (keys.contains(d.key) && d.options.isNotEmpty) d,
    ];
  }

  /// Cuffed pants and pants tucked into boots can't go in one request; the
  /// newer pick wins, as the backend does for a regenerate.
  void _dropConflictingPantsPick(Map<String, int> newPicks) {
    final cuff = GarmentAdjustmentKey.pantCuff.apiValue;
    final boots = GarmentAdjustmentKey.bootsPants.apiValue;
    final String clash;
    final int clashCode;
    if (newPicks[cuff] == pantCuffCuffed) {
      (clash, clashCode) = (boots, bootsPantsTucked);
    } else if (newPicks[boots] == bootsPantsTucked) {
      (clash, clashCode) = (cuff, pantCuffCuffed);
    } else {
      return;
    }
    for (final id in _garmentAdjustments.keys.toList()) {
      final picks = _garmentAdjustments[id]!;
      if (picks[clash] != clashCode) continue;
      final rest = {...picks}..remove(clash);
      if (rest.isEmpty) {
        _garmentAdjustments.remove(id);
      } else {
        _garmentAdjustments[id] = rest;
      }
    }
  }

  /// The garment with [id] in the current outfit, if it's still there.
  Garment? _outfitGarment(int id) {
    for (final g in [..._outfit.garments, ..._outfit.accessoryGarments]) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// The picks this outfit can send: garments still in it, keys whose outfit
  /// condition is met. The only source for a request, so a stale or pending
  /// pick can't 400.
  GarmentAdjustments _effectiveAdjustments() {
    final result = <int, Map<String, int>>{};
    for (final e in _garmentAdjustments.entries) {
      final g = _outfitGarment(e.key);
      if (g == null) continue;
      final picks = {
        for (final p in e.value.entries)
          if (g.adjustmentOptions.contains(p.key) && _keyFitsOutfit(p.key))
            p.key: p.value,
      };
      if (picks.isNotEmpty) result[e.key] = picks;
    }
    return result;
  }

  /// Forgets the picks of garments that left the outfit, so one added back
  /// starts from Default. Picks waiting on an outfit condition stay.
  void _pruneGarmentAdjustments() {
    _garmentAdjustments.removeWhere((id, _) => _outfitGarment(id) == null);
  }

  Future<void> _showAdjustDetailsSheet(Garment g) async {
    final id = g.id;
    if (id == null || _adjustSheetInFlight) return;
    _adjustSheetInFlight = true;
    try {
      await _openAdjustDetailsSheet(id);
    } finally {
      _adjustSheetInFlight = false;
    }
  }

  Future<void> _openAdjustDetailsSheet(int id) async {
    final options = _adjustmentOptions;
    final Map<String, AdjustmentDefinition> definitions;
    try {
      definitions = await ref.read(options.future);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
      return;
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
      return;
    } catch (e) {
      debugLog('CreateOutfitPage._showAdjustDetailsSheet failed: $e');
      if (!mounted) return;
      showErrorDialog(
        context,
        message: apiErrorMessage(
          _l10n,
          e,
          fallback: _l10n.adjustmentOptionsLoadFailed,
        ),
        onRetry: () {
          ref.invalidate(options);
          final g = _outfitGarment(id);
          if (g != null) _showAdjustDetailsSheet(g);
        },
      );
      return;
    }
    if (!mounted) return;
    // The outfit may have changed while the table loaded.
    final g = _outfitGarment(id);
    if (g == null) return;
    final available = _definitionsFor(g, definitions);
    if (available.isEmpty) {
      showAppSnackBar(context, _l10n.noGarmentAdjustments);
      return;
    }
    // A pick for a key the garment no longer offers (its closure changed)
    // has no row; it's never sent, and a sheet closed unchanged keeps it.
    final listed = {
      for (final d in available) d.key: {for (final o in d.options) o.code},
    };
    final picks = await showGarmentAdjustmentSheet(
      context,
      definitions: available,
      selected: {
        for (final e in (_garmentAdjustments[id] ?? const {}).entries)
          if (listed[e.key]?.contains(e.value) ?? false) e.key: e.value,
      },
      notes: {for (final d in available) d.key: ?_pendingNoteFor(d.key)},
    );
    if (picks == null || !mounted || _outfitGarment(id) == null) return;
    setState(() {
      _garmentAdjustments.remove(id);
      _dropConflictingPantsPick(picks);
      if (picks.isNotEmpty) _garmentAdjustments[id] = picks;
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

  /// [replaceSlot] (+ [replaceTopIndex] for a top) / [replaceAccessoryIndex]
  /// pin the pick to the row being swapped; [current] shows as selected in
  /// the picker.
  Future<void> _pickGarmentForOutfit({
    GarmentCategory? initial,
    OutfitSlot? replaceSlot,
    int? replaceTopIndex,
    int? replaceAccessoryIndex,
    Garment? current,
  }) async {
    if (_waitingForCloset) return;
    if (!await _ensureFreshGarments() || !mounted) return;
    final candidates = _addGarmentCandidates(
      keepCategory: replaceSlot != null
          ? OutfitSelection.categoryFor(replaceSlot)
          : null,
      keepTopIndex: replaceTopIndex,
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
      replaceTopIndex: replaceTopIndex,
      replaceAccessoryIndex: replaceAccessoryIndex,
    );
  }

  /// Manual picks are always locked so Finish Outfit keeps them.
  void _assignGarment(
    Garment g, {
    OutfitSlot? replaceSlot,
    int? replaceTopIndex,
    int? replaceAccessoryIndex,
  }) {
    setState(() {
      if (replaceSlot != null &&
          g.category == OutfitSelection.categoryFor(replaceSlot)) {
        if (replaceTopIndex != null && replaceTopIndex < _outfit.tops.length) {
          _outfit = _outfit.withTopAt(replaceTopIndex, g);
        } else if (replaceSlot != OutfitSlot.top) {
          _outfit = _outfit.withSlot(replaceSlot, g);
        } else {
          _outfit = _outfit.withTop(g);
        }
        _markManual(g);
        _lockGarment(g);
        return;
      }
      if (replaceAccessoryIndex != null &&
          OutfitSelection.isAccessoryGarment(g) &&
          replaceAccessoryIndex < _outfit.accessories.length) {
        _outfit = _outfit.withAccessoryAt(replaceAccessoryIndex, g);
        _lockGarment(g);
        return;
      }
      _placeGarment(g, lock: true);
    });
    _pruneGarmentAdjustments();
  }

  /// Call inside `setState`.
  /// Call inside `setState`. An accessory that can't go in is still
  /// unmarked as Match a Look's, but not locked.
  void _placeGarment(Garment g, {required bool lock}) {
    _markManual(g);
    final next = _outfit.withGarment(g);
    if (next == null) return;
    _outfit = next;
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
      _outfit = _outfit.keepingOnly(keepGarmentIds);

      for (final g in recommended) {
        if (kept(g)) continue; // already kept in place above
        // Only kept garments remain, and the backend may still suggest a
        // second piece for a locked slot — that must not displace it.
        if (!_outfit.hasRoomFor(g)) continue;
        _placeGarment(g, lock: false);
      }
    });
    _pruneGarmentAdjustments();
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
      title: _l10n.finishOutfit,
      subtitle: _l10n.finishOutfitDescription,
      trailing: AccentPillButton(
        label: _l10n.finishWithAi,
        enabled: enabled,
        onPressed: _completeWithAi,
      ),
      child: LayoutBuilder(
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
    if (!await ensureAiConsent(context)) return;
    if (!mounted || _isCompletingWithAi) return;
    final run = ++_completeWithAiRun;
    final session = AuthStorage.sessionEpoch;
    setState(() => _isCompletingWithAi = true);
    try {
      // null lets the backend decide.
      final temperatureC =
          _weatherTempOverrideC ??
          (await _fetchWeatherBestEffort())?.todayMeanTemp;
      // The advice is charged: never send it under the next account.
      if (AuthStorage.sessionEpoch != session) throw SessionChangedException();
      final keep = {..._lockedGarmentIds};
      final ids = await GarmentRecommendationService().completeOutfit(
        garmentIds: keep.toList(),
        excludeGarmentIds: _excludedGarmentIds.toList(),
        style: _completeWithAiStyle,
        temperatureC: temperatureC,
      );
      if (!mounted || run != _completeWithAiRun) return;
      _applyCompletedOutfit(ids, keepGarmentIds: keep);
    } on AuthExpiredException {
      if (!mounted || run != _completeWithAiRun) return;
      await AuthExpiredHandler.handle(context);
    } on SessionChangedException {
      // Its session ended meanwhile; whatever ended it owns the UI now.
    } catch (e) {
      debugLog('Complete with AI failed: $e');
      if (!mounted || run != _completeWithAiRun) return;
      showErrorDialog(
        context,
        message: apiErrorMessage(
          _l10n,
          e,
          fallback: _l10n.completeWithAiUnavailable,
        ),
      );
    } finally {
      if (mounted && run == _completeWithAiRun) {
        setState(() => _isCompletingWithAi = false);
      }
    }
  }

  /// The request can't be aborted; its reply is ignored when it lands.
  void _cancelCompleteWithAi() {
    _completeWithAiRun++;
    setState(() => _isCompletingWithAi = false);
  }

  /// The button stays visible; a tap that can't create explains why
  /// instead. Needs every core category the closet has; a closet with none
  /// of them falls back to "at least 2 garments".
  Future<void> _onCreatePressed() async {
    if (isOutfitLoading ||
        _garmentPoolLoading ||
        _tryOnRequested ||
        _isCompletingWithAi) {
      return;
    }
    if (_coreChecklist.isEmpty) {
      if (_selectedGarmentIds().length < 2) {
        await _showMissingItemsDialog(const []);
        return;
      }
    } else if (!_coreComplete) {
      await _showMissingItemsDialog(
        _coreChecklist.where((c) => !_coreSlotMet(c)).toList(),
      );
      return;
    }
    if (_isUnchangedVersion) {
      await _showVersionUnchangedDialog();
      return;
    }
    await _startTryOn();
  }

  /// Empty [missing] means the "at least 2 garments" fallback.
  Future<void> _showMissingItemsDialog(List<GarmentCategory> missing) async {
    final addGarment = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.createOutfitMissingItemsTitle,
        body: missing.isEmpty ? _l10n.createOutfitMinGarmentsBody : null,
        content: missing.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _l10n.createOutfitMissingItemsBody,
                    textAlign: TextAlign.center,
                    style: AppTextStyle.medium16,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in missing)
                        CategoryTag(label: c.localizedLabel(context)),
                    ],
                  ),
                ],
              ),
        primaryLabel: _l10n.addGarment,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (addGarment != true || !mounted) return;
    await _pickGarmentForOutfit(
      initial: missing.isEmpty ? null : missing.first,
    );
  }

  Future<void> _showVersionUnchangedDialog() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.createVersionUnchangedTitle,
        body: _l10n.createVersionUnchangedBody,
      ),
    );
  }

  Widget _buildBottomBar() {
    return BottomActionButton(
      label: _isVersionMode ? _l10n.createVersion : _l10n.createOutfit,
      onPressed: _onCreatePressed,
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

/// See [_CreateOutfitPageState._resolveBackground]. [visible] is null while the
/// list loads or after it failed to; so are [shown] and [starting].
typedef _BackgroundChoice = ({
  List<BackgroundOption>? visible,
  BackgroundOption? shown,
  BackgroundOption? starting,
  int? toSend,
});
