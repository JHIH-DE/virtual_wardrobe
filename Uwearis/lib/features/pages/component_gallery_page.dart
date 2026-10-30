import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/garment.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/buttons/accent_pill_button.dart';
import '../widgets/common/buttons/action_button.dart';
import '../widgets/common/buttons/bottom_action_button.dart';
import '../widgets/common/cards/app_card_shell.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/cards/category_tag.dart';
import '../widgets/common/cards/count_pill.dart';
import '../widgets/common/fields/selectable_chip.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/error_state_widget.dart';
import '../widgets/garment/garment_list_card.dart';
import '../widgets/outfit/outfit_tag_row.dart';

/// Debug-only preview of the shared components in their real states, for
/// before/after comparison. Spec labels are widget/variant identifiers, not
/// user-facing copy; sample labels reuse real ARB strings so each locale's
/// text length shows.
class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  static const List<double> _textScales = [1.0, 1.3, 2.0];

  static const Garment _sampleGarment = Garment(
    id: 1,
    name: 'Oversized Denim Trucker Jacket',
    category: GarmentCategory.outer,
    subCategory: 'Denim jacket',
    uploadUrl: '',
    objectName: '',
    imageUrl: '',
    color: 'Light Blue',
  );

  double _textScale = 1.0;
  bool _showBottomAction = true;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: AppToolBar(title: _l10n.debugToolsComponentGallery),
      bottomNavigationBar: _showBottomAction
          ? BottomActionButton(label: _l10n.save, onPressed: () {})
          : null,
      body: Column(
        children: [
          _buildControls(),
          Expanded(
            child: Builder(
              // The body's own MediaQuery, which Scaffold has already
              // adjusted for the app bar and bottom bar.
              builder: (bodyContext) => MediaQuery(
                data: MediaQuery.of(
                  bodyContext,
                ).copyWith(textScaler: TextScaler.linear(_textScale)),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    _showBottomAction
                        ? BottomActionButton.scrollClearance(bodyContext)
                        : 16 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    ..._buildFullWidthButtons(),
                    ..._buildHugButtons(),
                    ..._buildLoadingStates(),
                    ..._buildTagsAndChips(),
                    ..._buildCards(),
                    ..._buildPageStates(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kept outside the scaled subtree so the toggles stay usable at 2.0.
  Widget _buildControls() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final scale in _textScales) ...[
            SelectableChip(
              label: '${scale.toStringAsFixed(1)}×',
              selected: _textScale == scale,
              onTap: () => setState(() => _textScale = scale),
            ),
            const SizedBox(width: 8),
          ],
          const SizedBox(width: 8),
          SelectableChip(
            label: 'BottomActionButton',
            selected: _showBottomAction,
            onTap: () => setState(() => _showBottomAction = !_showBottomAction),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFullWidthButtons() {
    return [
      const _SectionHeader('ActionButton — full width'),
      const _Spec('primary · normal'),
      ActionButton(label: _l10n.createOutfit, onPressed: () {}),
      const _Spec('primary · disabled (onPressed: null)'),
      ActionButton(label: _l10n.createOutfit),
      const _Spec('secondary · normal'),
      ActionButton(
        label: _l10n.viewClosetMatch,
        variant: ActionButtonVariant.secondary,
        onPressed: () {},
      ),
      const _Spec('secondary · disabled'),
      ActionButton(
        label: _l10n.viewClosetMatch,
        variant: ActionButtonVariant.secondary,
      ),
      const _Spec(
        'secondary + primary side by side; stacks when either label would '
        'not fit its half',
      ),
      _ActionButtonPair(
        secondaryLabel: _l10n.viewClosetMatch,
        primaryLabel: _l10n.createOutfit,
      ),
    ];
  }

  List<Widget> _buildHugButtons() {
    return [
      const _SectionHeader('AccentPillButton — hugs its content'),
      const _Spec('inline · normal, beside a section title (on surface)'),
      // Mirrors Create Outfit's AI Styling header.
      AppCardShell(
        title: _l10n.finishOutfit,
        subtitle: _l10n.finishOutfitDescription,
        trailing: AccentPillButton(label: _l10n.finishWithAi, onPressed: () {}),
      ),
      const _Spec('inline · normal / disabled (on pageBackground)'),
      Wrap(
        spacing: 12,
        children: [
          AccentPillButton(label: _l10n.addVersionButton, onPressed: () {}),
          AccentPillButton(label: _l10n.addVersionButton, enabled: false),
        ],
      ),
      const _Spec('inline · disabled + disabledMessage'),
      AccentPillButton(
        label: _l10n.planTripOutfits,
        enabled: false,
        disabledMessage: _l10n.dayOutfitMissingCoreItemsMessage,
      ),
      const _Spec('toolbar variant'),
      Align(
        alignment: Alignment.centerLeft,
        child: AccentPillButton(
          label: _l10n.explore,
          variant: AccentPillButtonVariant.toolbar,
          onPressed: () {},
        ),
      ),
    ];
  }

  List<Widget> _buildLoadingStates() {
    return [
      const _SectionHeader('Loading — existing convention'),
      const _Spec(
        'BottomActionButton(isLoading: true) renders nothing; the screen '
        'shows a LoadingOverlay instead (box below is intentionally empty)',
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.borderStrong),
          borderRadius: BorderRadius.circular(AppDimens.cardRadius),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 24),
          child: BottomActionButton(
            label: _l10n.save,
            onPressed: () {},
            isLoading: true,
            panelPadding: EdgeInsets.zero,
          ),
        ),
      ),
      const _Spec('in-page trigger while in flight → enabled: false'),
      Align(
        alignment: Alignment.centerLeft,
        child: AccentPillButton(label: _l10n.finishWithAi, enabled: false),
      ),
      const _Spec('AppSpinner (brief in-place fetch)'),
      const Center(child: AppSpinner()),
    ];
  }

  List<Widget> _buildTagsAndChips() {
    return [
      const _SectionHeader('Tags & chips'),
      const _Spec('on pageBackground'),
      _buildTagChipSamples(),
      const _Spec('on surface (inside AppCardShell)'),
      AppCardShell(child: _buildTagChipSamples()),
    ];
  }

  Widget _buildTagChipSamples() {
    final category = _sampleGarment.category.localizedLabel(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Spec(
          'CategoryTag · default / borderColor: surface / header · CountPill',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            CategoryTag(label: category),
            CategoryTag(label: category, borderColor: AppColors.surface),
            CategoryTag(label: category, variant: CategoryTagVariant.header),
            // CountPill fills a loose width; real callers sit in a Row.
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [CountPill(count: 12)],
            ),
          ],
        ),
        const _Spec('OutfitTagRow (collapses to +N)'),
        const OutfitTagRow(
          seasons: ['spring', 'summer', 'autumn', 'winter'],
          style: ['smart_casual', 'minimalist', 'streetwear', 'business'],
        ),
        const _Spec('SelectableChip · default (selected / unselected)'),
        Wrap(
          spacing: 8,
          children: [
            SelectableChip(label: category, selected: true, onTap: () {}),
            SelectableChip(label: category, selected: false, onTap: () {}),
          ],
        ),
        // Same colors FilterButton passes; see the design-system report's
        // SelectableChip variant item.
        const _Spec('SelectableChip · as FilterButton styles it'),
        Wrap(
          spacing: 8,
          children: [
            for (final selected in [true, false])
              SelectableChip(
                label: _l10n.filterAll,
                selected: selected,
                selectedColor: AppColors.accentTint,
                selectedTextColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                onTap: () {},
              ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildCards() {
    return [
      const _SectionHeader('Cards (on pageBackground)'),
      const _Spec('AppCardShell'),
      AppCardShell(
        title: _l10n.startPackingTripTitle,
        subtitle: _l10n.startPackingTripHint,
      ),
      const _Spec('AppListCard · leading + summary + arrow'),
      AppListCard(
        onTap: () {},
        leading: const Icon(Icons.person_outline, color: AppColors.icon),
        showArrow: true,
        summary: _l10n.accountSummary,
        child: Text(_l10n.account, style: AppTextStyle.bold16),
      ),
      const _Spec('AppListCard · disabled'),
      AppListCard(
        enabled: false,
        onTap: () {},
        leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.icon),
        showArrow: true,
        summary: _l10n.styleTasteLockedSummary,
        child: Text(_l10n.styleTaste, style: AppTextStyle.bold16),
      ),
      const _Spec('GarmentListCard · minimum height, long name'),
      GarmentListCard(garment: _sampleGarment, onTap: () {}),
    ];
  }

  List<Widget> _buildPageStates() {
    return [
      const _SectionHeader('Page states'),
      const _Spec('EmptyStatePlaceholder · with action'),
      EmptyStatePlaceholder(
        icon: Icons.luggage_outlined,
        title: _l10n.startPackingTripTitle,
        message: _l10n.startPackingTripHint,
        actionLabel: _l10n.addGarmentsButton,
        onAction: () {},
      ),
      const _Spec('ErrorStateWidget'),
      SizedBox(
        height: 220,
        child: ErrorStateWidget(error: Exception('sample'), onRetry: () {}),
      ),
    ];
  }
}

/// The parent-side rule for two [ActionButton]s sharing a row: side by side
/// while both labels fit on one line in their half, otherwise stacked with
/// the primary on top.
class _ActionButtonPair extends StatelessWidget {
  final String secondaryLabel;
  final String primaryLabel;

  const _ActionButtonPair({
    required this.secondaryLabel,
    required this.primaryLabel,
  });

  static const double _gap = AppDimens.cardSpacing;

  @override
  Widget build(BuildContext context) {
    final primary = ActionButton(label: primaryLabel, onPressed: () {});
    final secondary = ActionButton(
      label: secondaryLabel,
      variant: ActionButtonVariant.secondary,
      onPressed: () {},
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final half = (constraints.maxWidth - _gap) / 2;
        final fits = [secondaryLabel, primaryLabel].every(
          (label) => ActionButton.oneLineWidthFor(context, label) <= half,
        );
        if (fits) {
          return Row(
            children: [
              Expanded(child: secondary),
              const SizedBox(width: _gap),
              Expanded(child: primary),
            ],
          );
        }
        return Column(
          children: [
            primary,
            const SizedBox(height: _gap),
            secondary,
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 4),
      child: Text(title, style: AppTextStyle.bold18),
    );
  }
}

class _Spec extends StatelessWidget {
  final String text;

  const _Spec(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Text(
        text,
        style: AppTextStyle.regular12.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
