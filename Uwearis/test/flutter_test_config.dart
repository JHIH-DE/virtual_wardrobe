import 'dart:async';

import 'package:uwearis/core/utils/ai_consent.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Most widget tests drive AI flows; the consent prompt has its own tests,
  // which reset this to null.
  AiConsent.debugGrantedOverride = true;
  await testMain();
}
