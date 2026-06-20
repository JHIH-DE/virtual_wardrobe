import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/app_colors.dart';
import '../core/providers/looks_provider.dart';
import '../core/providers/weather_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/weekly_plans_service.dart';
import '../core/services/outfit_service.dart';
import 'try_on_mixin.dart';
import '../data/garment.dart';
import '../data/look.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/today_outfit_idea.dart';

class DailyPlannerTab extends ConsumerStatefulWidget {
  const DailyPlannerTab({super.key});

  @override
  ConsumerState<DailyPlannerTab> createState() => _DailyPlannerTabState();
}

class _DailyPlannerTabState extends ConsumerState<DailyPlannerTab>
    with TryOnMixin {
  // 週計畫
  List<String> _weeklyOccasions = List.generate(7, (_) => 'casual_daily');
  int _counterValue = 0;

  // 當日資料
  List<Garment> _todayGarments = [];
  bool _loadingOutfits = false;
  int _selectedDayIndex = 0;
  String? _todayLookImageUrl;

  bool _planCreated = false;

  final Map<String, String> _occasionLabels = {
    'casual_daily': '🏠 Daily',
    'work': '💼 Work',
    'date': '❤️ Date',
    'sport': '🏃 Sport',
    'formal': '👔 Formal',
  };

  @override
  void initState() {
    super.initState();
    _initOccasions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(weatherProvider, (_, next) async {
        if (next.hasValue && !_planCreated) {
          _planCreated = true;
          await _createWeeklyPlan(next.value!);
          await _loadDailyData();
        }
      }, fireImmediately: true);
    });
  }

  Future<void> _initOccasions() async {
    final prefs = await SharedPreferences.getInstance();
    final lastSavedDate = prefs.getString('occasions_last_saved');
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastSavedDate == todayStr) {
      final saved = prefs.getStringList('weekly_occasions');
      if (saved != null && saved.length == 7) {
        if (mounted) setState(() => _weeklyOccasions = saved);
        return;
      }
    }

    final newOccasions = List.generate(7, (i) {
      final date = DateTime.now().add(Duration(days: i));
      return (date.weekday >= DateTime.monday && date.weekday <= DateTime.friday)
          ? 'work'
          : 'casual_daily';
    });

    if (mounted) setState(() => _weeklyOccasions = newOccasions);
    await _saveOccasions();
  }

  Future<void> _saveOccasions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('weekly_occasions', _weeklyOccasions);
    await prefs.setString(
        'occasions_last_saved', DateFormat('yyyy-MM-dd').format(DateTime.now()));
  }

  Future<void> _loadDailyData() async {
    await _getGarments(daysFromNow: _selectedDayIndex);
    await _getOutfits(daysFromNow: _selectedDayIndex);
  }

  Future<void> _createWeeklyPlan(WeatherData weather) async {
    try {
      final adjustedTemps =
          weather.weeklyHighs.map((t) => t + _counterValue).toList();
      await WeeklyPlansService()
          .createWeeklyPlan(tempsC: adjustedTemps, occasions: _weeklyOccasions);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugPrint('Failed to _createWeeklyPlan: $e');
    }
  }

  Future<void> _getGarments({int daysFromNow = 0}) async {
    final day = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(Duration(days: daysFromNow)));
    if (mounted) setState(() => _loadingOutfits = true);
    try {
      var list = await WeeklyPlansService().getGarments(day);

      if (list.isEmpty || list.every((g) => g.id == null)) {
        final weather = ref.read(weatherProvider).valueOrNull;
        if (weather != null) {
          final adjustedTemps =
              weather.weeklyHighs.map((t) => t + _counterValue).toList();
          await WeeklyPlansService().createWeeklyPlan(
            tempsC: adjustedTemps,
            occasions: _weeklyOccasions,
            forceRegenerate: true,
          );
          list = await WeeklyPlansService().getGarments(day);
        }
      }

      if (mounted) setState(() => _todayGarments = list);
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugPrint('Failed to _getGarments: $e');
    } finally {
      if (mounted) setState(() => _loadingOutfits = false);
    }
  }

  Future<void> _getOutfits({int daysFromNow = 0}) async {
    final day = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().add(Duration(days: daysFromNow)));
    try {
      final jobId = await WeeklyPlansService().getLook(day);
      if (jobId != null) {
        final statusRes = await OutfitService().getOutfit(jobId);
        if (mounted) {
          setState(() {
            _todayLookImageUrl = statusRes['result_image_url'];
            resetTryOnState();
          });
        }
      } else {
        if (mounted) setState(() => _todayLookImageUrl = null);
      }
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugPrint('Failed to _getOutfits: $e');
      if (mounted) setState(() => _todayLookImageUrl = null);
    }
  }

  Future<void> _handleGenerateLook() async {
    if (_todayGarments.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No garments to generate look from.')));
      }
      return;
    }

    final ids = _todayGarments
        .where((g) => g.garmentId != null)
        .map((g) => g.garmentId!)
        .toList();
    final int? jobId = await performTryOn(ids, 'weekly');

    if (jobId != null) {
      final day = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(Duration(days: _selectedDayIndex)));
      try {
        await WeeklyPlansService().saveJobId(day, jobId);
      } catch (e) {
        debugPrint('Failed to save jobId: $e');
      }
    }
  }

  Future<void> _onSaveLook() async {
    final url = tryOnResultUrl ?? _todayLookImageUrl;
    if (url == null) return;

    try {
      final look = Look(
        id: tryOnJobId,
        imageUrl: url,
        seasons: _weeklyOccasions[_selectedDayIndex],
        style: 'Daily',
        advice: tryOnAiAdvice,
      );
      ref.read(looksProvider.notifier).add(look);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved to Closet ✅')));
      }
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(weatherProvider);

    return weatherAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(weatherProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (weather) => _buildContent(weather),
    );
  }

  Widget _buildContent(WeatherData weather) {
    return Container(
      color: AppColors.defaultBackground,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weather.location,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary)),
                  Text(DateFormat('MMMM d, EEEE').format(DateTime.now()),
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              IconButton(
                onPressed: _showPlanSettings,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.tune_rounded,
                      color: AppColors.primary, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildWeeklyWeatherBar(weather),
          const SizedBox(height: 20),
          _buildWardrobeSection(),
          const SizedBox(height: 20),
          TodayOutfitIdea(
            onSave: _onSaveLook,
            onGenerate: _handleGenerateLook,
            imageUrl: tryOnResultUrl ?? _todayLookImageUrl,
            isLoading: _loadingOutfits || isOutfitLoading,
            jobStatus: isOutfitLoading
                ? (tryOnJobId == 0 ? 'Creating...' : 'Generating...')
                : null,
            errorMessage: tryOnErrorMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyWeatherBar(WeatherData weather) {
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isToday = index == 0;
          final isSelected = index == _selectedDayIndex;
          final code = weather.weeklyCodes.isNotEmpty
              ? weather.weeklyCodes[index]
              : 0;
          final high = weather.weeklyHighs[index].round();
          final low = weather.weeklyLows[index].round();
          final condition = WeatherData.conditionFromCode(code);

          return GestureDetector(
            onTap: () async {
              if (mounted) setState(() => _selectedDayIndex = index);
              await _loadDailyData();
            },
            onLongPress: _showPlanSettings,
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: isSelected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isToday ? 'Today' : DateFormat('E').format(date),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Icon(WeatherData.iconFromCondition(condition),
                      size: 28, color: AppColors.textPrimary),
                  const SizedBox(height: 8),
                  Text('$high° / $low°',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWardrobeSection() {
    final selectedDateStr = DateFormat('EEEE, MMMM d')
        .format(DateTime.now().add(Duration(days: _selectedDayIndex)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Items for $selectedDateStr',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        if (_loadingOutfits)
          const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()))
        else if (_todayGarments.isEmpty)
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
                child: Text('No items planned for this day',
                    style: TextStyle(color: AppColors.textSecondary))),
          )
        else
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _todayGarments.length,
              itemBuilder: (context, index) {
                final garment = _todayGarments[index];
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: garment.imageUrl != null && garment.imageUrl!.isNotEmpty
                        ? Image.network(garment.imageUrl!, fit: BoxFit.cover)
                        : const Icon(Icons.inventory_2_outlined,
                            color: AppColors.textSecondary),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _showPlanSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: AppColors.defaultBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Plan Customization',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildSectionTitle('Comfort Adjustment'),
                    const SizedBox(height: 12),
                    _buildTempAdjuster(setModalState),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Daily Occasions'),
                    const SizedBox(height: 8),
                    ...List.generate(7, (i) => i).map((index) {
                      final date =
                          DateTime.now().add(Duration(days: index));
                      final isToday = index == 0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isToday
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.1),
                          child: Text(DateFormat('E').format(date)[0],
                              style: TextStyle(
                                  color: isToday
                                      ? Colors.white
                                      : AppColors.primary,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          isToday
                              ? '${DateFormat('EEEE').format(date)} (Today)'
                              : DateFormat('EEEE').format(date),
                          style: TextStyle(
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                        ),
                        trailing: DropdownButton<String>(
                          value: _weeklyOccasions[index],
                          underline: const SizedBox(),
                          items: _occasionLabels.entries
                              .map((e) => DropdownMenuItem(
                                  value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(
                                  () => _weeklyOccasions[index] = val);
                              if (mounted) setState(() {});
                              _saveOccasions();
                            }
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
              BottomActionButton(
                label: 'Apply',
                onPressed: () async {
                  final weather =
                      ref.read(weatherProvider).valueOrNull;
                  if (weather != null) {
                    await _createWeeklyPlan(weather);
                  }
                  await _loadDailyData();
                  if (context.mounted) Navigator.pop(context);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Plan updated based on your settings')));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary));
  }

  Widget _buildTempAdjuster(StateSetter setModalState) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Expanded(
              child: Text('Perceived temperature offset',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
          IconButton(
            onPressed: () {
              if (_counterValue > -5) {
                setModalState(() => _counterValue--);
                if (mounted) setState(() {});
              }
            },
            icon: const Icon(Icons.remove_circle_outline,
                color: AppColors.textSecondary),
          ),
          SizedBox(
            width: 50,
            child: Text(
              '${_counterValue > 0 ? "+" : ""}$_counterValue°',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
          ),
          IconButton(
            onPressed: () {
              if (_counterValue < 5) {
                setModalState(() => _counterValue++);
                if (mounted) setState(() {});
              }
            },
            icon: const Icon(Icons.add_circle_outline,
                color: AppColors.primary),
          ),
        ],
      ),
    );
  }

}
