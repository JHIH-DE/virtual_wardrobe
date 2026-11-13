import 'env.dart';

class AppConfig {
  static const String baseUrl = Env.baseUrl;
  static const String apiVersion = 'v1';
  static const String apiPath = '/api/$apiVersion';
  static String get fullApiUrl => '$baseUrl$apiPath';

  static const bool enableDebugTools = false;
  static const bool enableExplore = false;

  // TODO(launch): placeholders — replace with the live pages and mailbox
  // before App Store submission (Guideline 5.1.1 requires a working link).
  static const String privacyPolicyUrl = 'https://uwearis.com/privacy';
  static const String termsOfServiceUrl = 'https://uwearis.com/terms';
  static const String supportEmail = 'support@uwearis.com';

  /// Named in the AI consent disclosure. Changing it changes who receives
  /// user data: bump `UserAcknowledgement.aiConsent`'s version in the same
  /// change so everyone is asked again.
  static const String aiProviderName = 'Google Gemini';

  /// Minimum age to add face/body reference photos; the Terms of Service and
  /// the App Store age rating must state the same age.
  static const int minimumAge = 13;
}
