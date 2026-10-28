import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/utils/crash_handler.dart';

void main() {
  test('setReportingUser is a no-op before Crashlytics is initialized', () {
    expect(GlobalErrorHandler.setReportingUser('a.b.c'), completes);
    expect(GlobalErrorHandler.setReportingUser(null), completes);
  });
}
