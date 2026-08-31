import 'env.dart';

class AppConfig {
  static const String baseUrl = Env.baseUrl;
  static const String apiVersion = 'v1';
  static const String apiPath = '/api/$apiVersion';
  static String get fullApiUrl => '$baseUrl$apiPath';
}
