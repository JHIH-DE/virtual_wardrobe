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

/// Garment slots — not [GarmentCategory], since Top and Mid Layer are two
/// slots sharing [GarmentCategory.top].
enum _Slot { top, middle, outer, bottom, onePiece, shoes }

/// One garment row: a core slot pick ([slot] set) or an accessory
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

/// Picks an outfit's garments from a fixed pool (a trip's suitcase) for
/// Trip Details' outfit edit. Pops the picked garment ids on Confirm, or
/// null if the user backs out. (Outfit Details' Add Version uses
/// AddOutfitPage's version mode instead.)
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
  late _OutfitSelection _initialOutfit;
  late Set<int> _initialAccessoryIds;

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
          0,
          24,
          0,
          _showsBottomActionButton ? AppDimens.bottomActionBtnClearance : 24,
        ),
        children: [
          _hInset(FieldLabel(_l10n.outfitItemsLabel.toUpperCase())),
          const SizedBox(height: AppDimens.cardHeaderGap),
          _hInset(_buildYourOutfitRow()),
        ],
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
      child: SizedBox(
        height: _outfitRowHeight,
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
                    child: Stack(
                      fit: StackFit.expand,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(width: 1, color: AppColors.borderSubtle),
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

  /// [replaceSlot] / [replaceAccessoryIndex] pin the pick to the row being
  /// swapped; [current] shows as selected in the picker.
  Future<void> _pickGarmentForOutfit({
    GarmentCategory? initial,
    _Slot? replaceSlot,
    int? replaceAccessoryIndex,
    Garment? current,
  }) async {
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

  /// Call inside `setState`. A top interchangeable with the current one
  /// ([baseTopSlotKey], e.g. Polo over T-shirt) replaces it instead of
  /// becoming the mid layer.
  void _placeGarment(Garment g) {
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
