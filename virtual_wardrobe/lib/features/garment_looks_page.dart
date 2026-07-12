import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/look_service.dart';
import '../core/utils/debug_log.dart';
import '../data/look.dart';
import 'looks_details_page.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/filter_icon_button.dart';
import 'widgets/common/filter_sheet_scaffold.dart';
import 'widgets/common/looks_grid_view.dart';
import 'widgets/common/page_app_bar.dart';
import 'widgets/common/selectable_chip.dart';

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
                            if (_selectedSeasons.isEmpty) _selectedSeasons = {'All'};
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
                            if (_selectedStyle.isEmpty) _selectedStyle = {'All'};
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: 'Used in Looks',
        actions: [
          FilterIconButton(
            isFiltered: _isFiltered,
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ErrorStateWidget(error: _error!, onRetry: _load)
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
