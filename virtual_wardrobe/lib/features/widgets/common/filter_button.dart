import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'selectable_chip.dart';

/// One labeled row of selectable chips inside a [FilterButton]'s sheet.
/// The group owns its own selection state and toggle logic, so callers
/// with different selection semantics (e.g. an 'All' sentinel vs plain
/// multi-select) can reuse the same sheet chrome.
class FilterGroup {
  final String label;
  final List<String> options;
  final Set<String> Function() selected;
  final void Function(String option) onToggle;
  final String? emptyMessage;

  FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.emptyMessage,
  });
}

/// Filter icon button that opens a bottom sheet built from [groups].
class FilterButton extends StatelessWidget {
  final bool isFiltered;
  final List<FilterGroup> groups;
  final int count;

  const FilterButton({
    super.key,
    required this.isFiltered,
    required this.groups,
    required this.count,
  });

  /// Toggle helper for the common 'All' sentinel pattern: selecting 'All'
  /// clears the rest, selecting anything else clears 'All', and clearing
  /// the last non-'All' selection falls back to 'All'.
  static Set<String> toggleWithAll(Set<String> current, String value) {
    if (value == 'All') return {'All'};
    final next = Set<String>.from(current)..remove('All');
    if (next.contains(value)) {
      next.remove(value);
      if (next.isEmpty) next.add('All');
    } else {
      next.add(value);
    }
    return next;
  }

  void _openFilterSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                      color: AppColors.overlaySubtle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < groups.length; i++) ...[
                  Text(groups[i].label, style: AppTextStyle.bold16),
                  Divider(
                      height: 16,
                      thickness: 1,
                      color: AppColors.dividerSubtle,
                  ),
                  const SizedBox(height: 12),
                  groups[i].options.isEmpty
                      ? Text(
                          groups[i].emptyMessage ??
                              l10n.noOptionsAvailable(
                                groups[i].label.toLowerCase(),
                              ),
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      : _JustifiedChips(
                          options: groups[i].options,
                          selected: groups[i].selected,
                          onToggle: groups[i].onToggle,
                          onChanged: () => setSheetState(() {}),
                        ),
                  if (i != groups.length - 1) const SizedBox(height: 32),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () => _openFilterSheet(context),
        ),
        if (isFiltered)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: AppTextStyle.bold10.copyWith(
                    color: AppColors.textOnPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Lays out chip options left-to-right, filling each full row edge-to-edge
/// (dynamic spacing) rather than leaving a ragged left-aligned gap, while
/// keeping the final partial row left-aligned with normal fixed spacing.
///
/// Real chip sizes vary with font rendering in ways a predicted width can't
/// match exactly, so this measures for real: pass 1 renders a plain [Wrap]
/// with a [GlobalKey] per chip and lets Flutter's own layout decide
/// wrapping; a post-frame callback reads back each chip's real position to
/// group them into rows, then pass 2 re-renders each full row as a
/// `spaceBetween` [Row] (edge-to-edge) and the last row as a normal
/// left-aligned [Row].
///
/// Options are also reordered (pinned 'All' first, then widest-first) so
/// wide chips settle earlier and rows pack more evenly — this uses a
/// [TextPainter] width estimate, which is only reliable for relative
/// ordering, not for exact layout decisions.
class _JustifiedChips extends StatefulWidget {
  final List<String> options;
  final Set<String> Function() selected;
  final void Function(String option) onToggle;
  final VoidCallback onChanged;

  const _JustifiedChips({
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  State<_JustifiedChips> createState() => _JustifiedChipsState();
}

class _JustifiedChipsState extends State<_JustifiedChips> {
  static const _spacing = 10.0;
  static const _runSpacing = 8.0;

  late List<String> _orderedOptions;
  final Map<String, GlobalKey> _keys = {};
  List<List<String>>? _rows;

  @override
  void initState() {
    super.initState();
    _prepareOrder();
  }

  @override
  void didUpdateWidget(covariant _JustifiedChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameOptions(oldWidget.options, widget.options)) {
      _rows = null;
      _prepareOrder();
    }
  }

  bool _sameOptions(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _prepareOrder() {
    _orderedOptions = _orderOptions(widget.options);
    _keys
      ..clear()
      ..addEntries(_orderedOptions.map((o) => MapEntry(o, GlobalKey())));
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  double _estimateWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: AppTextStyle.semibold14),
      textDirection: TextDirection.ltr,
    )..layout();
    // + chip horizontal padding (12 * 2) + border (1 * 2).
    return painter.width + 26;
  }

  List<String> _orderOptions(List<String> options) {
    final all = options.where((o) => o == 'All').toList();
    final rest = options.where((o) => o != 'All').toList()
      ..sort((a, b) => _estimateWidth(b).compareTo(_estimateWidth(a)));
    return [...all, ...rest];
  }

  void _measure() {
    if (!mounted) return;
    final rowY = <String, double>{};
    for (final opt in _orderedOptions) {
      final renderObject = _keys[opt]?.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) return;
      rowY[opt] = renderObject.localToGlobal(Offset.zero).dy;
    }

    final rows = <List<String>>[];
    double? currentY;
    for (final opt in _orderedOptions) {
      final y = rowY[opt]!;
      if (currentY == null || (y - currentY).abs() > 0.5) {
        rows.add([opt]);
        currentY = y;
      } else {
        rows.last.add(opt);
      }
    }

    if (!mounted) return;
    setState(() => _rows = rows);
  }

  Widget _buildChip(String opt) {
    final selected = widget.selected().contains(opt);
    return SelectableChip(
      key: _keys[opt],
      label: opt,
      selected: selected,
      selectedColor: AppColors.accentTint,
      selectedTextColor: AppColors.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () {
        widget.onToggle(opt);
        widget.onChanged();
      },
    );
  }

  Widget _buildRow(List<String> rowOptions, {required bool isLast}) {
    if (!isLast && rowOptions.length > 1) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: rowOptions.map(_buildChip).toList(),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rowOptions.length; i++) ...[
          if (i != 0) const SizedBox(width: _spacing),
          _buildChip(rowOptions[i]),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows == null) {
      return Wrap(
        spacing: _spacing,
        runSpacing: _runSpacing,
        children: _orderedOptions.map(_buildChip).toList(),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r != 0) const SizedBox(height: _runSpacing),
          _buildRow(rows[r], isLast: r == rows.length - 1),
        ],
      ],
    );
  }
}
