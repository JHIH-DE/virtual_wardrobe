class Env {
  /// The backend base URL. The `defaultValue` (staging) is the single source
  /// of truth — it isn't a secret and rarely changes, so it lives here
  /// rather than in `dart_defines/*.json` (which carry only the Google
  /// OAuth client ids). Point at another backend with
  /// `--dart-define=BASE_URL=https://…` or a per-env `*.json`.
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    //defaultValue: 'https://vw-backend-staging-662955046370.asia-east1.run.app',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
  );

  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );
}
