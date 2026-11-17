import '../../../data/style_type.dart';
import '../../../l10n/generated/app_localizations.dart';

/// Group name, else version name, else built from the first season/style
/// tag.
String outfitDisplayTitle(
  AppLocalizations l10n, {
  String? groupName,
  String? name,
  required List<String> seasons,
  required List<String> style,
}) {
  if (groupName != null && groupName.isNotEmpty) return groupName;
  if (name != null && name.isNotEmpty) return name;
  final parts = [...seasons, ...style].where((s) => s.trim().isNotEmpty);
  if (parts.isEmpty) return l10n.myOutfit;
  return l10n.outfitTitle(outfitTagLabel(l10n, parts.first));
}

/// A season/style tag's display label. A value this build doesn't know is
/// shown title-cased (`smart_casual` → "Smart Casual").
String outfitTagLabel(AppLocalizations l10n, String tag) {
  final value = normalizeOutfitTag(tag);
  switch (value) {
    case 'spring':
      return l10n.seasonSpring;
    case 'summer':
      return l10n.seasonSummer;
    case 'autumn':
      return l10n.seasonAutumn;
    case 'winter':
      return l10n.seasonWinter;
  }
  final style = styleTypeFromApiValue(value);
  if (style != null) {
    return switch (style) {
      StyleType.minimal => l10n.styleMinimalShort,
      StyleType.classic => l10n.styleClassic,
      StyleType.smartCasual => l10n.styleSmartCasual,
      StyleType.streetwear => l10n.styleStreetwear,
      StyleType.athleisure => l10n.styleAthleisure,
      StyleType.workwear => l10n.styleWorkwear,
      StyleType.preppy => l10n.stylePreppy,
      StyleType.business => l10n.styleBusiness,
      StyleType.vintage => l10n.styleVintage,
    };
  }
  return value
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
