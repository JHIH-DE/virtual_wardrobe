import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_data.dart';
import '../../data/user_profile.dart';
import '../services/profile_service.dart';

/// The signed-in user's profile + try-on reference photos. Shared by the
/// Account, Settings, and Try-on Profile screens so they don't each fetch
/// `GET /users/me` (three times over) on open.
final profileProvider = AsyncNotifierProvider<ProfileNotifier, ProfileData>(
  ProfileNotifier.new,
);

class ProfileNotifier extends AsyncNotifier<ProfileData> {
  @override
  Future<ProfileData> build() => _fetch();

  Future<ProfileData> _fetch() async {
    final results = await Future.wait([
      ProfileService().getMyProfile(),
      ProfileService().getBodyRef(),
      ProfileService().getFaceReference(),
    ]);
    return ProfileData(
      profile: results[0] as UserProfile,
      bodyRefUrl: results[1] as String?,
      faceRefUrl: results[2] as String?,
    );
  }

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
}
