import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/background_option.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/edge_fade_mask.dart';
import '../common/expand_arrow_icon.dart';
import '../common/field_label.dart';

/// The collapsible "BACKGROUND" section shared by Create Outfit
/// (`AddOutfitPage`) and Outfit Details' "+ New Version" picker
/// (`OutfitEditPage`): a tappable header showing the selected preset's name
/// while collapsed, expanding into a horizontally swipeable row of bundled
/// background photos. Tapping a photo selects it immediately — there are
/// only a handful of [BackgroundOption]s, so no separate picker page.
///
/// Meant to be laid out full-bleed: [horizontalInset] keeps the header and
/// the first/last card at the page's own inset while the photo row still
/// scrolls edge to edge.
class OutfitBackgroundSection extends StatefulWidget {
  final BackgroundOption selected;

  /// `null` disables selection (e.g. while an AI render is in flight).
  final ValueChanged<BackgroundOption>? onSelected;
  final double horizontalInset;

  const OutfitBackgroundSection({
    super.key,
    required this.selected,
    required this.onSelected,
    this.horizontalInset = 20,
  });

  @override
  State<OutfitBackgroundSection> createState() =>
      _OutfitBackgroundSectionState();
}

class _OutfitBackgroundSectionState extends State<OutfitBackgroundSection> {
  bool _expanded = false;
  final ScrollController _scrollController = ScrollController();

  static const _cardWidth = 120.0;
  // Matched to the "Your Outfit" row's card gap.
  static const _cardSpacing = AppDimens.cardSpacing;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalInset),
          child: _buildHeader(),
        ),
        AnimatedCrossFade(
          key: const ValueKey('backgroundSection'),
          duration: const Duration(milliseconds: 150),
          crossFadeState: _expanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Column(
            children: [
              const SizedBox(height: AppDimens.cardHeaderGap),
              _buildSelector(),
            ],
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Tappable "BACKGROUND" header — collapsed by default, with the selected
  /// preset's name as a grey summary while collapsed.
  Widget _buildHeader() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Row(
        children: [
          FieldLabel(
            AppLocalizations.of(context).backgroundLabel.toUpperCase(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _expanded
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      widget.selected.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.regular12.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          ExpandArrowIcon(expanded: _expanded),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    return SizedBox(
      height: 170,
      child: EdgeFadeMask(
        controller: _scrollController,
        child: ListView.separated(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: widget.horizontalInset),
          itemCount: BackgroundOption.all.length,
          separatorBuilder: (_, _) => const SizedBox(width: _cardSpacing),
          itemBuilder: (context, i) => _buildCard(BackgroundOption.all[i], i),
        ),
      ),
    );
  }

  /// Scrolls so the just-selected background at [index] is fully in view,
  /// centered in the row — tapping a card near either edge would otherwise
  /// leave it half cut off under the fade scrim.
  void _centerCard(int index) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final itemStart =
        widget.horizontalInset + index * (_cardWidth + _cardSpacing);
    final target = itemStart - (position.viewportDimension - _cardWidth) / 2;
    _scrollController.animateTo(
      target.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Selected-state treatment (foreground border + checkmark badge) mirrors
  /// `GarmentCard`'s selected styling, so the same "picked" affordance reads
  /// consistently across the app.
  Widget _buildCard(BackgroundOption background, int index) {
    final isSelected = background.id == widget.selected.id;
    final onSelected = widget.onSelected;
    return GestureDetector(
      onTap: onSelected == null
          ? null
          : () {
              onSelected(background);
              _centerCard(index);
            },
      child: SizedBox(
        width: _cardWidth,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowResting,
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          // Painted after the child (unlike `decoration`), so this stays
          // visible over the photo instead of being covered by it.
          foregroundDecoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderStrong, width: 1.5),
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(background.assetPath, fit: BoxFit.cover),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, AppColors.scrimBackdrop],
                      ),
                    ),
                    child: Text(
                      background.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyle.bold12.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.accent : AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowResting,
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: AppColors.textOnPrimary,
                            size: 14,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
