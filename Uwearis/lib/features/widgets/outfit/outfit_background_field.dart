import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/background_option.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/fields/labeled_field.dart';
import '../common/fields/tappable_field_decorator.dart';
import '../common/overlays/picker_sheet.dart';

/// Shows the selected background; opens a sheet with a horizontal row of
/// presets. Tapping one selects it and closes the sheet.
class OutfitBackgroundField extends StatelessWidget {
  final BackgroundOption selected;

  /// `null` disables selection (e.g. while an AI render is in flight).
  final ValueChanged<BackgroundOption>? onSelected;

  const OutfitBackgroundField({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabled = onSelected != null;
    return LabeledField(
      label: l10n.backgroundLabel,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: TappableFieldDecorator(
            onTap: () => _openSheet(context),
            children: [
              Expanded(
                child: Text(
                  selected.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.regular14,
                ),
              ),
              Image.asset(
                'assets/images/arrow_down.png',
                height: AppDimens.iconSmallSize,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _cardWidth = 120.0;
  static const _cardHeight = 170.0;
  static const _sheetInset = 20.0;

  void _openSheet(BuildContext context) {
    const options = BackgroundOption.all;
    final selectedIndex = options.indexWhere((b) => b.id == selected.id);
    // Open with the current background centered (clamped to the row ends).
    final screenWidth = MediaQuery.of(context).size.width;
    final contentWidth =
        options.length * _cardWidth +
        (options.length - 1) * AppDimens.cardSpacing +
        2 * _sheetInset;
    final maxOffset = (contentWidth - screenWidth).clamp(0.0, double.infinity);
    final centeredOffset =
        _sheetInset +
        selectedIndex * (_cardWidth + AppDimens.cardSpacing) -
        (screenWidth - _cardWidth) / 2;
    final scrollController = ScrollController(
      initialScrollOffset: selectedIndex < 0
          ? 0
          : centeredOffset.clamp(0.0, maxOffset),
    );

    showPickerSheet<void>(
      context,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sheetInset),
            child: PickerSheetHeader(
              AppLocalizations.of(sheetContext).chooseBackgroundTitle,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _sheetInset),
              itemCount: options.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: AppDimens.cardSpacing),
              itemBuilder: (_, i) {
                final background = options[i];
                return SizedBox(
                  width: _cardWidth,
                  child: _BackgroundCard(
                    background: background,
                    isSelected: background.id == selected.id,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      if (background.id != selected.id) {
                        onSelected?.call(background);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ).whenComplete(scrollController.dispose);
  }
}

class _BackgroundCard extends StatelessWidget {
  final BackgroundOption background;
  final bool isSelected;
  final VoidCallback onTap;

  const _BackgroundCard({
    required this.background,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        // Foreground, so the border isn't covered by the photo.
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
                child: Container(
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
    );
  }
}
