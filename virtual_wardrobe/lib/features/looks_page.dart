import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../app/theme/app_dimens.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../data/look.dart';
import 'looks_details_page.dart';
import 'manual_try_on_page.dart';
import 'widgets/look_card.dart';
import 'widgets/page_app_bar.dart';
import 'widgets/bottom_action_button.dart';

class LooksPage extends ConsumerStatefulWidget {
  const LooksPage({super.key});

  @override
  ConsumerState<LooksPage> createState() => _LooksPageState();
}

class _LooksPageState extends ConsumerState<LooksPage> {
  static const List<String> _seasons = ['All', 'Spring', 'Summer', 'Autumn', 'Winter'];
  static const List<String> _styles = ['All', 'Minimal', 'Street', 'Classic', 'Sporty'];

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
    });
  }

  bool get _isFiltered => !_selectedSeasons.contains('All') || !_selectedStyle.contains('All');

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text('Season', style: AppTextStyle.bold16),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _seasons.map((s) {
                    final selected = _selectedSeasons.contains(s);
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() {});
                        setState(() {
                          if (s == 'All') {
                            _selectedSeasons = {'All'};
                          } else {
                            _selectedSeasons.remove('All');
                            if (_selectedSeasons.contains(s)) {
                              _selectedSeasons.remove(s);
                              if (_selectedSeasons.isEmpty) _selectedSeasons = {'All'};
                            } else {
                              _selectedSeasons.add(s);
                            }
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          s,
                          style: AppTextStyle.semibold14.copyWith(
                            color: selected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
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
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() {});
                        setState(() {
                          if (s == 'All') {
                            _selectedStyle = {'All'};
                          } else {
                            _selectedStyle.remove('All');
                            if (_selectedStyle.contains(s)) {
                              _selectedStyle.remove(s);
                              if (_selectedStyle.isEmpty) _selectedStyle = {'All'};
                            } else {
                              _selectedStyle.add(s);
                            }
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? AppColors.primary : AppColors.border,
                          ),
                        ),
                        child: Text(
                          s,
                          style: AppTextStyle.semibold14.copyWith(
                            color: selected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Look> _filtered(List<Look> all) {
    return all.where((l) {
      final okSeason = _selectedSeasons.contains('All') ||
          l.seasons.any((s) => _selectedSeasons.any((sel) => sel.toLowerCase() == s.toLowerCase()));
      final okStyle = _selectedStyle.contains('All') ||
          l.style.any((s) => _selectedStyle.any((sel) => sel.toLowerCase() == s.toLowerCase()));
      return okSeason && okStyle;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final looksAsync = ref.watch(looksProvider);

    return Scaffold(
        backgroundColor: AppColors.defaultBackground,
        appBar: PageAppBar(
          title: 'Looks',
          backgroundColor: AppColors.surface,
          actions: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: _openFilterSheet,
                ),
                if (_isFiltered)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        body: looksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) {
            if (e is AuthExpiredException) return const SizedBox.shrink();
            return Center(child: Text(e.toString(), style: AppTextStyle.regular14));
          },
          data: (all) {
            final looks = _filtered(all);
            return RefreshIndicator(
              onRefresh: () => ref.read(looksProvider.notifier).refresh(),
              color: AppColors.primary,
              child: _buildListContent(looks),
            );
          },
        ),
        bottomNavigationBar: BottomActionButton(
          label: 'Create new look',
          trailing: const Icon(Icons.add, size: 20),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualTryOnPage())),
        ),
    );
  }

Widget _buildListContent(List<Look> looks) {
    if (looks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Text(
            'No looks yet.',
            style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: AppDimens.lookCardWidth / AppDimens.lookCardHeight,
      ),
      itemCount: looks.length,
      itemBuilder: (context, index) {
        final look = looks[index];
        return LookCard(
          look: look,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LooksDetailsPage(look: look),
            ),
          ),
        );
      },
    );
  }

}
