import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/garment_service.dart';
import '../../core/utils/signed_url.dart';
import '../../core/utils/try_on_mixin.dart';
import '../../data/garment.dart';
import '../../data/outfit.dart';
import '../../data/scene_option.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import 'outfit_details_page.dart';
import 'select_accessory_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/images/dashed_border_painter.dart';
import '../widgets/common/labeled_divider.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_image.dart';

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
  bool _isLoadingGarments = false;

  static const int _maxAccessories = 4;
  static const double _accessoryTileSize = 72;

  // Customization block state — held here until Create Outfit sends
  // everything to the backend together.
  bool _customizationExpanded = false;
  // Always exactly one trailing empty ("+") slot until the max is reached.
  final List<Garment?> _accessories = [null];
  SceneOption _scene = SceneOption.all.first;
  // Whether the user actually touched the scene picker — [_scene] always
  // has a concrete default, so this is the only way to tell "picked
  // Fitting Room on purpose" apart from "never opened the picker".
  bool _sceneCustomized = false;

  late final ScrollController _sceneScrollController = ScrollController()
    ..addListener(_updateSceneScrollArrows);
  bool _canScrollSceneLeft = false;
  // Optimistic default so the right-edge hint isn't briefly missing before
  // the first frame lets us measure whether the list actually overflows.
  bool _canScrollSceneRight = true;

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

  bool get _hasSelection =>
      _outfit.top != null ||
      _outfit.middle != null ||
      _outfit.outer != null ||
      _outfit.bottom != null ||
      _outfit.onePiece != null ||
      _outfit.shoes != null;

  bool get _isModified {
    bool sameSlot(Garment? a, Garment? b) => a?.id == b?.id;
    return !(sameSlot(_outfit.top, _initialOutfit.top) &&
        sameSlot(_outfit.middle, _initialOutfit.middle) &&
        sameSlot(_outfit.outer, _initialOutfit.outer) &&
        sameSlot(_outfit.bottom, _initialOutfit.bottom) &&
        sameSlot(_outfit.onePiece, _initialOutfit.onePiece) &&
        sameSlot(_outfit.shoes, _initialOutfit.shoes));
  }

  @override
  void initState() {
    super.initState();
    _outfit = widget.initialGarments.isNotEmpty
        ? _buildInitialOutfit(widget.initialGarments)
        : const _OutfitSelection();
    _initialOutfit = _outfit;
    if (widget.preloadedGarments != null) {
      _allGarments.addAll(widget.preloadedGarments!);
    } else {
      _loadGarments();
    }
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _updateSceneScrollArrows(),
    );
  }

  @override
  void dispose() {
    _sceneScrollController.dispose();
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

  List<int> _selectedGarmentIds() {
    return [
      _outfit.top,
      _outfit.middle,
      _outfit.outer,
      _outfit.bottom,
      _outfit.onePiece,
      _outfit.shoes,
    ].whereType<Garment>().map((g) => g.id).whereType<int>().toList();
  }

  Future<void> _startTryOn() async {
    final ids = _selectedGarmentIds();
    if (ids.isEmpty) return;
    if (tryOnOutfitId != 0) {
      await deleteOutfitJob(tryOnGroupId, tryOnOutfitId);
    }

    // The new API has no separate accessory concept — everything is one
    // flat garment_ids list.
    final accessoryIds = _accessoryGarmentIds();
    final allIds = {...ids, ...accessoryIds}.toList();

    await performTryOn(
      allIds,
      // existingOutfit mode: land the new outfit in that outfit's group
      // instead of starting a fresh one (Outfit Details' "Create Another
      // Version").
      groupId: widget.existingOutfit?.groupId,
      backgroundId: _sceneCustomized ? _scene.backgroundId : null,
    );
    if (!mounted) return;

    if (tryOnResultUrl != null) {
      if (widget.existingOutfit != null) {
        Navigator.pop(context, tryOnOutfit);
      } else {
        await _showTryOnResult(allIds);
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
        _scene = SceneOption.all.first;
        _sceneCustomized = false;
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
        _buildScaffold(),
        if (isOutfitLoading)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.creatingOutfitsEllipsis),
          ),
        if (_isLoadingGarments)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingClosetEllipsis),
          ),
      ],
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          24,
          20,
          AppDimens.bottomActionBtnClearance,
        ),
        children: [
          _buildInstructions(),
          const SizedBox(height: 24),
          if (!widget.selectOnly) ...[
            _buildMatchALookCard(),
            const SizedBox(height: 24),
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
    );
  }

  Widget _buildInstructions() {
    return Text(
      widget.selectOnly
          ? _l10n.editDayOutfitInstruction
          : _l10n.selectCombinationsInstruction,
      textAlign: TextAlign.center,
      style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
    );
  }

  /// Entry point for a not-yet-built "upload a photo, match it to closet
  /// items" flow — same AI call-out treatment as [LumiInsightCard]
  /// (gradient tint, sparkle badge, "AI" tag), but with the same trailing
  /// chevron the slot rows below use instead of an expand affordance.
  Widget _buildMatchALookCard() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.faceReferenceComingSoon)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.lumiCardTint],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.lumiCardTint,
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
                      Text(_l10n.matchALookTitle, style: AppTextStyle.bold16),
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
                          _l10n.aiTag,
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
                    _l10n.matchALookSubtitle,
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

  List<Widget> _buildTopSlots() {
    if (!_hasCategory(GarmentCategory.top)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.top.localizedLabel(context),
        iconAsset: 'assets/images/top.png',
        value: _outfit.top,
        category: GarmentCategory.top,
        onPicked: (g) => setState(() => _outfit = _outfit.copyWith(top: g)),
        onClear: _outfit.top == null
            ? null
            : () => setState(() => _outfit = _outfit.copyWith(clearTop: true)),
      ),
      const SizedBox(height: 24),
      _slotRow(
        title: _l10n.midLayer,
        iconAsset: 'assets/images/outer.png',
        value: _outfit.middle,
        category: GarmentCategory.top,
        onPicked: (g) => setState(() => _outfit = _outfit.copyWith(middle: g)),
        onClear: _outfit.middle == null
            ? null
            : () =>
                  setState(() => _outfit = _outfit.copyWith(clearMiddle: true)),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildOuterSlot() {
    if (!_hasCategory(GarmentCategory.outer)) return const [];
    return [
      _slotRow(
        title: _l10n.outerwear,
        iconAsset: 'assets/images/outer.png',
        value: _outfit.outer,
        category: GarmentCategory.outer,
        onPicked: (g) => setState(() => _outfit = _outfit.copyWith(outer: g)),
        onClear: _outfit.outer == null
            ? null
            : () =>
                  setState(() => _outfit = _outfit.copyWith(clearOuter: true)),
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
        onPicked: (g) => setState(() => _outfit = _outfit.copyWith(bottom: g)),
        onClear: _outfit.bottom == null
            ? null
            : () =>
                  setState(() => _outfit = _outfit.copyWith(clearBottom: true)),
      ),
      const SizedBox(height: 24),
    ];
  }

  List<Widget> _buildOnePieceSlot() {
    if (!_hasCategory(GarmentCategory.onePiece)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.onePiece.localizedLabel(context),
        iconData: Icons.checkroom,
        value: _outfit.onePiece,
        category: GarmentCategory.onePiece,
        onPicked: (g) =>
            setState(() => _outfit = _outfit.copyWith(onePiece: g)),
        onClear: _outfit.onePiece == null
            ? null
            : () => setState(
                () => _outfit = _outfit.copyWith(clearOnePiece: true),
              ),
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
        onPicked: (g) => setState(() => _outfit = _outfit.copyWith(shoes: g)),
        onClear: _outfit.shoes == null
            ? null
            : () =>
                  setState(() => _outfit = _outfit.copyWith(clearShoes: true)),
      ),
      const SizedBox(height: 24),
    ];
  }

  /// Collapsible panel (collapsed by default) holding the Accessories and
  /// Scene pickers — not shown in [selectOnly] mode, which just picks
  /// garment ids for a caller and has no concept of generating an outfit.
  Widget _buildCustomizationBlock() {
    if (widget.selectOnly) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
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
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 24,
                    color: AppColors.icon,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _l10n.customizationOptional,
                      style: AppTextStyle.bold16,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _customizationExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 20,
                      color: AppColors.icon,
                    ),
                  ),
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
                  Text(_l10n.accessoriesLabel, style: AppTextStyle.bold14),
                  const SizedBox(height: 8),
                  _buildAccessoriesRow(),
                  const SizedBox(height: 20),
                  LabeledDivider(label: _l10n.sceneLabel),
                  const SizedBox(height: 4),
                  Text(
                    _l10n.sceneSubtitle,
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSceneSelector(),
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

  /// Candidates for [index]'s slot, minus whatever *type* of accessory is
  /// already picked in the *other* slots (grouped by `subCategory`).
  List<Garment> _accessoryCandidatesFor(int index) {
    final pickedTypesElsewhere = <String>{};
    final pickedIdsElsewhere = <int>{};
    for (var i = 0; i < _accessories.length; i++) {
      if (i == index) continue;
      final picked = _accessories[i];
      if (picked == null) continue;
      if (picked.subCategory.isNotEmpty) {
        pickedTypesElsewhere.add(picked.subCategory.toLowerCase());
      } else if (picked.id != null) {
        pickedIdsElsewhere.add(picked.id!);
      }
    }
    return _accessoryCandidates.where((g) {
      if (g.subCategory.isNotEmpty &&
          pickedTypesElsewhere.contains(g.subCategory.toLowerCase())) {
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

  List<int> _accessoryGarmentIds() => _accessories
      .whereType<Garment>()
      .map((g) => g.id)
      .whereType<int>()
      .toList();

  Widget _buildAccessoriesRow() {
    return SizedBox(
      height: _accessoryTileSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _accessories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
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
  void _updateSceneScrollArrows() {
    if (!_sceneScrollController.hasClients) return;
    final position = _sceneScrollController.position;
    final canLeft = position.pixels > 4;
    final canRight = position.pixels < position.maxScrollExtent - 4;
    if (canLeft == _canScrollSceneLeft && canRight == _canScrollSceneRight) {
      return;
    }
    setState(() {
      _canScrollSceneLeft = canLeft;
      _canScrollSceneRight = canRight;
    });
  }

  /// Horizontally swipeable row of bundled scene photos — tapping one
  /// selects it immediately, no separate picker page needed since there
  /// are only a handful of scenes.
  Widget _buildSceneSelector() {
    return _fadeHorizontalEdges(
      SizedBox(
        height: 170,
        child: ListView.separated(
          controller: _sceneScrollController,
          scrollDirection: Axis.horizontal,
          itemCount: SceneOption.all.length,
          separatorBuilder: (_, __) => const SizedBox(width: _sceneCardSpacing),
          itemBuilder: (context, i) => _buildSceneCard(SceneOption.all[i], i),
        ),
      ),
    );
  }

  static const _sceneCardWidth = 120.0;
  static const _sceneCardSpacing = AppDimens.cardSpacing;

  /// Scrolls so the just-selected scene at [index] is fully in view,
  /// centered in the row — tapping a card near either edge would otherwise
  /// leave it half cut off under the fade scrim.
  void _centerSceneCard(int index) {
    if (!_sceneScrollController.hasClients) return;
    final position = _sceneScrollController.position;
    final itemStart = index * (_sceneCardWidth + _sceneCardSpacing);
    final target =
        itemStart - (position.viewportDimension - _sceneCardWidth) / 2;
    _sceneScrollController.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Overlays a short same-color scrim on each edge of [child] so content
  /// sliding past doesn't end abruptly.
  Widget _fadeHorizontalEdges(Widget child) {
    Widget scrim(Alignment begin, Alignment end, IconData icon, bool visible) {
      return IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: visible ? 1 : 0,
          child: Container(
            width: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: begin,
                end: end,
                colors: [
                  AppColors.surface,
                  AppColors.surface.withValues(alpha: 0),
                ],
              ),
            ),
            child: Icon(
              icon,
              size: 28,
              color: AppColors.icon.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: scrim(
            Alignment.centerLeft,
            Alignment.centerRight,
            Icons.chevron_left,
            _canScrollSceneLeft,
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: scrim(
            Alignment.centerRight,
            Alignment.centerLeft,
            Icons.chevron_right,
            _canScrollSceneRight,
          ),
        ),
      ],
    );
  }

  /// Selected-state treatment (foreground border + checkmark badge) mirrors
  /// `GarmentCard`'s selected styling, so the same "picked" affordance reads
  /// consistently across the app.
  Widget _buildSceneCard(SceneOption scene, int index) {
    final isSelected = scene.id == _scene.id;
    return GestureDetector(
      onTap: isOutfitLoading
          ? null
          : () {
              setState(() {
                _scene = scene;
                _sceneCustomized = true;
              });
              _centerSceneCard(index);
            },
      child: SizedBox(
        width: _sceneCardWidth,
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
                Image.asset(scene.assetPath, fit: BoxFit.cover),
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
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                    child: Text(
                      scene.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.bold12.copyWith(color: Colors.white),
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
          _hasSelection &&
          (widget.existingOutfit != null || _isModified),
    );
  }

  Widget _slotRow({
    required String title,
    String? iconAsset,
    IconData? iconData,
    required Garment? value,
    required GarmentCategory category,
    required void Function(Garment g) onPicked,
    VoidCallback? onClear,
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
          child: SectionTitle(title.toUpperCase()),
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
          minHeight: value == null ? 56 : 70,
          leadingSize: value == null ? 32 : 40,
          leadingAsset: (value == null && iconData == null) ? iconAsset : null,
          leading: value != null
              ? Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GarmentImage(
                      url: value.imageUrl,
                      garmentId: value.id,
                      width: 40,
                      height: 40,
                      memCacheWidth: 80,
                      memCacheHeight: 80,
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
            value == null ? _l10n.addItemLabel(title) : value.name,
            style: AppTextStyle.bold16,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
