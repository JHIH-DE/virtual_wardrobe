import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/auto_save_controller.dart';
import '../../data/occasion_type.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/occasion_type_localization.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/fields/number_stepper.dart';
import '../widgets/common/overlays/auto_save_prompts.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/occasion_picker_sheet.dart';
import '../widgets/common/section_title.dart';

class LifestylePage extends StatefulWidget {
  const LifestylePage({super.key});

  @override
  State<LifestylePage> createState() => _LifestylePageState();
}

class _LifestylePageState extends State<LifestylePage> {
  List<String> _weeklyOccasions = _defaultWeeklyOccasions();
  int _temperatureOffset = 0;

  late final AutoSaveController _autoSave = AutoSaveController(
    onSave: _persist,
    onError: (e) => showAutoSaveErrorDialog(
      context,
      _autoSave,
      e,
      fallback: _l10n.profileSaveFailed,
    ),
  );
  // Re-entrancy guard for _leave — a double-tap on back must not pop twice.
  bool _leaving = false;
  // Only while leaving waits on a save — drives the loading overlay.
  bool _savingBeforeLeave = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

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

  @override
  void dispose() {
    _autoSave.dispose();
    super.dispose();
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
    });
  }

  /// [AutoSaveController.onSave] — persists the whole current state; errors
  /// propagate so the controller can offer a retry. Snapshots the values
  /// first so the local cache always matches what was actually sent, even
  /// if the user changes another day while the PATCH is in flight.
  Future<void> _persist() async {
    final occasions = List.of(_weeklyOccasions);
    final offset = _temperatureOffset;
    await ProfileService().updateMyProfile(
      weeklySchedule: Map.fromIterables(_weekdayKeys, occasions),
      temperatureOffsetC: offset,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('weekly_occasions', occasions);
    await prefs.setInt('temperature_offset', offset);
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    try {
      final canLeave = await confirmLeaveAfterAutoSave(
        context,
        _autoSave,
        onFlushingChanged: (saving) =>
            setState(() => _savingBeforeLeave = saving),
      );
      if (canLeave && mounted) Navigator.pop(context);
    } finally {
      _leaving = false;
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.lifestyle, onBack: _leave);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _autoSave,
      builder: (context, child) => PopScope(
        canPop: !_autoSave.hasPendingChanges,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _leave();
        },
        child: child!,
      ),
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildContent(),
            if (_savingBeforeLeave)
              Positioned.fill(
                child: LoadingOverlay(label: _l10n.savingEllipsis),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
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
    );
  }

  /// A card's own title+subtitle header — same sizing as Style Taste's
  /// radar/profile cards ([SectionTitle] title, regular14 secondary
  /// subtitle) so every "titled card" in the app reads as one family.
  Widget _buildCardHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
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
    return AppCardShell(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Column(
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
    return AppCardShell(
      padding: const EdgeInsets.all(20),
      child: Column(
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
                '${_temperatureOffset > 0 ? "+" : ""}$_temperatureOffset°C',
            onDecrement: () {
              if (_temperatureOffset > -5) {
                setState(() => _temperatureOffset--);
                _autoSave.requestSave();
              }
            },
            onIncrement: () {
              if (_temperatureOffset < 5) {
                setState(() => _temperatureOffset++);
                _autoSave.requestSave();
              }
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
    final dayName = DateFormat(
      'EEEE',
    ).format(monday.add(Duration(days: index)));
    final selected = await showOccasionPickerSheet(
      context,
      current: current,
      title: _l10n.selectOccasionTitle(dayName),
    );

    if (selected == null || selected == current || !mounted) return;
    setState(() => _weeklyOccasions[index] = selected.apiValue);
    _autoSave.requestSave();
  }
}
