/// A named point (city/place) with coordinates and timezone, as returned by
/// [LocationPickerPage]'s geocoding search. Used wherever the app needs the
/// user to pick a place — trip legs, profile home location, etc.
class LocationResult {
  final String name;
  final double latitude;
  final double longitude;
  final String timezone;

  LocationResult({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });
}
