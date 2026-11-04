import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/profile_service.dart';
import '../../../data/profile_data.dart';
import '../../../data/user_tier.dart';
import '../../../l10n/user_tier_localization.dart';
import 'profile_avatar.dart';

/// Avatar, name, email and tier badge at the top of Settings and Explore's
/// Account tab. [data] is null while the profile is still loading.
class ProfileSummaryHeader extends StatelessWidget {
  final ProfileData? data;

  const ProfileSummaryHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final profile = data?.profile;
    final avatarUrl = profile?.avatarObjectUrl;
    final url =
        (avatarUrl != null && avatarUrl.isNotEmpty && avatarUrl != 'string')
        ? avatarUrl
        : null;
    final name = profile?.name;
    final email = profile?.email;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Row(
        children: [
          ProfileAvatar(
            url: url,
            onRefreshUrl: () => ProfileService().getMyAvatar(),
            size: 96,
            showEditLabel: false,
            fallbackIconSize: 52,
            ringColor: profile?.tier.colors.fill,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (name != null && name.isNotEmpty) ? name : '---',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.bold20,
                ),
                const SizedBox(height: 2),
                Text(
                  (email != null && email.isNotEmpty) ? email : '---',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (profile != null) ...[
                  const SizedBox(height: 8),
                  _TierBadge(tier: profile.tier),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final UserTier tier;
  const _TierBadge({required this.tier});

  @override
  Widget build(BuildContext context) {
    final (:fill, :text) = tier.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars, size: 18, color: text),
          const SizedBox(width: 4),
          Text(
            tier.localizedLabel(context),
            style: AppTextStyle.bold12.copyWith(color: text),
          ),
        ],
      ),
    );
  }
}

extension on UserTier {
  ({Color fill, Color text}) get colors {
    switch (this) {
      case UserTier.gold:
        return (fill: AppColors.tierGold, text: AppColors.tierGoldText);
      case UserTier.silver:
        return (fill: AppColors.tierSilver, text: AppColors.tierSilverText);
      case UserTier.bronze:
        return (fill: AppColors.tierBronze, text: AppColors.tierBronzeText);
    }
  }
}
