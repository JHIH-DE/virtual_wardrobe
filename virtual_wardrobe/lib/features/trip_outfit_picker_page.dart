import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../core/services/auth_handler.dart';
import '../core/services/outfit_service.dart';
import '../core/utils/debug_log.dart';
import '../data/outfit.dart';
import '../l10n/generated/app_localizations.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/outfit/outfit_card.dart';

/// Lets the user pick one of their saved outfits, so its garments can be
/// added to a trip's suitcase in one go — pops with the chosen [Outfit], or
/// null if dismissed without picking one.
class TripOutfitPickerPage extends StatefulWidget {
  const TripOutfitPickerPage({super.key});

  @override
  State<TripOutfitPickerPage> createState() => _TripOutfitPickerPageState();
}

class _TripOutfitPickerPageState extends State<TripOutfitPickerPage> {
  bool _loading = true;
  String? _error;
  List<Outfit> _outfits = const [];

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
      final outfits = await OutfitService().getAllOutfits();
      if (!mounted) return;
      setState(() => _outfits = outfits.where((o) => o.isSaved).toList());
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load outfits: $e');
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(title: l10n.selectAnOutfitTitle),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? ErrorStateWidget(error: _error!, onRetry: _load)
          : _buildGrid(l10n),
    );
  }

  Widget _buildGrid(AppLocalizations l10n) {
    if (_outfits.isEmpty) {
      return Center(child: EmptyStatePlaceholder(message: l10n.noOutfitsYet));
    }
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: AppDimens.outfitCardHeight,
      ),
      itemCount: _outfits.length,
      itemBuilder: (context, i) {
        final outfit = _outfits[i];
        return OutfitCard(
          outfit: outfit,
          onTap: () => Navigator.pop(context, outfit),
        );
      },
    );
  }
}
