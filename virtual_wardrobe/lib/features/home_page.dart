import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/weather_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/daily_look_service.dart';
import '../core/utils/debug_log.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/look.dart';
import 'looks_details_page.dart';
import 'settings_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/lumi_insight_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TryOnMixin {
  bool _loadingLook = true;
  String? _reasoning;
  List<int> _garmentIds = [];

  @override
  void initState() {
    super.initState();
    _loadDailyLook();
  }

  Future<void> _loadDailyLook() async {
    setState(() => _loadingLook = true);
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      var look = await DailyLookService().getDailyLook(today);
      if (look == null) {
        final optionId = await DailyLookService().generateDailyLook(
          date: today,
        );
        await DailyLookService().createTryOnForOption(optionId);
        look = await DailyLookService().getDailyLook(today);
      }
      if (look == null) return;

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
        if (mounted) setState(() => _reasoning = null);
        return;
      }

      final option = options.first;
      final items = ((option['items'] as List?) ?? [])
          .whereType<Map<String, dynamic>>();
      final garmentIds = items
          .map((i) => (i['garment_id'] as num?)?.toInt())
          .whereType<int>()
          .toList();
      if (mounted) {
        final rawReasoning = option['reasoning'];
        setState(() {
          _garmentIds = garmentIds;
          if (rawReasoning is List) {
            _reasoning = rawReasoning.map((e) => '• $e').join('\n');
          } else {
            _reasoning = rawReasoning as String?;
          }
        });
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
      if (mounted) setState(() => _loadingLook = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildScaffold(context);
  }

  AppToolBar _buildAppBar(BuildContext context) {
    return AppToolBar(
      title: 'Home',
      showBackButton: false,
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
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildLookImageCard(),
                const SizedBox(height: 12),
                _buildLumiInsightCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final weatherAsync = ref.watch(weatherProvider);
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Image.asset('assets/images/ai-today.png', fit: BoxFit.contain),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(dateStr, style: AppTextStyle.title22),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  weatherAsync.when(
                    data: (w) => _headerChip(
                      icon: Icon(
                        WeatherData.iconFromCondition(w.condition),
                        size: 16,
                        color: AppColors.statusUpcoming,
                      ),
                      label: '${w.low}°C - ${w.high}°C',
                      tint: AppColors.statusUpcoming,
                    ),
                    loading: () => _headerChip(
                      icon: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: 'Loading weather...',
                      tint: AppColors.statusUpcoming,
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  weatherAsync.maybeWhen(
                    data: (w) => _headerChip(
                      icon: const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: AppColors.statusOngoing,
                      ),
                      label: w.location,
                      tint: AppColors.statusOngoing,
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerChip({
    required Widget icon,
    required String label,
    required Color tint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyle.bold14.copyWith(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildLookImageCard() {
    final loading = _loadingLook || isLookLoading;
    final imageUrl = tryOnResultUrl;
    final hasResult = !loading && imageUrl != null && imageUrl.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Today's Look", style: AppTextStyle.bold16),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: hasResult ? _openLookDetails : null,
          child: ClipRRect(
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
                          color: AppColors.icon,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppColors.icon,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openLookDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LooksDetailsPage(
          look: Look(
            id: tryOnJobId,
            imageUrl: tryOnResultUrl!,
            advice: tryOnAiAdvice,
            garmentIds: _garmentIds,
          ),
          isNew: true,
          confirmLeaveOnBack: false,
        ),
      ),
    );
  }

  Widget _buildLumiInsightCard() {
    if (_reasoning == null || _reasoning!.isEmpty) {
      return const SizedBox.shrink();
    }
    return LumiInsightCard(
      child: Text(
        _reasoning!,
        style: AppTextStyle.regular14.copyWith(
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
    );
  }
}
