import '../l10n/generated/app_localizations.dart';

/// One story in Explore's The Edit carousel: a full-bleed photo with its
/// optional kicker, headline and subtitle laid over it.
class EditStory {
  final String imageAsset;
  final String? kicker;
  final String title;
  final String subtitle;

  const EditStory({
    required this.imageAsset,
    this.kicker,
    required this.title,
    required this.subtitle,
  });

  /// The bundled stories, until Explore has a content backend.
  static List<EditStory> bundled(AppLocalizations l10n) => [
    EditStory(
      imageAsset: 'assets/images/explore_01.png',
      title: l10n.exploreEditBlazerTitle,
      subtitle: l10n.exploreEditBlazerSubtitle,
    ),
    EditStory(
      imageAsset: 'assets/images/explore_02.png',
      kicker: l10n.exploreEditWorkwearKicker,
      title: l10n.exploreEditWorkwearTitle,
      subtitle: l10n.exploreEditWorkwearSubtitle,
    ),
    EditStory(
      imageAsset: 'assets/images/explore_03.png',
      kicker: l10n.exploreEditTrailKicker,
      title: l10n.exploreEditTrailTitle,
      subtitle: l10n.exploreEditTrailSubtitle,
    ),
  ];
}
