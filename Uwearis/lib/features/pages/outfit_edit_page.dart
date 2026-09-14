import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/garment.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/garment/garment_image.dart';
import 'select_garment_page.dart' show SelectGarmentPage;

/// The page's own identity for each garment slot — distinct from
/// [GarmentCategory] because Top and Mid Layer share [GarmentCategory.top]
/// but are two different slots.
enum _Slot { top, middle, outer, bottom, onePiece, shoes }

/// One garment shown in the "Your Outfit" list — either a core slot pick
/// ([slot] set) or an accessory ([accessoryIndex] set). [category] is the
/// label shown in the row's subtitle.
typedef _OutfitEntry = ({
  Garment garment,
  GarmentCategory category,
  _Slot? slot,
  int? accessoryIndex,
});

/// The user's in-progress slot-by-slot garment picks. Purely local UI state
/// (no fromJson/toJson) — not a synced domain model, so it lives here
/// rather than in lib/data/.
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

/// Lets the user pick which garments from a fixed pool (e.g. a trip's
/// suitcase, or the whole closet) make up an outfit — the "Change Garments"
/// flow off [TripDetailsPage]'s day header, and Outfit Details' "Create
/// Another Version" picker. Pops the selected garment ids as a `Set<int>` on
/// Confirm; `null` if the user backs out without confirming.
///
/// Same "Add garment" vertical-list UI as `AddOutfitPage`'s create flow — a
/// pinned "Add garment" row plus one card per current pick, tapping any card
/// reopens the picker to swap it — this page just has no AI/try-on/
/// background/Match-a-Look concepts, and draws from a fixed
/// [preloadedGarments] pool instead of the app-wide closet.
class OutfitEditPage extends StatefulWidget {
  final List<Garment> initialGarments;

  /// The fixed garment pool the picker draws from (a trip's suitcase, or the
  /// whole closet) — unlike AddOutfitPage's create flow, there's no
  /// app-wide closet fetch here.
  final List<Garment> preloadedGarments;
  final VoidCallback? onBack;

  /// Garment ids NOT in this set get a warning badge on their card — e.g.
  /// an outfit item that's since been removed from the trip's suitcase.
  final Set<int>? validGarmentIds;

  /// App bar title override — defaults to [AppLocalizations.selectGarmentsTitle].
  /// Outfit Details' "+ New Version" entry point passes
  /// [AppLocalizations.addVersionTitle] instead, since this same picker
  /// reads as a different flow from there.
  final String? title;

  const OutfitEditPage({
    super.key,
    this.initialGarments = const [],
    required this.preloadedGarments,
    this.onBack,
    this.validGarmentIds,
    this.title,
  });

  @override
  State<OutfitEditPage> createState() => _OutfitEditPageState();
}

class _OutfitEditPageState extends State<OutfitEditPage> {
  late _OutfitSelection _outfit;
  late _OutfitSelection _initialOutfit;
  late Set<int> _initialAccessoryIds;

  static const int _maxAccessories = 4;

  // Always exactly one trailing empty ("+") slot until the max is reached.
  final List<Garment?> _accessories = [null];

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// The fixed pool this picker draws from — no app-wide closet fetch, no
  /// loading state: the caller already has it in hand.
  List<Garment> get _garmentPool => widget.preloadedGarments;

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

  bool get _showsBottomActionButton => _hasSelection && _isModified;

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
  /// [_pickGarmentForOutfit] otherwise maintains.
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

  /// Garments the "Add garment" picker should offer, given what the outfit
  /// already has: a category with no free slot drops out entirely (you
  /// can't wear a second pair of trousers), and an accessory type already
  /// worn drops out (no second pair of sunglasses). Core garments already in
  /// the outfit don't reappear either. [keepCategory] / [keepAccessoryIndex]
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
        wornAccessoryKeys.add(accessorySlotKey(a.subCategory));
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
            wornAccessoryKeys.contains(accessorySlotKey(g.subCategory))) {
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

  /// Every selected garment id — core slots and accessories together as one
  /// flat list, since the caller (Confirm) treats them the same way.
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

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: widget.title ?? _l10n.selectGarmentsTitle,
      onBack: widget.onBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          _showsBottomActionButton ? AppDimens.bottomActionBtnClearance : 24,
        ),
        children: [
          _buildInstructions(),
          const SizedBox(height: AppDimens.sectionSpacing),
          FieldLabel(_l10n.yourOutfitLabel.toUpperCase()),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _buildYourOutfitRow(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return BottomActionButton(
      label: _l10n.confirm,
      onPressed: () => Navigator.pop(context, _selectedGarmentIds().toSet()),
      enabled: _showsBottomActionButton,
    );
  }

  Widget _buildInstructions() {
    return Text(
      _l10n.editDayOutfitInstruction,
      textAlign: TextAlign.left,
      style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
    );
  }

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
    final iconColor = exhausted ? AppColors.hintText : AppColors.icon;
    return Opacity(
      opacity: exhausted ? 0.5 : 1,
      child: AppListCard(
        onTap: exhausted ? null : () => _pickGarmentForOutfit(),
        showArrow: true,
        minHeight: _outfitRowMinHeight,
        leading: SizedBox(
          width: _addGarmentIconSize,
          height: _addGarmentIconSize,
          child: CustomPaint(
            painter: DashedBorderPainter(
              color: exhausted ? AppColors.hintText : AppColors.borderStrong,
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
    final categoryLabel = entry.category.localizedLabel(context);
    final subtitle = g.subCategory.isNotEmpty
        ? '$categoryLabel · ${g.subCategory}'
        : categoryLabel;
    final isInvalid =
        widget.validGarmentIds != null &&
        g.id != null &&
        !widget.validGarmentIds!.contains(g.id);

    return GestureDetector(
      // opaque so the whole row opens the picker — the Container has a
      // `decoration`, not a `color`, and the contained thumbnail leaves a
      // lot of transparent padding. The ✕ badge is deeper and still wins
      // its own area.
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickGarmentForOutfit(
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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GarmentImage(
                          url: g.imageUrl,
                          garmentId: g.id,
                          fit: BoxFit.contain,
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
                      CardCornerBadge(
                        icon: Icons.close,
                        backgroundColor: AppColors.placeholderSurface,
                        iconColor: AppColors.icon,
                        hitTargetSize: const Size(24, AppDimens.minTouchTarget),
                        onTap: () => _removeOutfitEntry(entry),
                      ),
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
        _outfit = _outfit.copyWith(
          clearTop: slot == _Slot.top,
          clearMiddle: slot == _Slot.middle,
          clearOuter: slot == _Slot.outer,
          clearBottom: slot == _Slot.bottom,
          clearOnePiece: slot == _Slot.onePiece,
          clearShoes: slot == _Slot.shoes,
        );
      } else if (entry.accessoryIndex != null) {
        _accessories.removeAt(entry.accessoryIndex!);
        _accessories.removeWhere((g) => g == null);
        if (_accessories.length < _maxAccessories) _accessories.add(null);
      }
    });
  }

  /// Opens the tab-mode [SelectGarmentPage] and files whatever the user picks
  /// into the matching slot (or accessory list). [replaceSlot] /
  /// [replaceAccessoryIndex] pin the result to that exact slot when swapping
  /// an existing card, and keep that slot's category/type available in the
  /// otherwise smart-filtered picker. [current] is the garment being
  /// swapped — it shows up marked as selected so the user can see what's
  /// already in that slot, and its non-null-ness is also what picks the
  /// picker's own title ("Edit Garment" swapping a card vs. "Add Garment"
  /// from the pinned add row, where [current] is always null).
  Future<void> _pickGarmentForOutfit({
    GarmentCategory? initial,
    _Slot? replaceSlot,
    int? replaceAccessoryIndex,
    Garment? current,
  }) async {
    final candidates = _addGarmentCandidates(
      keepCategory: replaceSlot != null ? _categoryForSlot(replaceSlot) : null,
      keepAccessoryIndex: replaceAccessoryIndex,
    );
    final tabs = _addGarmentTabs(candidates);
    final result = await Navigator.push<SelectGarmentResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectGarmentPage(
          title: current != null ? _l10n.editGarmentTitle : _l10n.addGarment,
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

  void _assignGarment(
    Garment g, {
    _Slot? replaceSlot,
    int? replaceAccessoryIndex,
  }) {
    setState(() {
      if (replaceSlot != null && g.category == _categoryForSlot(replaceSlot)) {
        _outfit = _applyToSlot(_outfit, replaceSlot, g);
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
        return;
      }
      _placeGarment(g);
    });
  }

  /// Auto-places [g] into whichever slot its category maps to — an empty
  /// top before middle, single-slot categories overwrite outright, and
  /// accessory categories append respecting `_maxAccessories` and
  /// no-duplicate-id. Call inside `setState`.
  void _placeGarment(Garment g) {
    switch (g.category) {
      case GarmentCategory.top:
        final slot = _outfit.top == null
            ? _Slot.top
            : (_outfit.middle == null ? _Slot.middle : _Slot.top);
        _outfit = _applyToSlot(_outfit, slot, g);
      case GarmentCategory.outer:
        _outfit = _applyToSlot(_outfit, _Slot.outer, g);
      case GarmentCategory.bottom:
        _outfit = _applyToSlot(_outfit, _Slot.bottom, g);
      case GarmentCategory.onePiece:
        _outfit = _applyToSlot(_outfit, _Slot.onePiece, g);
      case GarmentCategory.shoes:
        _outfit = _applyToSlot(_outfit, _Slot.shoes, g);
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
  }
}
