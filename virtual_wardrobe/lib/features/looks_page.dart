import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../data/look.dart';
import 'looks_details_page.dart';
import 'manual_try_on_page.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/filter_icon_button.dart';
import 'widgets/common/filter_sheet_scaffold.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/common/looks_grid_view.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/common/selectable_chip.dart';

class LooksPage extends ConsumerStatefulWidget {
  const LooksPage({super.key});

  @override
  ConsumerState<LooksPage> createState() => _LooksPageState();
}

class _LooksPageState extends ConsumerState<LooksPage> {
  bool _openingTryOn = false;

  static const List<String> _seasons = [
    'All',
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];
  static const List<String> _styles = [
    'All',
    'Minimal',
    'Street',
    'Classic',
    'Sporty',
  ];

  Set<String> _selectedSeasons = {'All'};
  Set<String> _selectedStyle = {'All'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(looksProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
      ref.read(looksProvider.notifier).refreshIfNeeded();
    });
  }

  bool get _isFiltered =>
      !_selectedSeasons.contains('All') || !_selectedStyle.contains('All');

  void _openFilterSheet() {
    showAppFilterSheet(
      context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return FilterSheetContent(
            children: [
              Text('Season', style: AppTextStyle.bold16),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _seasons.map((s) {
                  final selected = _selectedSeasons.contains(s);
                  return SelectableChip(
                    label: s,
                    selected: selected,
                    onTap: () {
                      setSheetState(() {});
                      setState(() {
                        if (s == 'All') {
                          _selectedSeasons = {'All'};
                        } else {
                          _selectedSeasons.remove('All');
                          if (_selectedSeasons.contains(s)) {
                            _selectedSeasons.remove(s);
                            if (_selectedSeasons.isEmpty) {
                              _selectedSeasons = {'All'};
                            }
                          } else {
                            _selectedSeasons.add(s);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('Style', style: AppTextStyle.bold16),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _styles.map((s) {
                  final selected = _selectedStyle.contains(s);
                  return SelectableChip(
                    label: s,
                    selected: selected,
                    onTap: () {
                      setSheetState(() {});
                      setState(() {
                        if (s == 'All') {
                          _selectedStyle = {'All'};
                        } else {
                          _selectedStyle.remove('All');
                          if (_selectedStyle.contains(s)) {
                            _selectedStyle.remove(s);
                            if (_selectedStyle.isEmpty) {
                              _selectedStyle = {'All'};
                            }
                          } else {
                            _selectedStyle.add(s);
                          }
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Look> _filtered(List<Look> all) {
    return all.where((l) {
      final okSeason =
          _selectedSeasons.contains('All') ||
          l.seasons.any(
            (s) => _selectedSeasons.any(
              (sel) => sel.toLowerCase() == s.toLowerCase(),
            ),
          );
      final okStyle =
          _selectedStyle.contains('All') ||
          l.style.any(
            (s) => _selectedStyle.any(
              (sel) => sel.toLowerCase() == s.toLowerCase(),
            ),
          );
      return okSeason && okStyle;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final looksAsync = ref.watch(looksProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.defaultBackground,
          appBar: PageAppBar(
            title: 'Looks',
            backgroundColor: AppColors.surface,
            onBack: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
            actions: [
              FilterIconButton(
                isFiltered: _isFiltered,
                onPressed: _openFilterSheet,
              ),
              IconButton(
                icon: Image.asset(
                  'assets/images/plus.png',
                  height: AppDimens.iconMediumSize,
                ),
                onPressed: () => _handleOpenManualTryOn(context),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: looksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
              error: e,
              onRetry: () => ref.read(looksProvider.notifier).refresh(),
            ),
            data: (all) {
              final looks = _filtered(all);
              return LooksGridView(
                looks: looks,
                onRefresh: () => ref.read(looksProvider.notifier).refresh(),
                onTap: (look) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LooksDetailsPage(look: look),
                  ),
                ),
              );
            },
          ),
        ),
        if (_openingTryOn)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Garments...'),
          ),
      ],
    );
  }

  Future<void> _handleOpenManualTryOn(BuildContext context) async {
    setState(() => _openingTryOn = true);
    try {
      final garments = await ManualTryOnPage.preload();
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualTryOnPage(preloadedGarments: garments),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load garments')),
        );
      }
    }
  }
}
