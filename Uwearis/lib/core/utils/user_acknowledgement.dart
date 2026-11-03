import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_storage.dart';

/// Something the signed-in user agreed to once, kept on the device per user
/// id until the backend stores it. Bump an instance's version when its
/// wording changes materially, so everyone is asked again.
class UserAcknowledgement {
  /// Photos and details going to the third-party AI service (App Review
  /// 5.1.2(i)); re-ask when `AppConfig.aiProviderName` changes.
  static const aiConsent = UserAcknowledgement._('ai_consent', 1);

  /// Meets `AppConfig.minimumAge` and adds only photos of themselves as
  /// face/body reference photos.
  static const referencePhotoTerms = UserAcknowledgement._(
    'reference_photo_terms',
    1,
  );

  final String _name;
  final int _version;

  const UserAcknowledgement._(this._name, this._version);

  /// Non-null skips storage for every acknowledgement;
  /// test/flutter_test_config.dart sets it true so flows run past the
  /// prompts unless a test opts back in with null.
  @visibleForTesting
  static bool? debugGrantedOverride;

  Future<String> _key() async =>
      '${_name}_v${_version}_${await AuthStorage.getUserId() ?? 'unknown'}';

  Future<bool> isGranted() async {
    if (debugGrantedOverride != null) return debugGrantedOverride!;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(await _key()) != null;
  }

  Future<void> grant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      await _key(),
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<void> revoke() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _key());
  }
}
