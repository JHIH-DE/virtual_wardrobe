/// A background scene choice for the Create Look flow, backed by a bundled
/// preview image (see `assets/images/`). Add another entry here to offer a
/// new scene — no other code needs to change.
class SceneOption {
  final String id;
  final String label;
  final String assetPath;

  /// The backend's `background_id` for Regenerate Look — matched against
  /// the backend's background lookup table by name (`fitting_room` maps to
  /// its "Default Fitting Room" entry; the rest match by name exactly).
  final int backgroundId;

  const SceneOption({
    required this.id,
    required this.label,
    required this.assetPath,
    required this.backgroundId,
  });

  static const List<SceneOption> all = [
    SceneOption(
      id: 'fitting_room',
      label: 'Fitting Room',
      assetPath: 'assets/images/fitting_room.png',
      backgroundId: 0,
    ),
    SceneOption(
      id: 'tokyo_street',
      label: 'Tokyo Street',
      assetPath: 'assets/images/tokyo_street.png',
      backgroundId: 7,
    ),
    SceneOption(
      id: 'new_york_street',
      label: 'New York Street',
      assetPath: 'assets/images/new_york_street.png',
      backgroundId: 5,
    ),
    SceneOption(
      id: 'paris_street',
      label: 'Paris Street',
      assetPath: 'assets/images/paris_street.png',
      backgroundId: 6,
    ),
    SceneOption(
      id: 'marina_bay',
      label: 'Marina Bay',
      assetPath: 'assets/images/marina_bay.png',
      backgroundId: 3,
    ),
    SceneOption(
      id: 'mediterranean_town',
      label: 'Mediterranean Town',
      assetPath: 'assets/images/mediterranean_town.png',
      backgroundId: 4,
    ),
  ];
}
