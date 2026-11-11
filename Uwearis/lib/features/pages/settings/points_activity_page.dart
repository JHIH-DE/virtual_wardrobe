import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import 'package:lucide_icons_flutter/lucide_icons_300.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/services/points_service.dart';
import '../../../core/utils/debug_log.dart';
import '../../../data/points.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../l10n/points_localization.dart';
import '../../widgets/common/app_divider.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/cards/app_card_shell.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/overlays/empty_state_placeholder.dart';
import '../../widgets/common/overlays/error_state_widget.dart';

/// `GET /points/transactions`, newest first, loading further pages as the
/// list nears its end.
class PointsActivityPage extends StatefulWidget {
  const PointsActivityPage({super.key});

  @override
  State<PointsActivityPage> createState() => _PointsActivityPageState();
}

class _PointsActivityPageState extends State<PointsActivityPage> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final List<PointsTransaction> _items = [];
  int _loadedPage = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 400) _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await PointsService().getTransactions(
        page: _loadedPage + 1,
        size: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _loadedPage = page.page;
        _hasMore = page.hasMore && page.items.isNotEmpty;
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('PointsActivityPage: load failed: $e');
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() {
      _items.clear();
      _loadedPage = 0;
      _hasMore = true;
    });
    await _loadNextPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: AppToolBar(title: _l10n.pointsActivityTitle),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final error = _error;
    if (_items.isEmpty) {
      if (error != null) {
        return Center(
          child: ErrorStateWidget(error: error, onRetry: _loadNextPage),
        );
      }
      if (_loading) return const Center(child: AppSpinner());
      return EmptyStatePlaceholder(
        icon: LucideIcons300.coins,
        message: _l10n.pointsActivityEmpty,
        fillAvailableSpace: true,
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          AppCardShell(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (final (i, item) in _items.indexed) ...[
                  if (i > 0) const AppDivider(),
                  _TransactionRow(item: item),
                ],
              ],
            ),
          ),
          if (_hasMore || error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppDimens.cardSpacing),
              child: error != null
                  ? ErrorStateWidget(error: error, onRetry: _loadNextPage)
                  : const Center(child: AppSpinner(size: 24, strokeWidth: 3)),
            ),
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final PointsTransaction item;

  const _TransactionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numbers = NumberFormat.decimalPattern(l10n.localeName);
    final delta = item.delta;
    final deltaText = delta > 0
        ? '+${numbers.format(delta)}'
        : numbers.format(delta);
    final secondary = AppTextStyle.regular14.copyWith(
      color: AppColors.textSecondary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.localizedTitle(l10n), style: AppTextStyle.medium16),
                const SizedBox(height: 2),
                Text(
                  DateFormat.yMMMd(
                    l10n.localeName,
                  ).add_Hm().format(item.createdAt),
                  style: secondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                deltaText,
                style: AppTextStyle.semibold16.copyWith(
                  color: delta > 0 ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.pointsBalanceAfter(numbers.format(item.balanceAfter)),
                style: secondary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
