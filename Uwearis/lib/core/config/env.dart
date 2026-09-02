class Env {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  // Empty disables Sentry entirely (its SDK no-ops with no DSN) — safe
  // default for local dev builds that haven't set one.
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
