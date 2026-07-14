import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/utils/debug_log.dart';
import 'edit_garment_page.dart';
import 'body_profile_page.dart';
import 'manual_try_on_page.dart';
import 'trip_planner_page.dart';
import 'widgets/common/app_card.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/loading_overlay.dart';

class CreatePage extends ConsumerStatefulWidget {
  const CreatePage({super.key});

  @override
  ConsumerState<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends ConsumerState<CreatePage> {
  bool _openingTryOn = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(context),
        if (_openingTryOn)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Garments...'),
          ),
      ],
    );
  }

  AppToolBar _buildAppBar(BuildContext context) {
    return AppToolBar(
      title: 'Create',
      backgroundColor: AppColors.defaultToolBar,
      actions: [
        IconButton(
          icon: Container(
            child: Image.asset('assets/images/figure_setting.png', height: 40),
          ),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BodyProfilePage()),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            _buildCard(
              context,
              label: 'Add Clothing',
              iconPath: 'assets/images/add.png',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditGarmentPage()),
              ),
            ),
            const SizedBox(height: 18),
            _buildCard(
              context,
              label: 'Manual Try-on',
              iconPath: 'assets/images/manul.png',
              onTap: () => _handleOpenManualTryOn(context),
            ),
            const SizedBox(height: 18),
            _buildCard(
              context,
              label: 'Daily Planner',
              iconPath: 'assets/images/daily_planner.png',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripPlannerPage()),
              ),
            ),
            const SizedBox(height: 18),
            _buildCard(
              context,
              label: 'Trip Planner',
              iconPath: 'assets/images/trip_planner.png',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripPlannerPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleOpenManualTryOn(BuildContext context) async {
    setState(() => _openingTryOn = true);
    try {
      final garments = await ref.read(garmentsProvider.future);
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualTryOnPage(
            preloadedGarments: garments,
            onBack: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load garments: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load garments')),
        );
      }
    }
  }

  Widget _buildCard(
    BuildContext context, {
    required String label,
    required String iconPath,
    required VoidCallback onTap,
  }) {
    return AppVerticalCard(
      label: label,
      iconPath: iconPath,
      isSelected: false,
      onTap: onTap,
      height: 140,
    );
  }
}
