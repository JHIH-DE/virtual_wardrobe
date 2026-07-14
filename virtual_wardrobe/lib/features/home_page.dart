import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/providers/weather_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/daily_look_service.dart';
import '../core/utils/debug_log.dart';
import '../core/utils/try_on_mixin.dart';
import 'manual_try_on_page.dart';
import 'settings_page.dart';
import 'trip_planner_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/garment/garment_upload_helper.dart';

enum _QuickAction { addClothing, manualTryOn, newTrip }

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TryOnMixin {
  bool _openingTryOn = false;

  bool _loadingOutfit = true;
  String? _stylingTips;

  @override
  void initState() {
    super.initState();
    _loadDailyLook();
  }

  Future<void> _loadDailyLook() async {
    setState(() => _loadingOutfit = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      var look = await DailyLookService().getDailyLook(today);
      look ??= await DailyLookService().generateDailyLook(date: today);

      final options =
          ((look['options'] as List?) ?? [])
              .whereType<Map<String, dynamic>>()
              .toList()
            ..sort(
              (a, b) => ((a['order_index'] as num?) ?? 0).compareTo(
                (b['order_index'] as num?) ?? 0,
              ),
            );

      if (options.isEmpty) {
        if (mounted) setState(() => _stylingTips = null);
        return;
      }

      final option = options.first;
      if (mounted) {
        setState(() => _stylingTips = option['styling_tips'] as String?);
      }

      final jobId = option['job_id'] as int?;
      debugLog('--- _loadDailyLook - jobId: $jobId  ---');
      if (jobId != null && jobId != 0) {
        await watchJob(jobId);
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load daily look: $e');
    } finally {
      if (mounted) setState(() => _loadingOutfit = false);
    }
  }

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
      title: 'Home',
      backgroundColor: AppColors.backgroundLight,
      showBackButton: false,
      leading: PopupMenuButton<_QuickAction>(
        icon: Container(
          padding: const EdgeInsets.all(4),
          child: Image.asset(
            'assets/images/plus.png',
            height: AppDimens.iconMediumSize,
          ),
        ),
        color: AppColors.surface,
        elevation: 8,
        padding: EdgeInsets.zero,
        offset: const Offset(0, 57),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (action) => _handleQuickAction(context, action),
        itemBuilder: (context) => [
          const PopupMenuItem(
            enabled: false,
            padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
            height: 0,
            child: Text('Quick Actions', style: AppTextStyle.regular12),
          ),
          _buildQuickActionItem(
            value: _QuickAction.addClothing,
            label: 'Add Clothing',
            icon: Icons.checkroom_outlined,
            showDivider: true,
          ),
          _buildQuickActionItem(
            value: _QuickAction.manualTryOn,
            label: 'Manual Try-on',
            icon: Icons.accessibility_new_outlined,
            showDivider: true,
          ),
          _buildQuickActionItem(
            value: _QuickAction.newTrip,
            label: 'New Trip',
            icon: Icons.luggage_outlined,
            showDivider: false,
          ),
        ],
      ),
      actions: [
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/setting.png',
            height: AppDimens.iconMediumSize,
          ),
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: _buildAppBar(context),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGreeting(),
                  const SizedBox(height: 16),
                  _buildOutfitImageCard(),
                  const SizedBox(height: 12),
                  _buildOutfitMetaRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final weatherAsync = ref.watch(weatherProvider);
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset('assets/images/ai-today.png', width: 49, height: 49),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateStr, style: AppTextStyle.bold16),
              const SizedBox(height: 4),
              weatherAsync.when(
                data: (w) => Row(
                  children: [
                    Icon(
                      WeatherData.iconFromCondition(w.condition),
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${w.low}°C - ${w.high}°C',
                      style: AppTextStyle.regular14,
                    ),
                  ],
                ),
                loading: () => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOutfitImageCard() {
    final loading = _loadingOutfit || isOutfitLoading;
    final imageUrl = tryOnResultUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 1 / 1.15,
        child: Container(
          color: AppColors.surface,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : (imageUrl == null || imageUrl.isEmpty)
              ? Center(
                  child: Icon(
                    Icons.checkroom,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildOutfitMetaRow() {
    if (_stylingTips == null || _stylingTips!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(_stylingTips!, style: AppTextStyle.regular14);
  }

  PopupMenuItem<_QuickAction> _buildQuickActionItem({
    required _QuickAction value,
    required String label,
    required IconData icon,
    required bool showDivider,
  }) {
    return PopupMenuItem(
      value: value,
      padding: EdgeInsets.zero,
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.dividerSubtle, width: 1),
                ),
              )
            : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyle.regular16),
            Icon(icon, size: 20, color: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }

  Future<void> _handleQuickAction(
    BuildContext context,
    _QuickAction action,
  ) async {
    switch (action) {
      case _QuickAction.addClothing:
        GarmentUploadHelper.showAddClothingDialog(
          context,
          onAdded: (g) => ref.read(garmentsProvider.notifier).addGarment(g),
        );
      case _QuickAction.manualTryOn:
        await _handleOpenManualTryOn(context);
      case _QuickAction.newTrip:
        await handleCreateTrip(context, ref);
    }
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
}
