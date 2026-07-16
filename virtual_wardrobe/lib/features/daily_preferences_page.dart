import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/number_stepper.dart';
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

  AppToolBar _buildAppBar() {
    return const AppToolBar(title: 'Daily Preferences');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 16),
          _buildSectionTitle('Comfort Adjustment'),
          const SizedBox(height: 12),
          _buildTempAdjuster(),
          const SizedBox(height: 24),
          _buildSectionTitle('Daily Occasions'),
          const SizedBox(height: 8),
          ...List.generate(7, _buildOccasionTile),
          const SizedBox(height: 24),
          _buildApplyButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String label) {
    return SectionTitle(
      label,
      style: AppTextStyle.bold16.copyWith(color: AppColors.textSecondary),
    );
  }

  Widget _buildOccasionTile(int index) {
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
            color: isToday ? AppColors.textOnPrimary : AppColors.primary,
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
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _weeklyOccasions[index] = val);
          }
        },
      ),
    );
  }

  Widget _buildApplyButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'Apply',
          style: AppTextStyle.bold16.copyWith(color: AppColors.textOnPrimary),
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
