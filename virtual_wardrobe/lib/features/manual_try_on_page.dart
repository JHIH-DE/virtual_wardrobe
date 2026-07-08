import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/garment.dart';
import '../data/look.dart';
import '../data/select_garment_result.dart';
import 'looks_details_page.dart';
import 'select_garment_page.dart' show SelectGarmentPage;
import 'widgets/app_list_card.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/garment_image.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/page_app_bar.dart';

class ManualTryOnPage extends StatefulWidget {
  final List<Garment> initialGarments;
  final VoidCallback? onBack;

  const ManualTryOnPage({
    super.key,
    this.initialGarments = const [],
    this.onBack,
  });

  @override
  State<ManualTryOnPage> createState() => _ManualTryOnPageState();
}

class _ManualTryOnPageState extends State<ManualTryOnPage> with TryOnMixin {
  final List<Garment> _allGarments = [];
  late OutfitSelection _outfit;
  bool _isLoadingGarments = false;

  bool get _hasSelection =>
      _outfit.top != null ||
      _outfit.middle != null ||
      _outfit.outer != null ||
      _outfit.bottom != null ||
      _outfit.shoes != null ||
      _outfit.accessory != null;

  @override
  void initState() {
    super.initState();
    _outfit = widget.initialGarments.isNotEmpty
        ? _buildInitialOutfit(widget.initialGarments)
        : const OutfitSelection();
    _loadGarments();
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
      shoes: garments
          .where((g) => g.category == GarmentCategory.shoes)
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
    if (_outfit.shoes?.id != null) ids.add(_outfit.shoes!.id!);
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
          appBar: PageAppBar(title: 'Manual Try-on', onBack: widget.onBack),
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
                  title: 'Middle',
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
                _slotRow(
                  title: 'Accessory',
                  iconAsset: 'assets/images/accessory.png',
                  value: _outfit.accessory,
                  category: GarmentCategory.accessory,
                  onPicked: (g) =>
                      setState(() => _outfit = _outfit.copyWith(accessory: g)),
                  onClear: _outfit.accessory == null
                      ? null
                      : () => setState(
                          () =>
                              _outfit = _outfit.copyWith(clearAccessory: true),
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
      ],
    );
  }

  Widget _slotRow({
    required String title,
    required String iconAsset,
    required Garment? value,
    required GarmentCategory category,
    required void Function(Garment g) onPicked,
    VoidCallback? onClear,
  }) {
    final detail = value == null
        ? null
        : (value.color?.isNotEmpty == true ? value.color! : value.subCategory);

    return AppListCard(
      onTap: (isOutfitLoading || _isLoadingGarments)
          ? null
          : () async {
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
      leadingAsset: value == null ? iconAsset : null,
      leading: value != null
          ? GarmentImage(
              url: value.imageUrl,
              width: 40,
              height: 40,
              borderRadius: 8,
              fit: BoxFit.cover,
            )
          : null,
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
