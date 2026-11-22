import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/background_option.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/fields/chip_tab_row.dart';
import '../common/fields/labeled_field.dart';
import '../common/fields/tappable_field_decorator.dart';
import '../common/images/app_image.dart';
import '../common/images/app_spinner.dart';
import '../common/overlays/picker_sheet.dart';

/// [background]'s display name: the backend's `label` (in the account's
/// language), else — a backend that predates it — its code as words.
String backgroundLabel(BackgroundOption background) {
  final label = background.label?.trim();
  return label != null && label.isNotEmpty ? label : background.fallbackLabel;
}

String backgroundCategoryLabel(
  AppLocalizations l10n,
  BackgroundCategory category,
) {
  return switch (category) {
    BackgroundCategory.indoor => l10n.backgroundCategoryIndoor,
    BackgroundCategory.urban => l10n.backgroundCategoryUrban,
    BackgroundCategory.nature => l10n.backgroundCategoryNature,
    BackgroundCategory.other => l10n.backgroundCategoryOther,
  };
}

/// Shows the selected background; [onTap] opens the picker
/// ([showBackgroundPickerSheet]) once the page has the list.
class OutfitBackgroundField extends StatelessWidget {
  /// Null while the list loads or after it failed to.
  final BackgroundOption? selected;

  /// The list is loading: with nothing [selected] yet, a spinner stands in
  /// for the name so a tap that waits on it isn't silent.
  final bool isLoading;

  /// `null` disables selection (e.g. while an AI render is in flight).
  final VoidCallback? onTap;

  const OutfitBackgroundField({
    super.key,
    required this.selected,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tap = onTap;
    final selected = this.selected;
    return LabeledField(
      label: l10n.backgroundLabel,
      child: IgnorePointer(
        ignoring: tap == null,
        child: Opacity(
          opacity: tap == null ? 0.5 : 1,
          child: TappableFieldDecorator(
            onTap: tap ?? () {},
            children: [
              Expanded(
                child: selected == null && isLoading
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: AppSpinner(size: 16, strokeWidth: 2),
                      )
                    : Text(
                        selected == null ? '' : backgroundLabel(selected),
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
}

const _cardWidth = 120.0;
const _cardHeight = 170.0;
const _sheetInset = 20.0;

/// [options] in category tabs (only the categories present; no tabs when
/// there's one), each a horizontal row in the given order. Opens on the tab
/// of [selectedId]. Tapping a background closes the sheet and returns it,
/// unless it's already [selectedId]. [onRefreshImageUrl] re-signs a preview
/// URL that failed to load.
Future<BackgroundOption?> showBackgroundPickerSheet(
  BuildContext context, {
  required List<BackgroundOption> options,
  required int? selectedId,
  Future<String?> Function(BackgroundOption background)? onRefreshImageUrl,
}) async {
  BackgroundOption? picked;
  await showPickerSheet<void>(
    context,
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 40),
    builder: (sheetContext) => _BackgroundPicker(
      options: options,
      selectedId: selectedId,
      onRefreshImageUrl: onRefreshImageUrl,
      onPicked: (background) {
        Navigator.pop(sheetContext);
        if (background.id != selectedId) picked = background;
      },
    ),
  );
  return picked;
}

class _BackgroundPicker extends StatefulWidget {
  final List<BackgroundOption> options;
  final int? selectedId;
  final Future<String?> Function(BackgroundOption background)?
  onRefreshImageUrl;
  final ValueChanged<BackgroundOption> onPicked;

  const _BackgroundPicker({
    required this.options,
    required this.selectedId,
    required this.onRefreshImageUrl,
    required this.onPicked,
  });

  @override
  State<_BackgroundPicker> createState() => _BackgroundPickerState();
}

class _BackgroundPickerState extends State<_BackgroundPicker> {
  // ChipTabRow's own 44px rows (CategorySelector's 52 minus its padding).
  static const double _tabsHeight = 44;

  // null is the All tab.
  late final List<BackgroundCategory?> _tabs = [
    null,
    for (final c in BackgroundCategory.values)
      if (widget.options.any((b) => b.category == c)) c,
  ];
  static const BackgroundCategory? _initialTab = null;
  BackgroundCategory? _tab = _initialTab;
  ScrollController? _initialTabScroll;

  List<BackgroundOption> _optionsIn(BackgroundCategory? tab) => [
    for (final b in widget.options)
      if (tab == null || b.category == tab) b,
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialTabScroll ??= ScrollController(
      initialScrollOffset: _centeredOffset(_optionsIn(_initialTab)),
    );
  }

  /// Opens with the current background centered (clamped to the row ends).
  double _centeredOffset(List<BackgroundOption> row) {
    final index = row.indexWhere((b) => b.id == widget.selectedId);
    if (index < 0) return 0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final contentWidth =
        row.length * _cardWidth +
        (row.length - 1) * AppDimens.cardSpacing +
        2 * _sheetInset;
    final maxOffset = (contentWidth - screenWidth).clamp(0.0, double.infinity);
    final centered =
        _sheetInset +
        index * (_cardWidth + AppDimens.cardSpacing) -
        (screenWidth - _cardWidth) / 2;
    return centered.clamp(0.0, maxOffset);
  }

  @override
  void dispose() {
    _initialTabScroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final row = _optionsIn(_tab);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _sheetInset),
          child: PickerSheetHeader(
            l10n.chooseBackgroundTitle,
            // All plus a single category would be two identical tabs.
            bottom: _tabs.length > 2
                ? SizedBox(
                    height: _tabsHeight,
                    child: ChipTabRow<BackgroundCategory?>(
                      tabs: _tabs,
                      selected: _tab,
                      labelOf: (c) => c == null
                          ? l10n.backgroundCategoryAll
                          : backgroundCategoryLabel(l10n, c),
                      onSelected: (c) => setState(() => _tab = c),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: _cardHeight,
          child: ListView.separated(
            // Another tab starts at its own beginning.
            key: ValueKey(_tab),
            controller: _tab == _initialTab ? _initialTabScroll : null,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _sheetInset),
            itemCount: row.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppDimens.cardSpacing),
            itemBuilder: (_, i) {
              final background = row[i];
              final refresh = widget.onRefreshImageUrl;
              return SizedBox(
                width: _cardWidth,
                child: _BackgroundCard(
                  background: background,
                  isSelected: background.id == widget.selectedId,
                  onRefreshImageUrl: refresh == null
                      ? null
                      : () => refresh(background),
                  onTap: () => widget.onPicked(background),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BackgroundCard extends StatelessWidget {
  final BackgroundOption background;
  final bool isSelected;
  final VoidCallback onTap;
  final Future<String?> Function()? onRefreshImageUrl;

  const _BackgroundCard({
    required this.background,
    required this.isSelected,
    required this.onTap,
    required this.onRefreshImageUrl,
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
              AppImage(
                url: background.imageUrl,
                cacheKey: background.imageCacheKey,
                onRefreshUrl: onRefreshImageUrl,
                memCacheWidth:
                    (_cardWidth * MediaQuery.devicePixelRatioOf(context))
                        .round(),
              ),
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
                    backgroundLabel(background),
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
