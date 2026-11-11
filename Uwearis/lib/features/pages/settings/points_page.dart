import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/providers/points_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/utils/api_error_text.dart';
import '../../../data/points.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/points_localization.dart';
import '../../widgets/common/app_divider.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/buttons/action_disc_button.dart';
import '../../widgets/common/buttons/bottom_action_button.dart';
import '../../widgets/common/cards/app_card_shell.dart';
import '../../widgets/common/cards/app_list_card.dart';
import '../../widgets/common/field_label.dart';
import '../../widgets/common/overlays/error_state_widget.dart';
import '../../widgets/common/overlays/page_sheet.dart';
import '../../widgets/common/overlays/picker_sheet.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/points_amount.dart';
import '../../widgets/common/section_header.dart';
import 'points_activity_page.dart';

class _Plan {
  final String Function(AppLocalizations l10n) name;
  final int points;
  final int priceNtd;
  final bool isSubscription;
  final String Function(AppLocalizations l10n)? badge;

  const _Plan({
    required this.name,
    required this.points,
    required this.priceNtd,
    this.isSubscription = false,
    this.badge,
  });
}

/// Balance, daily grant and per-feature costs from `GET /points`. The plans
/// are still illustrative: there is no purchase flow yet.
class PointsPage extends ConsumerStatefulWidget {
  const PointsPage({super.key});

  @override
  ConsumerState<PointsPage> createState() => _PointsPageState();
}

class _PointsPageState extends ConsumerState<PointsPage> {
  // Plus grants [points] per day, not once.
  static final _plus = _Plan(
    name: (l) => l.pointsPlusTitle,
    points: 75,
    priceNtd: 199,
    isSubscription: true,
  );
  static final _packs = [
    _Plan(name: (l) => l.pointsPackSmall, points: 750, priceNtd: 99),
    _Plan(
      name: (l) => l.pointsPackStandard,
      points: 2500,
      priceNtd: 299,
      badge: (l) => l.pointsBadgePopular,
    ),
    _Plan(
      name: (l) => l.pointsPackLarge,
      points: 9000,
      priceNtd: 999,
      badge: (l) => l.pointsBadgeBestValue,
    ),
  ];
  static final _plans = [_plus, ..._packs];

  int _selectedIndex = _plans.indexOf(_packs[1]);

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// Extra points per NT$ compared with the smallest pack.
  int _bonusPercent(_Plan pack) {
    final base = _packs.first;
    final ratio = (pack.points * base.priceNtd) / (base.points * pack.priceNtd);
    return ((ratio - 1) * 100).round();
  }

  @override
  void initState() {
    super.initState();
    // The shell's copy may be from hours ago; show the balance as of now.
    unawaited(ref.read(pointsProvider.notifier).reloadPoints());
  }

  String get _actionLabel {
    final plan = _plans[_selectedIndex];
    final price = _l10n.pointsPrice(plan.priceNtd);
    return plan.isSubscription
        ? _l10n.pointsSubscribe('$price${_l10n.pointsPerMonth}')
        : _l10n.pointsContinue(price);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pointsProvider, (_, next) {
      if (next.error is AuthExpiredException) {
        AuthExpiredHandler.handle(context);
      }
    });
    final points = ref.watch(pointsProvider);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: AppToolBar(
        title: _l10n.uwearisPoints,
        actions: [
          if (points.value case final summary? when summary.costs.isNotEmpty)
            ActionDiscButton(
              tooltip: _l10n.pointsCostsTitle,
              icon: const Icon(
                Icons.info_outline,
                size: 26,
                color: AppColors.icon,
              ),
              onPressed: () => _showCosts(summary),
            ),
        ],
      ),
      bottomNavigationBar: BottomActionButton(
        label: _actionLabel,
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
            _buildBalanceCard(points),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _openActivity,
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
            RadioGroup<int>(
              groupValue: _selectedIndex,
              onChanged: (i) {
                if (i != null) setState(() => _selectedIndex = i);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimens.sectionSpacing),
                  SectionHeader(
                    title: _l10n.pointsPlusSectionTitle,
                    subtitle: _l10n.pointsPlusSectionSubtitle,
                  ),
                  const SizedBox(height: AppDimens.cardSpacing),
                  _buildPlanOption(_plans.indexOf(_plus)),
                  const SizedBox(height: AppDimens.titleGap),
                  SectionHeader(
                    title: _l10n.pointsAddTitle,
                    subtitle: _l10n.pointsAddSubtitle,
                  ),
                  for (final pack in _packs) ...[
                    const SizedBox(height: AppDimens.cardSpacing),
                    _buildPlanOption(_plans.indexOf(pack)),
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

  Widget _buildBalanceCard(AsyncValue<PointsSummary> points) {
    final summary = points.value;
    final secondary = AppTextStyle.regular14.copyWith(
      color: AppColors.textSecondary,
    );
    final Widget amount;
    if (summary != null) {
      amount = _buildPointsAmount(summary.balance, fontSize: 40);
    } else if (points.hasError) {
      amount = ErrorStateWidget(
        error: points.error!,
        onRetry: () => ref.read(pointsProvider.notifier).refresh(),
      );
    } else {
      amount = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: AppSpinner(),
      );
    }
    final expiresAt = summary?.subscriptionExpiresAt;
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
          amount,
          if (summary != null) ...[
            const SizedBox(height: 8),
            Text(
              _l10n.pointsDailyGrantHint(
                summary.dailyGrant,
                clockLabel(summary.nextClaimAt),
              ),
              style: secondary,
            ),
            if (summary.subscriptionActive && expiresAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _l10n.pointsPlusActiveUntil(
                  DateFormat.yMMMd(_l10n.localeName).format(expiresAt),
                ),
                style: AppTextStyle.bold14.copyWith(color: AppColors.accent),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Every [PointsAction] belongs to exactly one group.
  static final _costGroups =
      <(String Function(AppLocalizations), List<PointsAction>)>[
        (
          (l) => l.pointsCostsGroupImages,
          [PointsAction.tryOn, PointsAction.flatLay, PointsAction.baseModel],
        ),
        (
          (l) => l.pointsCostsGroupWardrobe,
          [
            PointsAction.garmentAnalysis,
            PointsAction.closetAnalysis,
            PointsAction.outfitAdvice,
          ],
        ),
        (
          (l) => l.pointsCostsGroupMatchTrips,
          [
            PointsAction.matchLookReference,
            PointsAction.matchLookMatch,
            PointsAction.tripOutfits,
            PointsAction.tripPacking,
          ],
        ),
      ];

  void _showCosts(PointsSummary summary) {
    final groups = <(String, List<(PointsAction, int)>)>[];
    for (final (label, actions) in _costGroups) {
      final rows = [
        for (final action in actions)
          if (summary.costOf(action) case final cost?) (action, cost),
      ];
      if (rows.isNotEmpty) groups.add((label(_l10n), rows));
    }
    pageSheet<void>(
      context,
      title: _l10n.pointsCostsTitle,
      builder: (_) => ListView(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
        children: [
          Text(
            _l10n.pointsCostsSubtitle,
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          for (final (i, (label, rows)) in groups.indexed) ...[
            if (i == 0)
              const SizedBox(height: AppDimens.sectionSpacing)
            else
              const AppDivider(spacing: AppDimens.sectionSpacing),
            FieldLabel(label),
            for (final (action, cost) in rows)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        action.localizedLabel(_l10n),
                        style: AppTextStyle.regular16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    PointsAmount(cost, style: AppTextStyle.bold16),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointsAmount(
    int points, {
    required double fontSize,
    String? unit,
  }) {
    return Text.rich(
      TextSpan(
        style: AppTextStyle.bold24.copyWith(fontSize: fontSize, height: 1.2),
        children: [
          PointsAmount.span(context, points),
          if (unit != null)
            TextSpan(
              text: ' $unit',
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.accent : AppColors.accentTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTextStyle.bold12.copyWith(
          color: filled ? AppColors.textOnPrimary : AppColors.accent,
        ),
      ),
    );
  }

  Widget _buildPlanOption(int index) {
    final plan = _plans[index];
    final selected = index == _selectedIndex;
    final secondary = AppTextStyle.regular14.copyWith(
      color: AppColors.textSecondary,
    );
    final badge = plan.badge?.call(_l10n);
    final bonus = plan.isSubscription ? 0 : _bonusPercent(plan);

    final details = plan.isSubscription
        ? [
            Text(plan.name(_l10n), style: AppTextStyle.bold18),
            const SizedBox(height: 4),
            _buildPointsAmount(
              plan.points,
              fontSize: 26,
              unit: _l10n.pointsPerDay,
            ),
            const SizedBox(height: 4),
            Text(_l10n.pointsPlusDetail, style: secondary),
          ]
        : [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(plan.name(_l10n), style: secondary),
                if (badge != null) _buildBadge(badge, filled: selected),
              ],
            ),
            const SizedBox(height: 2),
            _buildPointsAmount(plan.points, fontSize: 26),
            if (bonus > 0) ...[
              const SizedBox(height: 2),
              Text(
                _l10n.pointsBonus(bonus),
                style: AppTextStyle.bold12.copyWith(color: AppColors.accent),
              ),
            ],
          ];

    return Material(
      color: selected ? AppColors.accentTint : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        side: BorderSide(
          color: selected
              ? AppColors.accent
              : plan.isSubscription
              ? AppColors.accentOutline
              : AppColors.borderSubtle,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: plan.isSubscription && !selected
              ? AppColors.uwearisGradient
              : null,
        ),
        child: InkWell(
          onTap: () => setState(() => _selectedIndex = index),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 18, 14),
            child: Row(
              children: [
                Radio<int>(value: index, activeColor: AppColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: details,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _l10n.pointsPrice(plan.priceNtd),
                      style: AppTextStyle.semibold16,
                    ),
                    if (plan.isSubscription)
                      Text(_l10n.pointsPerMonth, style: secondary),
                  ],
                ),
              ],
            ),
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

  void _openActivity() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PointsActivityPage()),
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
