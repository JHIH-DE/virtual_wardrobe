/// A background choice for the Create Outfit flow, backed by a
/// bundled preview image (see `assets/images/`). Add another entry here to
/// offer a new background — no other code needs to change.
class BackgroundOption {
  final String id;
  final String label;
  final String assetPath;

  /// The backend's `background_id` for outfit generate/regenerate —
  /// matched against the backend's background lookup table by name
  /// (`fitting_room` maps to its "Default Fitting Room" entry; the rest
  /// match by name exactly).
  final int backgroundId;

  const BackgroundOption({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.backgroundId,
  });

  static const List<BackgroundOption> all = [
    BackgroundOption(
      id: 'fitting_room',
      label: 'Fitting Room',
      assetPath: 'assets/images/fitting_room.png',
      backgroundId: 0,
    ),
    BackgroundOption(
      id: 'tokyo_street',
      label: 'Tokyo Street',
      assetPath: 'assets/images/tokyo_street.png',
      backgroundId: 7,
    ),
    BackgroundOption(
      id: 'new_york_street',
      label: 'New York Street',
      assetPath: 'assets/images/new_york_street.png',
      backgroundId: 5,
    ),
    BackgroundOption(
      id: 'paris_street',
      label: 'Paris Street',
      assetPath: 'assets/images/paris_street.png',
      backgroundId: 6,
    ),
    BackgroundOption(
      id: 'marina_bay',
      label: 'Marina Bay',
      assetPath: 'assets/images/marina_bay.png',
      backgroundId: 3,
    ),
    BackgroundOption(
      id: 'mediterranean_town',
      label: 'Mediterranean Town',
      assetPath: 'assets/images/mediterranean_town.png',
      backgroundId: 4,
    ),
  ];
}
