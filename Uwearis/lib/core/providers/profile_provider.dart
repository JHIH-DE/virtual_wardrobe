import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_data.dart';
import '../../data/user_profile.dart';
import '../services/profile_service.dart';
import 'retry_policy.dart';

/// The signed-in user's profile + try-on reference photos. Shared by the
/// Account, Settings, Home, and Try-on Profile screens so they don't each
/// fetch `GET /users/me` on open — and that one fetch itself only hits the
/// endpoint once (see [ProfileNotifier._fetch]).
final profileProvider = AsyncNotifierProvider<ProfileNotifier, ProfileData>(
  ProfileNotifier.new,
  retry: appRetryPolicy,
);

class ProfileNotifier extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() => _fetch();

  /// One `GET /users/me` request — see [ProfileService.getMyProfileData]'s
  /// own doc for why this used to be 3 (`getMyProfile`/`getBodyRef`/
  /// `getFaceReference` via `Future.wait`, all hitting the same endpoint).
  Future<ProfileData> _fetch() => ProfileService().getMyProfileData();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Reflects an [ProfileService.updateMyProfile] result in place, without a
  /// re-fetch — the reference-photo URLs are untouched by that call.
  void setProfile(UserProfile profile) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(profile: profile));
  }

  /// Reflects a just-completed [ProfileService.uploadBodyRef]/[uploadFaceRef]
  /// in place, using the signed URL its own `/complete` response already
  /// returns — deliberately not a [refresh] (re-fetching `GET /users/me`
  /// immediately afterwards can race a backend-side async job still
  /// committing that URL to the profile record it reads from; see
  /// `ProfileService._completeTimeout`'s doc for why `complete` isn't
  /// purely synchronous). Same optimistic-update shape as
  /// `garmentsProvider.addGarment`.
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
}
