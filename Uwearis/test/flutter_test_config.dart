import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/utils/user_acknowledgement.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Most widget tests drive AI and reference-photo flows; the prompts have
  // their own tests, which reset this to null.
  UserAcknowledgement.debugGrantedOverride = true;
  // An unmocked SharedPreferences never completes in a widget test; tests
  // that need stored values still set their own in setUp.
  SharedPreferences.setMockInitialValues({});
  await testMain();
}
