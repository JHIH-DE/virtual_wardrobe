import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garments_service.dart';
import 'looks_details_page.dart';
import 'try_on_mixin.dart';
import '../data/garment.dart';
import 'select_garment_page.dart';
import 'widgets/app_list_card.dart';
import 'widgets/garment_image.dart';
import 'widgets/page_app_bar.dart';
import 'widgets/bottom_action_button.dart';

class ManualTryOnPage extends StatefulWidget {
  const ManualTryOnPage({super.key});

  @override
  State<ManualTryOnPage> createState() => _ManualTryOnPageState();
}

class _ManualTryOnPageState extends State<ManualTryOnPage> with TryOnMixin {
  final List<Garment> _allGarments = [];
  OutfitSelection _outfit = const OutfitSelection();

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
    _loadGarments();
  }

  Future<void> _loadGarments() async {
    try {
      final list = await GarmentService().getGarments();
      if (mounted) setState(() => _allGarments..clear()..addAll(list));
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (_) {}
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
            imageUrl: tryOnResultUrl!,
            aiAdvice: tryOnAiAdvice,
            jobId: tryOnJobId,
          ),
        ),
      );
      if (mounted) resetTryOnState();
    } else if (tryOnErrorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tryOnErrorMessage!)),
      );
      resetTryOnState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: const PageAppBar(title: 'Manual Try-on'),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              children: [
                Text(
                  'Select the clothing combinations you\'d like to try, then click "Create Look" to see your try-on results!',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                _slotRow(
                  title: 'Top',
                  iconAsset: 'assets/images/top.png',
                  value: _outfit.top,
                  category: GarmentCategory.top,
                  onPicked: (g) => setState(() => _outfit = _outfit.copyWith(top: g)),
                  onClear: _outfit.top == null ? null : () => setState(() => _outfit = _outfit.copyWith(clearTop: true)),
                ),
                const SizedBox(height: 12),
                _slotRow(
                  title: 'Middle',
                  iconAsset: 'assets/images/outer.png',
                  value: _outfit.middle,
                  category: GarmentCategory.top,
                  onPicked: (g) => setState(() => _outfit = _outfit.copyWith(middle: g)),
                  onClear: _outfit.middle == null ? null : () => setState(() => _outfit = _outfit.copyWith(clearMiddle: true)),
                ),
                const SizedBox(height: 12),
                _slotRow(
                  title: 'Outerwear',
                  iconAsset: 'assets/images/outer.png',
                  value: _outfit.outer,
                  category: GarmentCategory.outer,
                  onPicked: (g) => setState(() => _outfit = _outfit.copyWith(outer: g)),
                  onClear: _outfit.outer == null ? null : () => setState(() => _outfit = _outfit.copyWith(clearOuter: true)),
                ),
                const SizedBox(height: 12),
                _slotRow(
                  title: 'Bottom',
                  iconAsset: 'assets/images/buttom.png',
                  value: _outfit.bottom,
                  category: GarmentCategory.bottom,
                  onPicked: (g) => setState(() => _outfit = _outfit.copyWith(bottom: g)),
                  onClear: _outfit.bottom == null ? null : () => setState(() => _outfit = _outfit.copyWith(clearBottom: true)),
                ),
                const SizedBox(height: 12),
                _slotRow(
                  title: 'Shoes',
                  iconAsset: 'assets/images/shoes.png',
                  value: _outfit.shoes,
                  category: GarmentCategory.shoes,
                  onPicked: (g) => setState(() => _outfit = _outfit.copyWith(shoes: g)),
                  onClear: _outfit.shoes == null ? null : () => setState(() => _outfit = _outfit.copyWith(clearShoes: true)),
                ),
                const SizedBox(height: 12),
                _slotRow(
                  title: 'Accessory',
                  iconAsset: 'assets/images/accessory.png',
                  value: _outfit.accessory,
                  category: GarmentCategory.accessory,
                  onPicked: (g) => setState(() => _outfit = _outfit.copyWith(accessory: g)),
                  onClear: _outfit.accessory == null ? null : () => setState(() => _outfit = _outfit.copyWith(clearAccessory: true)),
                ),
              ],
            ),
            if (isOutfitLoading)
              Container(
                color: AppColors.primary.withValues(alpha: 0.88),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.textPrimaryInv,
                      strokeWidth: 2,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Creating Looks...',
                      style: AppTextStyle.bold16.copyWith(color: AppColors.textPrimaryInv),
                    ),
                  ],
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
      onTap: isOutfitLoading
          ? null
          : () async {
              final picked = await Navigator.push<Garment>(
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
              if (picked != null) onPicked(picked);
            },
      showArrow: true,
      status: value == null ? 'select' : 'edit',
      leadingAsset: value == null ? iconAsset : null,
      leading: value != null
          ? GarmentImage(url: value.imageUrl, width: 40, height: 40, borderRadius: 8, fit: BoxFit.cover)
          : null,
      summary: detail?.isNotEmpty == true ? detail : null,
      child: Text(
        value == null ? title : value.name,
        style: AppTextStyle.bold16,
      ),
    );
  }
}
