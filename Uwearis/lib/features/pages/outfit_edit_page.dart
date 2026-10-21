import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/garment.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/adaptive_side_layout.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/card_corner_badge.dart';
import '../widgets/common/field_label.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/garment/garment_image.dart';
import 'select_garment_page.dart' show SelectGarmentPage;

/// Garment slots. [top] holds up to [_maxTops] garments
/// ([_OutfitSelection.tops]); the rest hold one each.
enum _Slot { top, outer, bottom, onePiece, shoes }

const int _maxTops = 2;

/// One garment row: a core slot pick ([slot] set; [topIndex] too for a top)
/// or an accessory ([accessoryIndex] set).
typedef _OutfitEntry = ({
  Garment garment,
  GarmentCategory category,
  _Slot? slot,
  int? topIndex,
  int? accessoryIndex,
});

/// In-progress slot picks — local UI state, not a domain model.
class _OutfitSelection {
  final List<Garment> tops;
  final Garment? outer;
  final Garment? bottom;
  final Garment? onePiece;
  final Garment? shoes;

  const _OutfitSelection({
    this.tops = const [],
    this.outer,
    this.bottom,
    this.onePiece,
    this.shoes,
  });

  _OutfitSelection copyWith({
    List<Garment>? tops,
    Garment? outer,
    Garment? bottom,
    Garment? onePiece,
    Garment? shoes,
    bool clearOuter = false,
    bool clearBottom = false,
    bool clearOnePiece = false,
    bool clearShoes = false,
  }) {
    return _OutfitSelection(
      tops: List.unmodifiable(tops ?? this.tops),
      outer: clearOuter ? null : (outer ?? this.outer),
      bottom: clearBottom ? null : (bottom ?? this.bottom),
      onePiece: clearOnePiece ? null : (onePiece ?? this.onePiece),
      shoes: clearShoes ? null : (shoes ?? this.shoes),
    );
  }

  /// Tops first, then the single slots — the row order.
  List<Garment> get garments => [
    ...tops,
    ...[outer, bottom, onePiece, shoes].whereType<Garment>(),
  ];
}

/// Picks an outfit's garments from a fixed pool (a trip's suitcase) for
/// Trip Details' outfit edit. Pops the picked garment ids on Confirm, or
/// null if the user backs out. (Outfit Details' Add Version uses
/// CreateOutfitPage's version mode instead.)
class OutfitEditPage extends StatefulWidget {
  final List<Garment> initialGarments;

  final List<Garment> preloadedGarments;
  final VoidCallback? onBack;

  /// Ids not in this set get a warning badge (e.g. removed from the
  /// suitcase).
  final Set<int>? validGarmentIds;

  /// Defaults to [AppLocalizations.selectGarmentsTitle].
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
  late Set<int> _initialGarmentIds;

  static const int _maxAccessories = 4;

  // Always exactly one trailing empty ("+") slot until the max is reached.
  final List<Garment?> _accessories = [null];

  AppLocalizations get _l10n => AppLocalizations.of(context);

  List<Garment> get _garmentPool => widget.preloadedGarments;

  Set<int> get _accessoryIds => _accessories
      .whereType<Garment>()
      .map((g) => g.id)
      .whereType<int>()
      .toSet();

  bool get _hasSelection =>
      _outfit.garments.isNotEmpty || _accessoryIds.isNotEmpty;

  bool get _isModified =>
      !setEquals(_selectedGarmentIds().toSet(), _initialGarmentIds);

  bool get _showsBottomActionButton => _hasSelection && _isModified;

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
  }

  _OutfitSelection _buildInitialOutfit(List<Garment> garments) {
    final tops = garments
        .where((g) => g.category == GarmentCategory.top)
        .toList();
    return _OutfitSelection(
      tops: tops.take(_maxTops).toList(),
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

  /// Single slots only; tops go through [_placeTop] or their index.
  _OutfitSelection _applyToSlot(_OutfitSelection sel, _Slot slot, Garment g) {
    switch (slot) {
      case _Slot.top:
        throw ArgumentError.value(slot, 'slot', 'tops are indexed');
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
          return _outfit.tops.length >= _maxTops;
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

  List<int> _selectedGarmentIds() {
    final coreIds = _outfit.garments.map((g) => g.id).whereType<int>();
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
          children: [
            _hInset(FieldLabel(_l10n.outfitItemsLabel.toUpperCase())),
            const SizedBox(height: AppDimens.cardHeaderGap),
            _hInset(_buildYourOutfitRow()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  static const double _pageInset = 20;

  Widget _hInset(Widget child) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: _pageInset),
    child: child,
  );

  Widget _buildBottomBar() {
    return BottomActionButton(
      label: _l10n.confirm,
      onPressed: () =>
          Navigator.pop<Set<int>>(context, _selectedGarmentIds().toSet()),
      enabled: _showsBottomActionButton,
    );
  }

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
    final iconColor = exhausted ? AppColors.hintText : AppColors.icon;
    return Opacity(
      opacity: exhausted ? 0.5 : 1,
      child: AppListCard(
        onTap: exhausted ? null : () => _pickGarmentForOutfit(),
        showArrow: true,
        minHeight: _outfitRowHeight,
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
      behavior: HitTestBehavior.opaque,
      onTap: () => _pickGarmentForOutfit(
        initial: entry.category,
        replaceSlot: entry.slot,
        replaceTopIndex: entry.topIndex,
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
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: GarmentImage(
                            url: g.imageUrl,
                            garmentId: g.id,
                            fit: BoxFit.contain,
                          ),
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

  /// Tops, then the other core slots, then accessories.
  List<_OutfitEntry> _outfitEntries() {
    final list = <_OutfitEntry>[
      for (var i = 0; i < _outfit.tops.length; i++)
        (
          garment: _outfit.tops[i],
          category: GarmentCategory.top,
          slot: _Slot.top,
          topIndex: i,
          accessoryIndex: null,
        ),
    ];
    void addSlot(Garment? g, _Slot slot) {
      if (g != null) {
        list.add((
          garment: g,
          category: _categoryForSlot(slot),
          slot: slot,
          topIndex: null,
          accessoryIndex: null,
        ));
      }
    }

    addSlot(_outfit.outer, _Slot.outer);
    addSlot(_outfit.bottom, _Slot.bottom);
    addSlot(_outfit.onePiece, _Slot.onePiece);
    addSlot(_outfit.shoes, _Slot.shoes);
    for (var i = 0; i < _accessories.length; i++) {
      final g = _accessories[i];
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
        _outfit = _outfit.copyWith(tops: [..._outfit.tops]..removeAt(topIndex));
      } else if (slot != null) {
        _outfit = _outfit.copyWith(
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

  /// [replaceSlot] (+ [replaceTopIndex] for a top) / [replaceAccessoryIndex]
  /// pin the pick to the row being swapped; [current] shows as selected in
  /// the picker.
  Future<void> _pickGarmentForOutfit({
    GarmentCategory? initial,
    _Slot? replaceSlot,
    int? replaceTopIndex,
    int? replaceAccessoryIndex,
    Garment? current,
  }) async {
    final candidates = _addGarmentCandidates(
      keepCategory: replaceSlot != null ? _categoryForSlot(replaceSlot) : null,
      keepTopIndex: replaceTopIndex,
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
      replaceTopIndex: replaceTopIndex,
      replaceAccessoryIndex: replaceAccessoryIndex,
    );
  }

  void _assignGarment(
    Garment g, {
    _Slot? replaceSlot,
    int? replaceTopIndex,
    int? replaceAccessoryIndex,
  }) {
    setState(() {
      if (replaceSlot != null && g.category == _categoryForSlot(replaceSlot)) {
        if (replaceTopIndex != null && replaceTopIndex < _outfit.tops.length) {
          _outfit = _outfit.copyWith(
            tops: [..._outfit.tops]..[replaceTopIndex] = g,
          );
        } else if (replaceSlot != _Slot.top) {
          _outfit = _applyToSlot(_outfit, replaceSlot, g);
        } else {
          _outfit = _outfit.copyWith(tops: _placeTop(_outfit.tops, g));
        }
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

  /// A top interchangeable with a worn one ([baseTopSlotKey], e.g. Polo
  /// over T-shirt) replaces it; otherwise it's added, or replaces the last
  /// top once [_maxTops] are worn.
  List<Garment> _placeTop(List<Garment> tops, Garment g) {
    final next = [...tops];
    final same = next.indexWhere(
      (t) => baseTopSlotKey(t.subCategory) == baseTopSlotKey(g.subCategory),
    );
    if (same >= 0) {
      next[same] = g;
    } else if (next.length < _maxTops) {
      next.add(g);
    } else {
      next[next.length - 1] = g;
    }
    return next;
  }

  /// Call inside `setState`.
  void _placeGarment(Garment g) {
    switch (g.category) {
      case GarmentCategory.top:
        _outfit = _outfit.copyWith(tops: _placeTop(_outfit.tops, g));
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
