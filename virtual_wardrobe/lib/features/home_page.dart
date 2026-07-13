import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/providers/weather_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/daily_look_service.dart';
import '../core/services/profile_service.dart';
import '../core/utils/debug_log.dart';
import '../core/utils/try_on_mixin.dart';
import 'create_page.dart';
import 'finance_page.dart';
import 'looks_page.dart';
import 'manual_try_on_page.dart';
import 'my_closet_page.dart';
import 'settings_page.dart';
import 'trip_planner_page.dart';
import 'widgets/common/app_card.dart';
import 'widgets/common/floating_nav_bar.dart';
import 'widgets/common/loading_overlay.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TryOnMixin {
  int? _selectedCardIndex;
  bool _openingCloset = false;
  bool _openingTryOn = false;

  String? _userName;
  bool _loadingOutfit = true;
  String? _stylingTips;

  final List<String> _features = [
    'My Closet',
    'Planner',
    'Manual Try-on',
    'Looks',
    'Finance',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDailyLook();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ProfileService().getMyProfile();
      final name = (profile['name'] as String?)?.trim();
      if (mounted && name != null && name.isNotEmpty) {
        setState(() => _userName = name.split(' ').first);
      }
    } catch (e) {
      debugLog('Failed to load profile: $e');
    }
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
        if (_openingCloset)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Closet...'),
          ),
        if (_openingTryOn)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Garments...'),
          ),
        const FloatingNavBar(current: AppTab.home),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) => _handleSwipe(context, details),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 20),
                    _buildGreeting(),
                    const SizedBox(height: 16),
                    _buildOutfitImageCard(),
                    const SizedBox(height: 12),
                    _buildOutfitMetaRow(),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              /*Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundLight,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(40),
                      topRight: Radius.circular(40),
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                      children: [
                        _buildQuickAddButton(context),
                        const SizedBox(height: 18),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _features.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 18,
                                mainAxisSpacing: 18,
                                childAspectRatio: 1.0,
                              ),
                          itemBuilder: (context, index) {
                            final feature = _features[index];
                            return AppVerticalCard(
                              label: feature,
                              iconPath: _getIconPath(feature),
                              isSelected: _selectedCardIndex == index,
                              onTap: () {
                                setState(() => _selectedCardIndex = index);
                                if (feature == 'My Closet') {
                                  _handleOpenMyCloset(context);
                                } else if (feature == 'Planner') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const TripPlannerPage(),
                                    ),
                                  );
                                } else if (feature == 'Manual Try-on') {
                                  _handleOpenManualTryOn(context);
                                } else if (feature == 'Looks') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const LooksPage(),
                                    ),
                                  );
                                } else if (feature == 'Finance') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FinancePage(),
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),*/
            ],
          ),
        ),
      ),
    );
  }

  /// Nav carousel order: Home -> My Closet -> Looks -> Finance, wrapping
  /// around. Swiping left/right from Home reaches its two neighbors.
  void _handleSwipe(BuildContext context, DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const threshold = 200.0;
    if (velocity < -threshold) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MyClosetPage()),
        (route) => route.isFirst,
      );
    } else if (velocity > threshold) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const FinancePage()),
        (route) => route.isFirst,
      );
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/logo.png', height: 40),
              const SizedBox(height: 2),
              Text(
                'Your personal AI closet',
                style: AppTextStyle.regular12.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          },
          borderRadius: BorderRadius.circular(25),
          child: Material(
            color: Colors.black,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 50,
              height: 50,
              child: Center(
                child: Image.asset(
                  'assets/images/setting.png',
                  width: 50,
                  height: 50,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGreeting() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset('assets/images/ai-today.png', width: 49, height: 49),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi, ${_userName ?? 'there'}!', style: AppTextStyle.bold18),
              const SizedBox(height: 2),
              Text(
                "Here's your dress idea for today!",
                style: AppTextStyle.bold14.copyWith(
                  color: AppColors.textSecondary,
                ),
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
                  cacheKey: tryOnJobId != 0
                      ? 'daily_look_job_$tryOnJobId'
                      : null,
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
    final weatherAsync = ref.watch(weatherProvider);
    return Row(
      children: [
        weatherAsync.when(
          data: (w) => Row(
            children: [
              Icon(
                WeatherData.iconFromCondition(w.condition),
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text('${w.low}°C - ${w.high}°C', style: AppTextStyle.regular14),
            ],
          ),
          loading: () => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
        if (_stylingTips != null && _stylingTips!.isNotEmpty) ...[
          const SizedBox(width: 12),
          Container(width: 1, height: 14, color: AppColors.border),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _stylingTips!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyle.regular14,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleOpenMyCloset(BuildContext context) async {
    setState(() => _openingCloset = true);
    try {
      await ref.read(garmentsProvider.future);
      if (!mounted) return;
      setState(() => _openingCloset = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyClosetPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingCloset = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load closet: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load closet')));
      }
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

  Widget _buildQuickAddButton(BuildContext context) {
    return AppHorizontalCard(
      label: 'Create',
      iconPath: 'assets/images/create.png',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreatePage()),
      ),
    );
  }

  String _getIconPath(String feature) {
    switch (feature) {
      case 'My Closet':
        return 'assets/images/my_closet.png';
      case 'Planner':
        return 'assets/images/ai_planner.png';
      case 'Manual Try-on':
        return 'assets/images/manul.png';
      case 'Looks':
        return 'assets/images/looks.png';
      case 'Finance':
        return 'assets/images/finance.png';
      default:
        return '';
    }
  }
}
