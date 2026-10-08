import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/features/widgets/common/images/refreshable_network_image.dart';
import 'package:uwearis/l10n/generated/app_localizations_en.dart';

import '../helpers/fake_auth.dart';
import '../helpers/widget_harness.dart';

/// Fails every download, standing in for an expired signed URL.
class _FailingCacheManager extends Fake implements BaseCacheManager {
  @override
  Future<FileInfo?> getFileFromMemory(String key) async => null;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => Stream.error(const HttpExceptionWithStatus(403, 'expired'));
}

void main() {
  // Set without reading the original first: reading it would lazily build
  // the real DefaultCacheManager, which hits path_provider. Each test file
  // runs in its own isolate, so there's nothing to restore.
  setUpAll(() {
    CachedNetworkImageProvider.defaultCacheManager = _FailingCacheManager();
  });

  setUp(() {
    setUpFakeAuth();
    // AuthExpiredHandler.handle's clearSignedInSession() touches
    // SharedPreferences (GarmentService's closet-analysis cache).
    SharedPreferences.setMockInitialValues({});
  });

  // The fake cache manager fails every load, so the widget always attempts
  // its one self-heal.
  Future<void> pumpFailingImage(
    WidgetTester tester, {
    required Future<String?> Function() onRefreshUrl,
  }) async {
    await pumpApp(
      tester,
      RefreshableNetworkImage(
        imageUrl: 'https://example.com/expired.jpg',
        onRefreshUrl: onRefreshUrl,
      ),
    );
    await tester.pump();
    await tester.pump();
    // AuthExpiredHandler's own async chain (clearSignedInSession) runs
    // before it calls showDialog.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('an AuthExpiredException from onRefreshUrl shows the '
      'session-expired dialog', (tester) async {
    var refreshCalls = 0;
    await pumpFailingImage(
      tester,
      onRefreshUrl: () async {
        refreshCalls++;
        throw AuthExpiredException();
      },
    );

    expect(refreshCalls, 1);
    expect(find.text(AppLocalizationsEn().sessionExpiredTitle), findsOneWidget);
  });

  testWidgets('no session-expired dialog when the session was already ended '
      '(e.g. right after a logout)', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    var refreshCalls = 0;
    await pumpFailingImage(
      tester,
      onRefreshUrl: () async {
        refreshCalls++;
        throw AuthExpiredException();
      },
    );

    expect(refreshCalls, 1);
    expect(find.text(AppLocalizationsEn().sessionExpiredTitle), findsNothing);
  });

  testWidgets('any other onRefreshUrl failure keeps the broken-image state '
      'without a dialog', (tester) async {
    var refreshCalls = 0;
    await pumpFailingImage(
      tester,
      onRefreshUrl: () async {
        refreshCalls++;
        throw Exception('network down');
      },
    );

    expect(refreshCalls, 1);
    expect(find.text(AppLocalizationsEn().sessionExpiredTitle), findsNothing);
  });
}
