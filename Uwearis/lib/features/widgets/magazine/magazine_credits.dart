import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/editorial_typography.dart';
import '../../../data/magazine.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/labeled_divider.dart';
import 'editorial_text.dart';

/// "Advertisement | KUMO ATELIER" for a sponsored story; null otherwise.
String? magazineSponsorText(BuildContext context, MagazineStorySummary story) {
  final l10n = AppLocalizations.of(context);
  final kind = switch (story.sponsorship) {
    MagazineSponsorship.none => null,
    MagazineSponsorship.gifted => l10n.magazineSponsorGifted,
    MagazineSponsorship.collaboration => l10n.magazineSponsorCollaboration,
    MagazineSponsorship.advertisement => l10n.magazineSponsorAdvertisement,
  };
  if (kind == null) return null;
  final brand = story.sponsorName;
  return brand == null || brand.isEmpty
      ? kind
      : l10n.magazineSponsorLine(kind, brand);
}

/// A sponsored story's disclosure, on its cover, its card and its article.
/// Renders nothing for an unsponsored story.
class MagazineSponsorLabel extends StatelessWidget {
  final MagazineStorySummary story;
  final bool onPhoto;

  const MagazineSponsorLabel({
    super.key,
    required this.story,
    this.onPhoto = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = magazineSponsorText(context, story);
    if (text == null) return const SizedBox.shrink();
    final color = onPhoto ? AppColors.textOnPrimary : AppColors.textPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: color)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: EditorialText(
          text,
          style: EditorialTypography.sectionLabel.merge(
            TextStyle(color: color),
          ),
        ),
      ),
    );
  }
}

/// A story's credits under a "Credits" rule, closing an article or a
/// story's last page.
class MagazineCreditsSection extends StatelessWidget {
  final MagazineStory story;
  final void Function(String url)? onOpenSource;

  const MagazineCreditsSection({
    super.key,
    required this.story,
    this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledDivider(label: AppLocalizations.of(context).magazineCredits),
        const SizedBox(height: AppDimens.cardSpacing),
        MagazineCreditsView(story: story, onOpenSource: onOpenSource),
      ],
    );
  }
}

/// A story's credits: who wrote it, what it drew on, who took the photos,
/// and its sponsor. [onOpenSource] opens a source's link; null (the CMS
/// preview) lists them without links.
class MagazineCreditsView extends StatelessWidget {
  final MagazineStory story;
  final void Function(String url)? onOpenSource;

  const MagazineCreditsView({
    super.key,
    required this.story,
    this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final author = story.author;
    final sponsor = magazineSponsorText(context, story.summary);
    final onOpenSource = this.onOpenSource;
    final valueStyle = EditorialTypography.caption;
    Widget section(String label, List<Widget> values) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EditorialText(
            label.toUpperCase(),
            style: EditorialTypography.sectionLabel,
          ),
          const SizedBox(height: 4),
          ...values,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sponsor != null)
          section(l10n.magazineCreditsPartner, [
            EditorialText(sponsor, style: valueStyle),
          ]),
        if (author != null)
          section(l10n.magazineCreditsAuthor, [
            EditorialText(author, style: valueStyle),
          ]),
        if (story.sources.isNotEmpty)
          section(l10n.magazineCreditsSources, [
            for (final source in story.sources)
              _SourceRow(
                source: source,
                style: valueStyle,
                onOpen: onOpenSource == null
                    ? null
                    : () => onOpenSource(source.url),
              ),
          ]),
        if (story.photoCredits.isNotEmpty)
          section(l10n.magazineCreditsPhotography, [
            EditorialText(story.photoCredits.join('、'), style: valueStyle),
          ]),
        if (story.aiImageTools.isNotEmpty)
          section(l10n.magazineCreditsAiImages, [
            EditorialText(story.aiImageTools.join('、'), style: valueStyle),
          ]),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  final MagazineSource source;
  final EditorialTextStyle style;
  final VoidCallback? onOpen;

  const _SourceRow({required this.source, required this.style, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final onOpen = this.onOpen;
    final title = source.title ?? Uri.tryParse(source.url)?.host ?? source.url;
    final text = EditorialText(
      title,
      style: onOpen == null
          ? style
          : style.merge(const TextStyle(decoration: TextDecoration.underline)),
    );
    if (onOpen == null) return text;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onOpen,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(child: text),
              const Icon(
                Icons.open_in_new,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
