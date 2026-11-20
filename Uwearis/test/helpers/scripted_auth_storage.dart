import 'dart:async';

import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
// Transitive via flutter_secure_storage / shared_preferences; only their
// platform setters and in-memory stores are used.
// ignore: depend_on_referenced_packages
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:uwearis/core/services/auth_storage.dart';

/// Secure storage (the keychain) whose individual writes and deletes the
/// test scripts. Its [data] outlives a simulated restart.
class ScriptedSecureStorage extends TestFlutterSecureStoragePlatform {
  ScriptedSecureStorage(super.data);

  /// Keys whose next write throws.
  final failNextWrite = <String>{};

  /// Keys whose deletes throw, every time.
  final failDeletes = <String>{};

  /// Keys whose next write waits for the completer; completing it with an
  /// error fails that write.
  final holdNextWrite = <String, Completer<void>>{};

  @override
  Future<void> write({
    required String key,
    required String value,
    required Map<String, String> options,
  }) async {
    final hold = holdNextWrite.remove(key);
    if (hold != null) await hold.future;
    if (failNextWrite.remove(key)) throw Exception('keychain write failed');
    return super.write(key: key, value: value, options: options);
  }

  @override
  Future<void> delete({
    required String key,
    required Map<String, String> options,
  }) async {
    if (failDeletes.contains(key)) throw Exception('keychain delete failed');
    return super.delete(key: key, options: options);
  }
}

/// SharedPreferences' platform store, whose reads and writes the test can
/// fail. Its contents outlive a simulated restart.
class ScriptedPrefsStore extends InMemorySharedPreferencesStore {
  ScriptedPrefsStore() : super.empty();

  bool failReads = false;
  bool failWrites = false;
  bool failRemoves = false;

  /// Everything stored, without the plugin's `flutter.` prefix.
  Future<Map<String, Object>> stored() async => {
    for (final e in (await super.getAll()).entries)
      e.key.replaceFirst('flutter.', ''): e.value,
  };

  @override
  Future<Map<String, Object>> getAllWithParameters(
    GetAllParameters parameters,
  ) {
    if (failReads) throw Exception('prefs read failed');
    return super.getAllWithParameters(parameters);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) {
    if (failWrites) throw Exception('prefs write failed');
    return super.setValue(valueType, key, value);
  }

  @override
  Future<bool> remove(String key) {
    if (failRemoves) throw Exception('prefs remove failed');
    return super.remove(key);
  }
}

ScriptedSecureStorage installKeychain(Map<String, String> data) {
  final storage = ScriptedSecureStorage(data);
  FlutterSecureStoragePlatform.instance = storage;
  return storage;
}

ScriptedPrefsStore installPrefs() {
  final store = ScriptedPrefsStore();
  SharedPreferencesStorePlatform.instance = store;
  SharedPreferences.resetStatic();
  return store;
}

/// A relaunch: every in-memory cache goes, the keychain and the
/// SharedPreferences store keep what they hold.
void simulateRestart() {
  AuthStorage.debugSimulateRestart();
  SharedPreferences.resetStatic();
}
