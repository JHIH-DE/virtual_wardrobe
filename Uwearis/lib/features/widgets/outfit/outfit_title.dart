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
  final parts = [...seasons, ...style];
  if (parts.isEmpty) return l10n.myOutfit;
  final word = parts.first;
  final capitalized = word.isEmpty
      ? word
      : '${word[0].toUpperCase()}${word.substring(1)}';
  return l10n.outfitTitle(capitalized);
}

/// A season/style value as a tag label. Styles arrive snake_case
/// (`smart_casual`).
String outfitTagLabel(String s) => s
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
