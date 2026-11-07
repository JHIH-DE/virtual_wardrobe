import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/bottom_action_button.dart';
import '../../widgets/common/cards/app_card_shell.dart';
import '../../widgets/common/cards/app_list_card.dart';
import '../../widgets/common/overlays/picker_sheet.dart';
import '../../widgets/common/section_header.dart';

class _PointsPackage {
  final int points;
  final int priceNtd;
  const _PointsPackage(this.points, this.priceNtd);
}

/// UI only: the balance and packages are placeholders until the points and
/// purchase APIs exist.
class PointsPage extends StatefulWidget {
  const PointsPage({super.key});

  @override
  State<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends State<PointsPage> {
  static const _balance = 10000;
  static const _packages = [
    _PointsPackage(100, 60),
    _PointsPackage(300, 150),
    _PointsPackage(600, 270),
  ];

  int _selectedIndex = 1;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  String _formatPoints(int points) =>
      NumberFormat.decimalPattern(_l10n.localeName).format(points);

  @override
  Widget build(BuildContext context) {
    final selected = _packages[_selectedIndex];
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: AppToolBar(title: _l10n.uwearisPoints),
      bottomNavigationBar: BottomActionButton(
        label: _l10n.pointsContinue(_l10n.pointsPrice(selected.priceNtd)),
        onPressed: () {},
      ),
      body: Builder(
        builder: (bodyContext) => ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            BottomActionButton.scrollClearance(bodyContext),
          ),
          children: [
            _buildBalanceCard(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _l10n.pointsViewActivity,
                      style: AppTextStyle.semibold16.copyWith(
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      LucideIcons300.arrowRight,
                      size: AppDimens.iconSmallSize,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimens.sectionSpacing),
            SectionHeader(
              title: _l10n.pointsAddTitle,
              subtitle: _l10n.pointsAddSubtitle,
            ),
            RadioGroup<int>(
              groupValue: _selectedIndex,
              onChanged: (i) {
                if (i != null) setState(() => _selectedIndex = i);
              },
              child: Column(
                children: [
                  for (var i = 0; i < _packages.length; i++) ...[
                    const SizedBox(height: AppDimens.cardSpacing),
                    _buildPackageOption(i),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppDimens.sectionSpacing),
            _buildIllustrativeNote(),
            const SizedBox(height: AppDimens.sectionSpacing),
            Text(
              _l10n.pointsOneTimeNote,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppDimens.sectionSpacing),
            AppListCard(
              onTap: _showHowPointsWork,
              showArrow: true,
              child: Text(_l10n.pointsHowItWorks, style: AppTextStyle.bold16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return AppCardShell(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _l10n.pointsAvailable,
            style: AppTextStyle.regular16.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          _buildPointsAmount(_balance, fontSize: 40),
          const SizedBox(height: 8),
          Text(
            _l10n.pointsBalanceHint,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsAmount(int points, {required double fontSize}) {
    return Text.rich(
      TextSpan(
        style: AppTextStyle.bold24.copyWith(fontSize: fontSize, height: 1.2),
        children: [
          TextSpan(
            text: '${_l10n.aiCreditsSymbol} ',
            style: const TextStyle(color: AppColors.accent),
          ),
          TextSpan(text: _formatPoints(points)),
        ],
      ),
    );
  }

  Widget _buildPackageOption(int index) {
    final package = _packages[index];
    final selected = index == _selectedIndex;
    return Material(
      color: selected ? AppColors.accentTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: BorderSide(
          color: selected ? AppColors.accent : AppColors.borderSubtle,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 18, 12),
          child: Row(
            children: [
              Radio<int>(value: index, activeColor: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(child: _buildPointsAmount(package.points, fontSize: 26)),
              Text(
                _l10n.pointsPrice(package.priceNtd),
                style: AppTextStyle.semibold16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustrativeNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.headerChipBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons300.info,
            size: AppDimens.iconSmallSize,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _l10n.pointsIllustrativeNote,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHowPointsWork() {
    showPickerSheet<void>(
      context,
      fitContent: true,
      builder: (_) => PickerSheetHeader(
        _l10n.pointsHowItWorks,
        description: _l10n.pointsHowItWorksBody,
      ),
    );
  }
}
