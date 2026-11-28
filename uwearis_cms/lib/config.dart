/// Build settings, from `--dart-define-from-file=dart_defines/dev.json`.
class Config {
  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static String get apiUrl => '$apiBaseUrl/api/v1';
}
