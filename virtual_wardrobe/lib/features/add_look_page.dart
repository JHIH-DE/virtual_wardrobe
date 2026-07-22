import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../core/utils/signed_url.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/garment.dart';
import '../data/look.dart';
import '../data/select_garment_result.dart';
import '../l10n/garment_localization.dart';
import '../l10n/generated/app_localizations.dart';
import 'looks_details_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;
import 'widgets/common/app_list_card.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/garment/garment_image.dart';

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
  final Garment? socks;
  final Garment? accessory;

  const _OutfitSelection({
    this.top,
    this.middle,
    this.outer,
    this.bottom,
    this.onePiece,
    this.shoes,
    this.socks,
    this.accessory,
  });

  _OutfitSelection copyWith({
    Garment? top,
    Garment? middle,
    Garment? outer,
    Garment? bottom,
    Garment? onePiece,
    Garment? shoes,
    Garment? socks,
    Garment? accessory,
    bool clearTop = false,
    bool clearMiddle = false,
    bool clearOuter = false,
    bool clearBottom = false,
    bool clearOnePiece = false,
    bool clearShoes = false,
    bool clearSocks = false,
    bool clearAccessory = false,
  }) {
    return _OutfitSelection(
      top: clearTop ? null : (top ?? this.top),
      middle: clearMiddle ? null : (middle ?? this.middle),
      outer: clearOuter ? null : (outer ?? this.outer),
      bottom: clearBottom ? null : (bottom ?? this.bottom),
      onePiece: clearOnePiece ? null : (onePiece ?? this.onePiece),
      shoes: clearShoes ? null : (shoes ?? this.shoes),
      socks: clearSocks ? null : (socks ?? this.socks),
      accessory: clearAccessory ? null : (accessory ?? this.accessory),
    );
  }
}

class AddLookPage extends StatefulWidget {
  final List<Garment> initialGarments;
  final List<Garment>? preloadedGarments;
  final VoidCallback? onBack;

  const AddLookPage({
    super.key,
    this.initialGarments = const [],
    this.preloadedGarments,
    this.onBack,
  });

  @override
  State<AddLookPage> createState() => _AddLookPageState();
}

class _AddLookPageState extends State<AddLookPage> with TryOnMixin {
  final List<Garment> _allGarments = [];
  late _OutfitSelection _outfit;
  late _OutfitSelection _initialOutfit;
  bool _isLoadingGarments = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool _hasCategory(GarmentCategory category) =>
      _allGarments.any((g) => g.category == category);

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
      _outfit.shoes != null ||
      _outfit.socks != null ||
      _outfit.accessory != null;

  bool get _isModified {
    bool sameSlot(Garment? a, Garment? b) => a?.id == b?.id;
    return !(sameSlot(_outfit.top, _initialOutfit.top) &&
        sameSlot(_outfit.middle, _initialOutfit.middle) &&
        sameSlot(_outfit.outer, _initialOutfit.outer) &&
        sameSlot(_outfit.bottom, _initialOutfit.bottom) &&
        sameSlot(_outfit.onePiece, _initialOutfit.onePiece) &&
        sameSlot(_outfit.shoes, _initialOutfit.shoes) &&
        sameSlot(_outfit.socks, _initialOutfit.socks) &&
        sameSlot(_outfit.accessory, _initialOutfit.accessory));
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
      socks: garments
          .where((g) => g.category == GarmentCategory.socks)
          .firstOrNull,
      accessory: garments
          .where((g) => g.category == GarmentCategory.accessory)
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
      _outfit.socks,
      _outfit.accessory,
    ].whereType<Garment>().map((g) => g.id).whereType<int>().toList();
  }

  Future<void> _startTryOn() async {
    final ids = _selectedGarmentIds();
    if (ids.isEmpty) return;
    if (tryOnJobId != 0) await deleteOutfitJob(tryOnJobId);

    await performTryOn(ids, 'outfit');
    if (!mounted) return;

    if (tryOnResultUrl != null) {
      await _showTryOnResult(ids);
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
        builder: (_) => LooksDetailsPage(
          look: Look(
            id: tryOnJobId,
            imageUrl: tryOnResultUrl!,
            advice: tryOnAiAdvice,
            garmentIds: garmentIds,
          ),
          isNew: true,
        ),
      ),
    );
    if (mounted) resetTryOnState();
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.quickActionAddLook, onBack: widget.onBack);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(),
        if (isLookLoading)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.creatingLooksEllipsis),
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
        children: [
          _buildInstructions(),
          const SizedBox(height: 24),
          ..._buildTopSlots(),
          ..._buildOuterSlot(),
          ..._buildBottomSlot(),
          ..._buildOnePieceSlot(),
          ..._buildShoesSlot(),
          ..._buildSocksSlot(),
          ..._buildAccessorySlot(),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildInstructions() {
    return Text(
      _l10n.selectCombinationsInstruction,
      textAlign: TextAlign.center,
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
        onPicked: (g) => setState(() => _outfit = _outfit.copyWith(top: g)),
        onClear: _outfit.top == null
            ? null
            : () => setState(() => _outfit = _outfit.copyWith(clearTop: true)),
      ),
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildSocksSlot() {
    if (!_hasCategory(GarmentCategory.socks)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.socks.localizedLabel(context),
        iconData: Icons.dry_cleaning,
        value: _outfit.socks,
        category: GarmentCategory.socks,
        onPicked: (g) => setState(() => _outfit = _outfit.copyWith(socks: g)),
        onClear: _outfit.socks == null
            ? null
            : () =>
                  setState(() => _outfit = _outfit.copyWith(clearSocks: true)),
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _buildAccessorySlot() {
    if (!_hasCategory(GarmentCategory.accessory)) return const [];
    return [
      _slotRow(
        title: GarmentCategory.accessory.localizedLabel(context),
        iconAsset: 'assets/images/accessory.png',
        value: _outfit.accessory,
        category: GarmentCategory.accessory,
        onPicked: (g) =>
            setState(() => _outfit = _outfit.copyWith(accessory: g)),
        onClear: _outfit.accessory == null
            ? null
            : () => setState(
                () => _outfit = _outfit.copyWith(clearAccessory: true),
              ),
      ),
    ];
  }

  Widget _buildBottomBar() {
    return BottomActionButton(
      label: _l10n.createLook,
      leading: Image.asset(
        'assets/images/ai_process_inv.png',
        width: 18,
        height: 18,
      ),
      onPressed: _startTryOn,
      enabled: !isLookLoading && _hasSelection && _isModified,
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

    return AppListCard(
      onTap: (isLookLoading || _isLoadingGarments)
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
      leadingAsset: (value == null && iconData == null) ? iconAsset : null,
      leading: value != null
          ? GarmentImage(
              url: value.imageUrl,
              width: 40,
              height: 40,
              borderRadius: 8,
              fit: BoxFit.cover,
            )
          : (iconData != null
                ? Icon(iconData, size: 28, color: AppColors.icon)
                : null),
      summary: detail?.isNotEmpty == true ? detail : null,
      child: Text(
        value == null ? title : value.name,
        style: AppTextStyle.bold16,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
