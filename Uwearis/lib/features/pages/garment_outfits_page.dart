import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../core/providers/garment_outfits_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../data/outfit.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/outfit_season_style_filter.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/outfit/outfit_grid.dart';
import 'outfit_details_page.dart';

class GarmentOutfitsPage extends ConsumerStatefulWidget {
  final int garmentId;

  const GarmentOutfitsPage({super.key, required this.garmentId});

  @override
  ConsumerState<GarmentOutfitsPage> createState() => _GarmentOutfitsPageState();
}

class _GarmentOutfitsPageState extends ConsumerState<GarmentOutfitsPage> {
  final _filter = OutfitSeasonStyleFilter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(garmentOutfitsProvider(widget.garmentId), (_, next) {
        if (next.hasError && next.error is AuthExpiredException && mounted) {
          AuthExpiredHandler.handle(context);
        }
      });
    });
  }

  void _refresh() => ref.invalidate(garmentOutfitsProvider(widget.garmentId));

  AppToolBar _buildAppBar(List<Outfit> outfits) {
    final l10n = AppLocalizations.of(context);
    return AppToolBar(
      title: l10n.usedInOutfits,
      actions: [
        _filter.buildButton(l10n, outfits, onChanged: () => setState(() {})),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final outfitsAsync = ref.watch(garmentOutfitsProvider(widget.garmentId));
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(outfitsAsync.value ?? const []),
      body: outfitsAsync.when(
        loading: () => const Center(child: AppSpinner()),
        error: (e, _) => ErrorStateWidget(error: e, onRetry: _refresh),
        data: (outfits) => OutfitGrid(
          outfits: _filter.apply(outfits),
          onRefresh: () async => _refresh(),
          emptyMessage: AppLocalizations.of(context).itemNotUsedInOutfitsYet,
          onOutfitTap: (outfit) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OutfitDetailsPage(outfit: outfit),
            ),
          ),
        ),
      ),
    );
  }
}
