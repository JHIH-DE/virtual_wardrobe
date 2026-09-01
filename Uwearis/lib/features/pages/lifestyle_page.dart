import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/profile_service.dart';
import '../../data/occasion_type.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/occasion_type_localization.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/fields/number_stepper.dart';
import '../widgets/common/overlays/picker_sheet.dart';

class LifestylePage extends StatefulWidget {
  const LifestylePage({super.key});

  @override
  State<LifestylePage> createState() => _LifestylePageState();
}

class _LifestylePageState extends State<LifestylePage> {
  List<String> _weeklyOccasions = _defaultWeeklyOccasions();
  int _temperatureOffset = 0;
  bool _saving = false;

  late List<String> _initialWeeklyOccasions = List.of(_weeklyOccasions);
  int _initialTemperatureOffset = 0;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  bool get _isModified =>
      !listEquals(_weeklyOccasions, _initialWeeklyOccasions) ||
      _temperatureOffset != _initialTemperatureOffset;

  // Index 0 = Monday ... 6 = Sunday, matching the fixed weekly card order.
  static List<String> _defaultWeeklyOccasions() => List.generate(
    7,
    (i) => (i < 5 ? OccasionType.work : OccasionType.casual).apiValue,
  );

  static const _weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  /// Maps a stored value to a currently-valid occasion id, falling back to
  /// Work for values from a retired taxonomy (e.g. an older build's
  /// 'casual_daily' / 'sport' / 'formal').
  static String _normalizeOccasion(String stored) =>
      (occasionTypeFromApiValue(stored) ?? OccasionType.work).apiValue;

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
    final loaded = (saved != null && saved.length == 7)
        ? saved.map(_normalizeOccasion).toList()
        : _defaultWeeklyOccasions();
    setState(() {
      _weeklyOccasions = loaded;
      _temperatureOffset = offset;
      _initialWeeklyOccasions = List.of(loaded);
      _initialTemperatureOffset = offset;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ProfileService().updateMyProfile(
        weeklySchedule: Map.fromIterables(_weekdayKeys, _weeklyOccasions),
        temperatureOffsetC: _temperatureOffset,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('weekly_occasions', _weeklyOccasions);
      await prefs.setString(
        'occasions_last_saved',
        DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      await prefs.setInt('temperature_offset', _temperatureOffset);
      if (!mounted) return;
      setState(() {
        _initialWeeklyOccasions = List.of(_weeklyOccasions);
        _initialTemperatureOffset = _temperatureOffset;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.settingsSaved)));
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.lifestyle);
  }

  bool get _showsBottomActionButton => _isModified && !_saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          _showsBottomActionButton ? AppDimens.bottomActionBtnClearance : 20,
        ),
        children: [
          const SizedBox(height: AppDimens.sectionSpacing),
          Text(
            _l10n.lifestyleDescription,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppDimens.sectionSpacing),
          _buildWeeklyScheduleCard(),
          const SizedBox(height: AppDimens.sectionSpacing),
          _buildComfortAdjustmentCard(),
        ],
      ),
      bottomNavigationBar: BottomActionButton(
        label: _l10n.save,
        onPressed: _save,
        isLoading: _saving,
        enabled: _isModified,
      ),
    );
  }

  /// Shared white-card chrome — radius, shadow — matching every other
  /// page-level card in the app (see tryon_profile_page.dart's own
  /// _buildCardShell): same [AppDimens.cardRadius], same resting shadow.
  Widget _buildCardShell(Widget child, {double bottomPadding = 20}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  /// A card's own title+subtitle header — same sizing as Style Taste's
  /// radar/profile cards (bold18 title, regular14 secondary subtitle) so
  /// every "titled card" in the app reads as one family.
  Widget _buildCardHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyle.bold18),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTextStyle.regular14.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklyScheduleCard() {
    return _buildCardShell(
      bottomPadding: 6,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(_l10n.weeklySchedule, _l10n.weeklyScheduleIntro),
          const SizedBox(height: AppDimens.cardHeaderGap),
          const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle),
          for (var i = 0; i < 7; i++) ...[
            _buildWeekdayRow(i),
            if (i < 6)
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColors.borderSubtle,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekdayRow(int index) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final date = monday.add(Duration(days: index));
    final occasion =
        occasionTypeFromApiValue(_weeklyOccasions[index]) ?? OccasionType.work;

    return InkWell(
      onTap: () => _openOccasionPicker(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                DateFormat('EEEE').format(date),
                style: AppTextStyle.semibold16,
              ),
            ),
            Icon(occasion.icon, size: 18, color: AppColors.icon),
            const SizedBox(width: 6),
            Text(
              occasion.localizedLabel(context),
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Image.asset(
              'assets/images/page_arrow_right.png',
              width: 20,
              height: 20,
              color: AppColors.textSecondary,
              colorBlendMode: BlendMode.srcIn,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComfortAdjustmentCard() {
    return _buildCardShell(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            _l10n.comfortAdjustment,
            _l10n.comfortAdjustmentIntro,
          ),
          const SizedBox(height: AppDimens.cardHeaderGap),
          NumberStepper(
            label: _l10n.perceivedTempOffset,
            valueLabel:
                '${_temperatureOffset > 0 ? "+" : ""}$_temperatureOffset°',
            onDecrement: () {
              if (_temperatureOffset > -5) {
                setState(() => _temperatureOffset--);
              }
            },
            onIncrement: () {
              if (_temperatureOffset < 5) setState(() => _temperatureOffset++);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openOccasionPicker(int index) async {
    final current =
        occasionTypeFromApiValue(_weeklyOccasions[index]) ?? OccasionType.work;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayName = DateFormat('EEEE').format(monday.add(Duration(days: index)));
    final selected = await showPickerSheet<OccasionType>(
      context,
      builder: (sheetContext) => RadioGroup<OccasionType>(
        groupValue: current,
        onChanged: (v) {
          if (v != null) Navigator.pop(sheetContext, v);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PickerSheetHeader(_l10n.selectOccasionTitle(dayName)),
            for (final occasion in OccasionType.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: occasion == current
                      ? BoxDecoration(
                          color: AppColors.accentTint,
                          borderRadius: BorderRadius.circular(10),
                        )
                      : null,
                  child: Icon(
                    occasion.icon,
                    size: 18,
                    color: occasion == current
                        ? AppColors.accent
                        : AppColors.icon,
                  ),
                ),
                title: Text(
                  occasion.localizedLabel(sheetContext),
                  style: occasion == current
                      ? AppTextStyle.bold16
                      : AppTextStyle.regular16,
                ),
                trailing: Radio<OccasionType>(
                  value: occasion,
                  activeColor: AppColors.accent,
                ),
                onTap: () => Navigator.pop(sheetContext, occasion),
              ),
          ],
        ),
      ),
    );

    if (selected == null || selected == current) return;
    setState(() => _weeklyOccasions[index] = selected.apiValue);
  }
}
