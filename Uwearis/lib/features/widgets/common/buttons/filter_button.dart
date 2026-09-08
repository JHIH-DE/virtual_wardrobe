import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimens.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../app_divider.dart';
import '../fields/selectable_chip.dart';
import '../overlays/picker_sheet.dart';

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

  /// When true, [FilterButton.allOption] is pulled out of the chip row and
  /// rendered as a compact toggle beside the group's title (`Season (All)`).
  /// Set by [FilterGroup.toggleAll]; a plain multi-select group (e.g. an
  /// outfit's tag editor) leaves it false and just lists every option.
  final bool headerAll;

  FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.emptyMessage,
    this.headerAll = false,
  });

  /// The common case: an 'All'-sentinel multi-select group. [selected] reads
  /// the current set, [onChanged] receives the next set (call `setState`
  /// there) — the [FilterButton.toggleWithAll] plumbing is handled here so
  /// each call site doesn't repeat it (and can't mismatch the set it reads
  /// vs. the set it writes).
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

  /// The 'show everything / no filter' sentinel value carried in a
  /// [FilterGroup.toggleAll] group's selected set and option list.
  static const String allOption = 'All';

  /// Toggle helper for the common 'All' sentinel pattern: selecting 'All'
  /// clears the rest, selecting anything else clears 'All', and clearing
  /// the last non-'All' selection falls back to 'All'.
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

  void _openFilterSheet(BuildContext context) =>
      showChipGroupsSheet<void>(context, groups: groups);

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          // Zero padding + a toolbar-slot square so the hit target matches
          // AppToolBar's back button and the "⋮" menu (IconButton's default
          // 8px padding would otherwise clamp the glyph and shrink the area).
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: AppDimens.toolbarHeight,
            minHeight: AppDimens.toolbarHeight,
          ),
          icon: const Icon(Icons.filter_list),
          onPressed: () => _openFilterSheet(context),
        ),
        if (isFiltered)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              width: 8,
              height: 8,
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

/// Opens the app's standard "pick multiple values from grouped chips" bottom
/// sheet — a drag handle, then per [FilterGroup] a title (with the "All"
/// chip beside it when [FilterGroup.headerAll]), a divider, and a justified
/// row of option chips.
///
/// Used by [FilterButton] (applies live, no button) and by "edit tags"
/// style sheets — pass [confirmLabel] to add a trailing full-width button
/// that pops [confirmResult]; without it the sheet has no button and the
/// caller reacts to the [FilterGroup]s' own `onToggle` side effects.
Future<T?> showChipGroupsSheet<T>(
  BuildContext context, {
  required List<FilterGroup> groups,
  String? confirmLabel,
  T Function()? confirmResult,
}) {
  final l10n = AppLocalizations.of(context);
  return showPickerSheet<T>(
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
            if (confirmLabel != null) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(sheetContext, confirmResult?.call()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    confirmLabel,
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// One group inside [showChipGroupsSheet]: `label` (+ the "All" chip beside
/// it for a [FilterGroup.headerAll] group) → divider → justified chips (or
/// the empty-state text).
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
              // The same pill as the option chips, just lifted up beside the
              // title — "All" reads as this group's reset, not a peer option.
              SelectableChip(
                label: l10n.filterAll,
                selected: group.selected().contains(FilterButton.allOption),
                selectedColor: AppColors.accentTint,
                selectedTextColor: AppColors.accent,
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

/// Lays out chip options left-to-right, justifying a row edge-to-edge
/// (`spaceBetween`) once its chips already fill most of the width, and
/// leaving a sparser row (or a lone chip) left-aligned with normal fixed
/// spacing — so a single near-full row (e.g. `Color: White Black Navy Grey
/// Blue`) spreads out the same way a wrapped row does, and a trailing
/// `T-shirt` on its own line doesn't get stretched across the sheet.
///
/// Real chip sizes vary with font rendering in ways a predicted width can't
/// match exactly, so this measures for real: pass 1 renders a plain [Wrap]
/// with a [GlobalKey] per chip and lets Flutter's own layout decide
/// wrapping; a post-frame callback reads back each chip's real position to
/// group them into rows, then pass 2 re-renders each row as a `spaceBetween`
/// or a left-aligned [Row] per the fill rule above. A row [_measure] grouped
/// together is by definition <= the available width, so `spaceBetween` on it
/// can never overflow.
///
/// Options are also reordered widest-first so wide chips settle earlier and
/// rows pack more evenly — this uses a [TextPainter] width estimate, which
/// is only reliable for relative ordering / a rough fill ratio, not for
/// exact layout decisions.
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

  /// A row whose chips' natural width is at least this fraction of the
  /// available width gets justified edge-to-edge; below it the row stays
  /// left-aligned (stretching just 2–3 short chips across the sheet looks
  /// worse than a small right-hand gap).
  static const _justifyFillRatio = 0.62;

  late List<String> _orderedOptions;
  final Map<String, GlobalKey> _keys = {};
  List<List<String>>? _rows;

  /// The width handed to this widget by its parent (the sheet content
  /// width), captured from the [LayoutBuilder] in [build] and read when
  /// deciding whether to justify each row.
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
      selectedColor: AppColors.accentTint,
      selectedTextColor: AppColors.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () {
        widget.onToggle(opt);
        widget.onChanged();
      },
    );
  }

  /// Whether [rowOptions] fill enough of [_availableWidth] to be justified
  /// edge-to-edge rather than left-aligned. Uses the [_estimateWidth]
  /// estimate — fine for a rough ratio.
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
