import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uwearis/core/services/auth_handler.dart';
import 'package:uwearis/core/utils/image_cache_bust.dart';
import 'package:uwearis/data/profile_data.dart';
import 'package:uwearis/data/user_profile.dart';

void main() {
  testWidgets(
    "invalidateSignedInProviders bumps the avatar/face/body reference "
    "image cache keys, so a newly signed-in account never sees the "
    "previous account's still-cached photo bytes under the same fixed, "
    "un-scoped cache key",
    (tester) async {
      final beforeAvatar = ImageCacheBust.versionOf(avatarImageCacheKey);
      final beforeFace = ImageCacheBust.versionOf(faceRefImageCacheKey);
      final beforeBody = ImageCacheBust.versionOf(bodyRefImageCacheKey);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      invalidateSignedInProviders(capturedContext);

      expect(ImageCacheBust.versionOf(avatarImageCacheKey), beforeAvatar + 1);
      expect(ImageCacheBust.versionOf(faceRefImageCacheKey), beforeFace + 1);
      expect(ImageCacheBust.versionOf(bodyRefImageCacheKey), beforeBody + 1);
    },
  );
}
