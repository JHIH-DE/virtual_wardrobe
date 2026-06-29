import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garments_service.dart';
import '../core/services/looks_service.dart';
import '../data/look.dart';
import '../data/garment.dart';
import '../app/theme/app_dimens.dart';
import 'manual_try_on_page.dart';
import 'widgets/garment_image.dart';
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

      final current = ref.read(looksProvider);
      if (current.hasError && current.error is AuthExpiredException) {
        AuthExpiredHandler.handle(context);
        return;
      }

      ref.read(looksProvider.notifier).refresh();

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
        body: SafeArea(
          top: false,
          child: SizedBox.expand(
            child: _buildManualTryOnTab(looksAsync),
          ),
        ),
        bottomNavigationBar: BottomActionButton(
          label: 'Create new look',
          trailing: const Icon(Icons.add, size: 20),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualTryOnPage())),
        ),
    );
  }

  Widget _buildManualTryOnTab(AsyncValue<List<Look>> looksAsync) {
    return Container(
      color: AppColors.defaultBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: looksAsync.when(
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
          ),
        ],
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
      padding: const EdgeInsets.only(top: 4, bottom: 20),
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
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => _lookDetailSheet(look),
          ),
        );
      },
    );
  }

  Widget _lookDetailSheet(Look look) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 0.65,
                      child: Image.network(look.imageUrl, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${look.seasons.join(', ')} • ${look.style.join(', ')}',
                        style: AppTextStyle.title18,
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Garment>>(
                        future: Future.wait(
                          look.garmentIds.map((id) => GarmentService().getGarment(id)),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
                          }
                          if (snapshot.hasError) {
                            return SizedBox(
                              height: 90,
                              child: Center(
                                child: Text(
                                  'Failed to load garments',
                                  style: AppTextStyle.regular12.copyWith(color: AppColors.error),
                                ),
                              ),
                            );
                          }
                          final garments = snapshot.data ?? [];
                          return SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: garments.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => _buildSmallGarmentItem(garments[i]),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmDelete(context, look);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Remove'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLook(int id) async {
    try {
      await LookService().deleteLook(id);
      ref.read(looksProvider.notifier).removeById(id);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Look look) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove look?', style: AppTextStyle.bold16),
        content: Text(
          'This look will be removed from your Looks.',
          style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) _deleteLook(look.id);
  }

  Widget _buildSmallGarmentItem(Garment garment) {
    final imageUrl = (garment.imageUrl != null && garment.imageUrl!.isNotEmpty)
        ? garment.imageUrl!
        : garment.uploadUrl;

    return InkWell(
      onTap: () => _showGarmentDetail(garment),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Expanded(
              child: GarmentImage(
                url: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: 11,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Text(
                garment.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyle.bold10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGarmentDetail(Garment garment) {
    final imageUrl = (garment.imageUrl != null && garment.imageUrl!.isNotEmpty)
        ? garment.imageUrl!
        : garment.uploadUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            AspectRatio(
              aspectRatio: 1,
              child: GarmentImage(
                url: imageUrl,
                fit: BoxFit.contain,
                borderRadius: 16,
              ),
            ),
            const SizedBox(height: 20),
            Text(garment.name, style: AppTextStyle.title22),
            const SizedBox(height: 8),
            Text(
              '${garment.category.label} • ${garment.subCategory}',
              style: AppTextStyle.semibold16.copyWith(color: AppColors.textSecondary),
            ),
            const Divider(height: 32),
            if (garment.brand != null) _infoRow('Brand', garment.brand!),
            if (garment.color != null) _infoRow('Color', garment.color!),
            if (garment.price != null) _infoRow('Price', '\$${garment.price!.toStringAsFixed(0)}'),
            if (garment.purchaseDate != null)
              _infoRow(
                'Purchased',
                '${garment.purchaseDate!.year}/${garment.purchaseDate!.month}/${garment.purchaseDate!.day}',
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary)),
          Text(value, style: AppTextStyle.bold14),
        ],
      ),
    );
  }
}
