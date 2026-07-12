import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import 'widgets/common/number_stepper.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/common/section_title.dart';

class DailyPreferencesPage extends StatefulWidget {
  const DailyPreferencesPage({super.key});

  @override
  State<DailyPreferencesPage> createState() => _DailyPreferencesPageState();
}

class _DailyPreferencesPageState extends State<DailyPreferencesPage> {
  List<String> _weeklyOccasions = List.generate(7, (_) => 'casual_daily');
  int _temperatureOffset = 0;

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
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('weekly_occasions');
    final offset = prefs.getInt('temperature_offset') ?? 0;
    if (!mounted) return;
    if (saved != null && saved.length == 7) {
      setState(() {
        _weeklyOccasions = saved;
        _temperatureOffset = offset;
      });
    } else {
      final defaults = List.generate(7, (i) {
        final date = DateTime.now().add(Duration(days: i));
        return (date.weekday <= DateTime.friday) ? 'work' : 'casual_daily';
      });
      setState(() {
        _weeklyOccasions = defaults;
        _temperatureOffset = offset;
      });
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('weekly_occasions', _weeklyOccasions);
    await prefs.setString(
      'occasions_last_saved',
      DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
    await prefs.setInt('temperature_offset', _temperatureOffset);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: const PageAppBar(title: 'Daily Preferences'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 16),
            SectionTitle(
              'Comfort Adjustment',
              style: AppTextStyle.bold16.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildTempAdjuster(),
            const SizedBox(height: 24),
            SectionTitle(
              'Daily Occasions',
              style: AppTextStyle.bold16.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(7, (index) {
              final date = DateTime.now().add(Duration(days: index));
              final isToday = index == 0;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: isToday
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    DateFormat('E').format(date)[0],
                    style: TextStyle(
                      color: isToday ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  isToday
                      ? '${DateFormat('EEEE').format(date)} (Today)'
                      : DateFormat('EEEE').format(date),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: _weeklyOccasions[index],
                  underline: const SizedBox(),
                  items: _occasionLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _weeklyOccasions[index] = val);
                    }
                  },
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Apply',
                  style: AppTextStyle.bold16.copyWith(
                    color: AppColors.textPrimaryInv,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTempAdjuster() {
    return NumberStepper(
      label: 'Perceived temperature offset',
      valueLabel: '${_temperatureOffset > 0 ? "+" : ""}$_temperatureOffset°',
      onDecrement: () {
        if (_temperatureOffset > -5) setState(() => _temperatureOffset--);
      },
      onIncrement: () {
        if (_temperatureOffset < 5) setState(() => _temperatureOffset++);
      },
    );
  }
}
