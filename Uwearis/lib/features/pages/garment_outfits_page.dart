import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/outfit_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/outfit_season_style_filter.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/outfit/outfit_grid.dart';
import 'outfit_details_page.dart';

class GarmentOutfitsPage extends StatefulWidget {
  final int garmentId;

  const GarmentOutfitsPage({super.key, required this.garmentId});

  @override
  State<GarmentOutfitsPage> createState() => _GarmentOutfitsPageState();
}

class _GarmentOutfitsPageState extends State<GarmentOutfitsPage> {
  final _filter = OutfitSeasonStyleFilter();

  List<Outfit> _allOutfits = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugLog('getOutfitsByGarments garmentId=${widget.garmentId}');
      final result = await OutfitService().getOutfitsByGarments([
        widget.garmentId,
      ]);
      // `by-garments` also returns daily/trip-generated outfits, which
      // shouldn't surface here — this page is about the garment's saved
      // (general) outfits only.
      final general = result
          .where((o) => o.groupType == OutfitGroupType.general)
          .toList();
      if (!mounted) return;
      setState(() => _allOutfits = general);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  AppToolBar _buildAppBar() {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.usedInOutfits,
      actions: [
        _filter.buildButton(l10n, onChanged: () => setState(() {})),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: AppSpinner())
          : _error != null
          ? ErrorStateWidget(error: _error!, onRetry: _load)
          : OutfitGrid(
              outfits: _filter.apply(_allOutfits),
              onRefresh: _load,
              emptyMessage: AppLocalizations.of(
                context,
              ).itemNotUsedInOutfitsYet,
              onOutfitTap: (outfit) => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OutfitDetailsPage(outfit: outfit),
                ),
              ),
            ),
    );
  }
}
