import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/look_service.dart';
import '../core/utils/debug_log.dart';
import '../data/look.dart';
import 'looks_details_page.dart';
import 'widgets/looks_grid_view.dart';
import 'widgets/page_app_bar.dart';

class GarmentLooksPage extends StatefulWidget {
  final int garmentId;

  const GarmentLooksPage({super.key, required this.garmentId});

  @override
  State<GarmentLooksPage> createState() => _GarmentLooksPageState();
}

class _GarmentLooksPageState extends State<GarmentLooksPage> {
  static const List<String> _seasons = ['All', 'Spring', 'Summer', 'Autumn', 'Winter'];
  static const List<String> _styles = ['All', 'Minimal', 'Street', 'Classic', 'Sporty'];

  Set<String> _selectedSeasons = {'All'};
  Set<String> _selectedStyle = {'All'};

  List<Look> _allLooks = [];
  bool _loading = true;
  String? _error;

  bool get _isFiltered =>
      !_selectedSeasons.contains('All') || !_selectedStyle.contains('All');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      debugLog('getLooksByGarments garmentId=${widget.garmentId}');
      final result = await LookService().getLooksByGarments([widget.garmentId]);
      final saved = result.where((l) => l.isSaved).toList();
      debugLog('API returned ${result.length} looks, ${saved.length} isSaved=true');
      for (final l in result) {
        debugLog('  look id=${l.id} isSaved=${l.isSaved} imageUrl=${l.imageUrl}');
      }
      if (!mounted) return;
      setState(() => _allLooks = saved);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Look> _filtered() {
    return _allLooks.where((l) {
      final okSeason = _selectedSeasons.contains('All') ||
          l.seasons.any((s) => _selectedSeasons.any((sel) => sel.toLowerCase() == s.toLowerCase()));
      final okStyle = _selectedStyle.contains('All') ||
          l.style.any((s) => _selectedStyle.any((sel) => sel.toLowerCase() == s.toLowerCase()));
      return okSeason && okStyle;
    }).toList();
  }

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
                      child: _filterChip(s, selected),
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
                      child: _filterChip(s, selected),
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

  Widget _filterChip(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : AppColors.border),
      ),
      child: Text(
        label,
        style: AppTextStyle.semibold14.copyWith(
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: 'Used in Looks',
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  )
                : LooksGridView(
                    looks: _filtered(),
                    onRefresh: _load,
                    onTap: (look) => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LooksDetailsPage(look: look)),
                    ),
                    emptyMessage: 'This item has not been used in any looks yet.',
                  ),
      ),
    );
  }
}
