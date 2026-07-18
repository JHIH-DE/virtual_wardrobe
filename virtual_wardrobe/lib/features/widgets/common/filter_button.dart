import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
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
  final String emptyMessage;

  FilterGroup({
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    String? emptyMessage,
  }) : emptyMessage = emptyMessage ?? 'No ${label.toLowerCase()} available';
}

/// Filter icon button that opens a dropdown menu built from [groups],
/// anchored directly under the button, with a full-screen dark scrim behind
/// it so the panel reads as highlighted above the rest of the page.
class FilterButton extends StatefulWidget {
  final bool isFiltered;
  final List<FilterGroup> groups;

  const FilterButton({
    super.key,
    required this.isFiltered,
    required this.groups,
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

  @override
  State<FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends State<FilterButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool get _isOpen => _overlayEntry != null;

  void _toggle() {
    if (_isOpen) {
      _close();
    } else {
      _open();
    }
  }

  void _open() {
    final entry = OverlayEntry(builder: _buildOverlayContent);
    _overlayEntry = entry;
    Overlay.of(context).insert(entry);
    setState(() {});
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  // A single Stack owns both layers, so paint order (scrim first, panel on
  // top) is just widget order — no dependence on how/where Overlay entries
  // from other widgets happen to be stacked.
  Widget _buildOverlayContent(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _close,
            child: Container(color: AppColors.scrimBackdrop),
          ),
        ),
        CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 8),
          child: _buildPanel(),
        ),
      ],
    );
  }

  Widget _buildPanel() {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: StatefulBuilder(
        builder: (ctx, setMenuState) {
          return Container(
            width: 262,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < widget.groups.length; i++) ...[
                  Text(widget.groups[i].label, style: AppTextStyle.bold16),
                  const SizedBox(height: 10),
                  widget.groups[i].options.isEmpty
                      ? Text(
                          widget.groups[i].emptyMessage,
                          style: AppTextStyle.regular14.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.groups[i].options.map((opt) {
                            final selected = widget.groups[i]
                                .selected()
                                .contains(opt);
                            return SelectableChip(
                              label: opt,
                              selected: selected,
                              onTap: () {
                                widget.groups[i].onToggle(opt);
                                setMenuState(() {});
                              },
                            );
                          }).toList(),
                        ),
                  if (i != widget.groups.length - 1) const SizedBox(height: 20),
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(icon: const Icon(Icons.filter_list), onPressed: _toggle),
          if (widget.isFiltered)
            Positioned(
              right: 8,
              top: 8,
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
      ),
    );
  }
}
