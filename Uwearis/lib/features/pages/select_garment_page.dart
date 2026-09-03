import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/garment.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/garment_color_type_filter.dart';
import '../widgets/garment/garment_card.dart';
import '../widgets/garment/garment_grid.dart';
import '../widgets/garment/none_garment_card.dart';

/// Full-page grid picker for a single outfit slot (Top/Bottom/Shoes/etc) or
/// for an accessory slot. Tapping an item — or the "None" tile — immediately
/// pops back with the result; there's no separate confirm step.
class SelectGarmentPage extends StatefulWidget {
  final String title;

  /// The slot's category. Null = don't pre-filter by category (the caller
  /// already passed the exact candidate list — e.g. the Add Outfit accessory
  /// picker, which mixes accessories and socks).
  final GarmentCategory? category;

  final List<Garment> garments;
  final Garment? selected;

  /// Whether the "None" tile (clear this slot) shows in the grid — only
  /// makes sense for optional slots (e.g. Mid Layer, Outerwear, accessories);
  /// required slots are cleared via the slot card's own "x" affordance
  /// instead.
  final bool showNoneOption;

  /// Match a Look's AI ranking for this slot, #1 first — up to 4 ids.
  /// #1 never gets a badge here (it's already the auto-filled selection,
  /// shown via the normal selected checkmark instead); #2-#4 get a small
  /// "✦ #N" marker so the user can still see the AI's other suggestions
  /// without being limited to them.
  final List<int> rankedGarmentIds;

  const SelectGarmentPage({
    super.key,
    required this.title,
    this.category,
    required this.garments,
    this.selected,
    this.showNoneOption = false,
    this.rankedGarmentIds = const [],
  });

  @override
  State<SelectGarmentPage> createState() => _SelectGarmentPageState();
}

class _SelectGarmentPageState extends State<SelectGarmentPage> {
  final _filter = GarmentColorTypeFilter();

  List<Garment> get _byCategory => widget.category == null
      ? widget.garments
      : widget.garments.where((g) => g.category == widget.category).toList();

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: widget.title,
      actions: [
        _filter.buildButton(
          AppLocalizations.of(context),
          _byCategory,
          onChanged: () => setState(() {}),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _filter.apply(_byCategory);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: GarmentGrid(
        itemCount: items.length + (widget.showNoneOption ? 1 : 0),
        itemBuilder: (context, i) {
          if (widget.showNoneOption && i == 0) {
            return NoneGarmentCard(
              isSelected: widget.selected == null,
              label: l10n.noneLabel,
              onTap: () =>
                  Navigator.pop(context, const SelectGarmentResult(null)),
            );
          }
          final g = items[widget.showNoneOption ? i - 1 : i];
          final rank = g.id == null
              ? -1
              : widget.rankedGarmentIds.indexOf(g.id!);
          return Stack(
            children: [
              GarmentCard(
                garment: g,
                isSelected:
                    widget.selected?.id != null && widget.selected!.id == g.id,
                onTap: () => Navigator.pop(context, SelectGarmentResult(g)),
              ),
              // rank 0 is AI's #1 pick — already reflected by the normal
              // selected checkmark above, so it doesn't also get a badge.
              if (rank > 0) _buildAiRankBadge(rank + 1),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAiRankBadge(int rank) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 10, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              '#$rank',
              style: AppTextStyle.bold12.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
