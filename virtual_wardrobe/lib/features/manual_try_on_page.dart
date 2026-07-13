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
import 'looks_details_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;
import 'widgets/common/app_list_card.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/garment/garment_image.dart';

class ManualTryOnPage extends StatefulWidget {
  final List<Garment> initialGarments;
  final List<Garment>? preloadedGarments;
  final VoidCallback? onBack;

  const ManualTryOnPage({
    super.key,
    this.initialGarments = const [],
    this.preloadedGarments,
    this.onBack,
  });

  /// Fetches the closet garments up front, so the page can be pushed only
  /// once loading is complete (no in-page spinner on open).
  static Future<List<Garment>> preload() => GarmentService().getGarments();

  @override
  State<ManualTryOnPage> createState() => _ManualTryOnPageState();
}

class _ManualTryOnPageState extends State<ManualTryOnPage> with TryOnMixin {
  final List<Garment> _allGarments = [];
  late OutfitSelection _outfit;
  bool _isLoadingGarments = false;

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

  @override
  void initState() {
    super.initState();
    _outfit = widget.initialGarments.isNotEmpty
        ? _buildInitialOutfit(widget.initialGarments)
        : const OutfitSelection();
    if (widget.preloadedGarments != null) {
      _allGarments.addAll(widget.preloadedGarments!);
    } else {
      _loadGarments();
    }
  }

  OutfitSelection _buildInitialOutfit(List<Garment> garments) {
    final tops = garments
        .where((g) => g.category == GarmentCategory.top)
        .toList();
    return OutfitSelection(
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

  Future<void> _startTryOn() async {
    final ids = <int>[];
    if (_outfit.top?.id != null) ids.add(_outfit.top!.id!);
    if (_outfit.middle?.id != null) ids.add(_outfit.middle!.id!);
    if (_outfit.outer?.id != null) ids.add(_outfit.outer!.id!);
    if (_outfit.bottom?.id != null) ids.add(_outfit.bottom!.id!);
    if (_outfit.onePiece?.id != null) ids.add(_outfit.onePiece!.id!);
    if (_outfit.shoes?.id != null) ids.add(_outfit.shoes!.id!);
    if (_outfit.socks?.id != null) ids.add(_outfit.socks!.id!);
    if (_outfit.accessory?.id != null) ids.add(_outfit.accessory!.id!);

    if (ids.isEmpty) return;
    if (tryOnJobId != 0) await deleteOutfitJob(tryOnJobId);

    await performTryOn(ids, 'outfit');
    if (!mounted) return;

    if (tryOnResultUrl != null) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => LooksDetailsPage(
            look: Look(
              id: tryOnJobId,
              imageUrl: tryOnResultUrl!,
              advice: tryOnAiAdvice,
              garmentIds: ids,
            ),
            isNew: true,
          ),
        ),
      );
      if (mounted) resetTryOnState();
    } else if (tryOnErrorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tryOnErrorMessage!)));
      resetTryOnState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.defaultBackground,
          appBar: AppToolBar(title: 'Manual Try-on', onBack: widget.onBack),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                Text(
                  'Select the clothing combinations you\'d like to try, then click "Create Look" to see your try-on results!',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                if (_hasCategory(GarmentCategory.top)) ...[
                  _slotRow(
                    title: 'Top',
                    iconAsset: 'assets/images/top.png',
                    value: _outfit.top,
                    category: GarmentCategory.top,
                    onPicked: (g) =>
                        setState(() => _outfit = _outfit.copyWith(top: g)),
                    onClear: _outfit.top == null
                        ? null
                        : () => setState(
                            () => _outfit = _outfit.copyWith(clearTop: true),
                          ),
                  ),
                  const SizedBox(height: 12),
                  _slotRow(
                    title: 'Mid Layer',
                    iconAsset: 'assets/images/outer.png',
                    value: _outfit.middle,
                    category: GarmentCategory.top,
                    onPicked: (g) =>
                        setState(() => _outfit = _outfit.copyWith(middle: g)),
                    onClear: _outfit.middle == null
                        ? null
                        : () => setState(
                            () => _outfit = _outfit.copyWith(clearMiddle: true),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_hasCategory(GarmentCategory.outer)) ...[
                  _slotRow(
                    title: 'Outerwear',
                    iconAsset: 'assets/images/outer.png',
                    value: _outfit.outer,
                    category: GarmentCategory.outer,
                    onPicked: (g) =>
                        setState(() => _outfit = _outfit.copyWith(outer: g)),
                    onClear: _outfit.outer == null
                        ? null
                        : () => setState(
                            () => _outfit = _outfit.copyWith(clearOuter: true),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_hasCategory(GarmentCategory.bottom)) ...[
                  _slotRow(
                    title: 'Bottom',
                    iconAsset: 'assets/images/buttom.png',
                    value: _outfit.bottom,
                    category: GarmentCategory.bottom,
                    onPicked: (g) =>
                        setState(() => _outfit = _outfit.copyWith(bottom: g)),
                    onClear: _outfit.bottom == null
                        ? null
                        : () => setState(
                            () => _outfit = _outfit.copyWith(clearBottom: true),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_hasCategory(GarmentCategory.onePiece)) ...[
                  _slotRow(
                    title: 'One-piece',
                    iconData: Icons.checkroom,
                    value: _outfit.onePiece,
                    category: GarmentCategory.onePiece,
                    onPicked: (g) =>
                        setState(() => _outfit = _outfit.copyWith(onePiece: g)),
                    onClear: _outfit.onePiece == null
                        ? null
                        : () => setState(
                            () =>
                                _outfit = _outfit.copyWith(clearOnePiece: true),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_hasCategory(GarmentCategory.shoes)) ...[
                  _slotRow(
                    title: 'Shoes',
                    iconAsset: 'assets/images/shoes.png',
                    value: _outfit.shoes,
                    category: GarmentCategory.shoes,
                    onPicked: (g) =>
                        setState(() => _outfit = _outfit.copyWith(shoes: g)),
                    onClear: _outfit.shoes == null
                        ? null
                        : () => setState(
                            () => _outfit = _outfit.copyWith(clearShoes: true),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_hasCategory(GarmentCategory.socks)) ...[
                  _slotRow(
                    title: 'Socks',
                    iconData: Icons.dry_cleaning,
                    value: _outfit.socks,
                    category: GarmentCategory.socks,
                    onPicked: (g) =>
                        setState(() => _outfit = _outfit.copyWith(socks: g)),
                    onClear: _outfit.socks == null
                        ? null
                        : () => setState(
                            () => _outfit = _outfit.copyWith(clearSocks: true),
                          ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_hasCategory(GarmentCategory.accessory))
                  _slotRow(
                    title: 'Accessory',
                    iconAsset: 'assets/images/accessory.png',
                    value: _outfit.accessory,
                    category: GarmentCategory.accessory,
                    onPicked: (g) => setState(
                      () => _outfit = _outfit.copyWith(accessory: g),
                    ),
                    onClear: _outfit.accessory == null
                        ? null
                        : () => setState(
                            () => _outfit = _outfit.copyWith(
                              clearAccessory: true,
                            ),
                          ),
                  ),
              ],
            ),
          ),
          bottomNavigationBar: BottomActionButton(
            label: 'Create Look',
            trailing: const Icon(Icons.crop_free, size: 18),
            onPressed: _startTryOn,
            enabled: !isOutfitLoading && _hasSelection,
          ),
        ),
        if (isOutfitLoading)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Creating Looks...'),
          ),
        if (_isLoadingGarments)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Closet...'),
          ),
      ],
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
      status: value == null ? 'select' : 'edit',
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
                ? Icon(iconData, size: 28, color: AppColors.textSecondary)
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
