import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../app_divider.dart';
import '../fields/selectable_chip.dart';
import '../overlays/picker_sheet.dart';
import 'action_disc_button.dart';

/// One labeled row of chips in [showChipGroupsSheet]. Owns its selection
/// logic, so an 'All'-sentinel group and a plain multi-select share the sheet.
class FilterGroup {
  final String label;
  final List<String> options;
  final Set<String> Function() selected;
  final void Function(String option) onToggle;
  final String? emptyMessage;

  /// Renders [FilterButton.allOption] beside the title instead of in the
  /// chip row. Set by [FilterGroup.toggleAll].
  final bool headerAll;

  FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.emptyMessage,
    this.headerAll = false,
  });

  /// An 'All'-sentinel multi-select group; [onChanged] receives the next set
  /// computed by [FilterButton.toggleWithAll].
  factory FilterGroup.toggleAll({
    required String label,
    required List<String> options,
    required Set<String> Function() selected,
    required void Function(Set<String> next) onChanged,
    String? emptyMessage,
  }) {
    return FilterGroup(
      label: label,
      options: options,
      selected: selected,
      onToggle: (option) =>
          onChanged(FilterButton.toggleWithAll(selected(), option)),
      emptyMessage: emptyMessage,
      headerAll: true,
    );
  }
}

/// Filter icon button that opens a bottom sheet built from [groups].
class FilterButton extends StatelessWidget {
  final bool isFiltered;
  final List<FilterGroup> groups;

  const FilterButton({
    super.key,
    required this.isFiltered,
    required this.groups,
  });

  /// The "no filter" sentinel in a [FilterGroup.toggleAll] group.
  static const String allOption = 'All';

  /// Selecting 'All' clears the rest, selecting anything else clears 'All',
  /// and clearing the last selection falls back to 'All'.
  static Set<String> toggleWithAll(Set<String> current, String value) {
    if (value == allOption) return {allOption};
    final next = Set<String>.from(current)..remove(allOption);
    if (next.contains(value)) {
      next.remove(value);
      if (next.isEmpty) next.add(allOption);
    } else {
      next.add(value);
    }
    return next;
  }

  static const double _dotSize = 6;

  static const double _dotOffset =
      (AppDimens.toolbarHeight - ActionDisc.iconSize) / 2 + 0.5 - _dotSize / 2;

  void _openFilterSheet(BuildContext context) =>
      showChipGroupsSheet(context, groups: groups);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ActionDiscButton(
          icon: const Icon(
            Icons.filter_list,
            size: ActionDisc.iconSize,
            color: AppColors.icon,
          ),
          onPressed: () => _openFilterSheet(context),
        ),
        if (isFiltered)
          Positioned(
            left: _dotOffset,
            top: _dotOffset,
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

/// Grouped-chip multi-select sheet. No confirm button: selection applies
/// through each [FilterGroup.onToggle] as the user taps.
Future<void> showChipGroupsSheet(
  BuildContext context, {
  required List<FilterGroup> groups,
}) {
  final l10n = AppLocalizations.of(context);
  return showPickerSheet<void>(
    context,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
    builder: (sheetContext) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        void rebuild() => setSheetState(() {});
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 20),
            for (var i = 0; i < groups.length; i++) ...[
              _ChipGroup(group: groups[i], l10n: l10n, onChanged: rebuild),
              if (i != groups.length - 1) const SizedBox(height: 32),
            ],
          ],
        );
      },
    ),
  );
}

class _ChipGroup extends StatelessWidget {
  final FilterGroup group;
  final AppLocalizations l10n;
  final VoidCallback onChanged;

  const _ChipGroup({
    required this.group,
    required this.l10n,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = group.headerAll
        ? group.options
              .where((o) => o != FilterButton.allOption)
              .toList(growable: false)
        : group.options;
    final showAllChip = group.headerAll && options.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(group.label, style: AppTextStyle.bold16),
            if (showAllChip) ...[
              const SizedBox(width: 10),
              SelectableChip(
                label: l10n.filterAll,
                selected: group.selected().contains(FilterButton.allOption),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onTap: () {
                  group.onToggle(FilterButton.allOption);
                  onChanged();
                },
              ),
            ],
          ],
        ),
        const AppDivider(
          topSpacing: 8,
          bottomSpacing: 12,
          color: AppColors.dividerSubtle,
        ),
        options.isEmpty
            ? Text(
                group.emptyMessage ??
                    l10n.noOptionsAvailable(group.label.toLowerCase()),
                style: AppTextStyle.regular14.copyWith(
                  color: AppColors.textSecondary,
                ),
              )
            : _JustifiedChips(
                options: options,
                selected: group.selected,
                onToggle: group.onToggle,
                onChanged: onChanged,
              ),
      ],
    );
  }
}

/// Justifies a row edge-to-edge once it's mostly full; sparser rows stay
/// left-aligned. Row breaks come from a real [Wrap] layout pass (measured
/// post-frame), not predicted widths, so a justified row can't overflow.
/// The [TextPainter] estimate is only used for widest-first ordering and the
/// rough fill ratio.
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

  static const _justifyFillRatio = 0.62;

  late List<String> _orderedOptions;
  final Map<String, GlobalKey> _keys = {};
  List<List<String>>? _rows;

  double _availableWidth = 0;

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
    return [...options]
      ..sort((a, b) => _estimateWidth(b).compareTo(_estimateWidth(a)));
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () {
        widget.onToggle(opt);
        widget.onChanged();
      },
    );
  }

  bool _shouldJustify(List<String> rowOptions) {
    if (rowOptions.length < 2 || _availableWidth <= 0) return false;
    final natural =
        rowOptions.fold<double>(0, (w, o) => w + _estimateWidth(o)) +
        (rowOptions.length - 1) * _spacing;
    return natural >= _availableWidth * _justifyFillRatio;
  }

  Widget _buildRow(List<String> rowOptions) {
    if (_shouldJustify(rowOptions)) {
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _availableWidth = constraints.maxWidth;
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
              _buildRow(rows[r]),
            ],
          ],
        );
      },
    );
  }
}
