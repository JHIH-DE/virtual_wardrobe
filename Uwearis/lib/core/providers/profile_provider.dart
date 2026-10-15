import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_data.dart';
import '../../data/user_profile.dart';
import '../services/profile_service.dart';
import 'retry_policy.dart';

/// Profile + reference photos, shared by Account, Settings, Home and My
/// Virtual Model so each doesn't fetch `GET /users/me` on open.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, ProfileData>(
  ProfileNotifier.new,
  retry: appRetryPolicy,
);

class ProfileNotifier extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() => _fetch();

  Future<ProfileData> _fetch() => ProfileService().getMyProfileData();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Applies an [ProfileService.updateMyProfile] result; photo URLs are
  /// unaffected by that call.
  void setProfile(UserProfile profile) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(profile: profile));
  }

  /// Uses the URL from the upload's `/complete` response rather than a
  /// [refresh], which could race the backend still committing it.
  void setBodyRefUrl(String url) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(bodyRefUrl: url));
  }

  void setFaceRefUrl(String url) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(faceRefUrl: url));
  }

  /// Compare-and-set: a re-signed URL can arrive after a newer upload, and
  /// must not revert it.
  void setBodyRefUrlIfCurrent(String expectedCurrent, String freshUrl) {
    final current = state.value;
    if (current == null || current.bodyRefUrl != expectedCurrent) return;
    state = AsyncData(current.copyWith(bodyRefUrl: freshUrl));
  }

  /// See [setBodyRefUrlIfCurrent].
  void setFaceRefUrlIfCurrent(String expectedCurrent, String freshUrl) {
    final current = state.value;
    if (current == null || current.faceRefUrl != expectedCurrent) return;
    state = AsyncData(current.copyWith(faceRefUrl: freshUrl));
  }

  /// Not a [refresh], for the same reason as [setBodyRefUrl].
  void setBaseModelUrl(String url) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(baseModelUrl: url));
  }
}
