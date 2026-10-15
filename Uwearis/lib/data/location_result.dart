/// A named place with coordinates and timezone, from
/// `LocationPickerPage`'s geocoding search.
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
