import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/garment.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/bottom_action_button.dart';
import '../../widgets/common/cards/app_list_card.dart';
import '../../widgets/common/cards/card_corner_badge.dart';
import '../../widgets/common/field_label.dart';
import '../../widgets/common/images/dashed_border_painter.dart';
import '../../widgets/garment/outfit_garment_row.dart';
import 'create_outfit_selection.dart';
import 'select_garment_page.dart' show SelectGarmentPage;

/// One garment row: a core slot pick ([slot] set; [topIndex] too for a top)
/// or an accessory ([accessoryIndex] set).
typedef _OutfitEntry = ({
  Garment garment,
  GarmentCategory category,
  OutfitSlot? slot,
  int? topIndex,
  int? accessoryIndex,
});

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
  late OutfitSelection _outfit;
  late Set<int> _initialGarmentIds;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  List<Garment> get _garmentPool => widget.preloadedGarments;

  bool get _hasSelection =>
      _outfit.garments.isNotEmpty || _outfit.accessoryIds.isNotEmpty;

  bool get _isModified =>
      !setEquals(_selectedGarmentIds().toSet(), _initialGarmentIds);

  bool get _showsBottomActionButton => _hasSelection && _isModified;

  @override
  void initState() {
    super.initState();
    _outfit = OutfitSelection.fromGarments(widget.initialGarments);
    _initialGarmentIds = _selectedGarmentIds().toSet();
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
      if (OutfitSelection.isAccessoryGarment(g)) {
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

  List<int> _selectedGarmentIds() {
    final coreIds = _outfit.garments.map((g) => g.id).whereType<int>();
    final accessoryIds = _outfit.accessoryGarments
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

  static const double _addGarmentIconSize = 56;

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
        minHeight: OutfitGarmentRow.minHeight,
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
          style: AppTextStyle.regular14.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildOutfitGarmentRow(_OutfitEntry entry) {
    final g = entry.garment;
    final isInvalid =
        widget.validGarmentIds != null &&
        g.id != null &&
        !widget.validGarmentIds!.contains(g.id);

    return OutfitGarmentRow(
      garment: g,
      category: entry.category,
      isInvalid: isInvalid,
      onTap: () => _pickGarmentForOutfit(
        initial: entry.category,
        replaceSlot: entry.slot,
        replaceTopIndex: entry.topIndex,
        replaceAccessoryIndex: entry.accessoryIndex,
        current: g,
      ),
      trailing: CardCornerBadge(
        icon: Icons.close,
        backgroundColor: AppColors.placeholderSurface,
        iconColor: AppColors.icon,
        hitTargetSize: const Size(24, AppDimens.minTouchTarget),
        onTap: () => _removeOutfitEntry(entry),
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
        return;
      }
      if (replaceAccessoryIndex != null &&
          OutfitSelection.isAccessoryGarment(g) &&
          replaceAccessoryIndex < _outfit.accessories.length) {
        _outfit = _outfit.withAccessoryAt(replaceAccessoryIndex, g);
        return;
      }
      _outfit = _outfit.withGarment(g) ?? _outfit;
    });
  }
}
