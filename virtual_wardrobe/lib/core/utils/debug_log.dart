import 'package:flutter/foundation.dart';

/// Usage: debugLog('message');
/// Output: [AuthService.logout] message
void debugLog(String message, {Object? error, StackTrace? stackTrace}) {
  if (!kDebugMode) return;
  final frames = StackTrace.current.toString().split('\n');
  final callerFrame = frames.length > 1 ? frames[1] : '';
  final match = RegExp(r'#\d+\s+(\S+)').firstMatch(callerFrame);
  final name = match?.group(1) ?? 'App';
  debugPrint('[$name] $message');
  if (error != null) debugPrint('[$name] ERROR: $error');
  if (stackTrace != null) debugPrint('[$name] STACK: $stackTrace');
}
