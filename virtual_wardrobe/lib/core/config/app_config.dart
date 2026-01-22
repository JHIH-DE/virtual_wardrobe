class AppConfig {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const String apiVersion = 'v1';
  static const String apiPath = '/api/$apiVersion';
  static String get fullApiUrl => '$baseUrl$apiPath';
}
