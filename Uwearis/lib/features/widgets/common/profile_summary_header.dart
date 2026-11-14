import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/services/profile_service.dart';
import '../../../data/profile_data.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'profile_avatar.dart';

/// Avatar, name, email and (for subscribers) a Plus badge at the top of Settings and Explore's
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
            cacheKey: profile?.avatarCacheKey,
            onRefreshUrl: () => ProfileService().getMyAvatar(),
            size: 96,
            showEditLabel: false,
            fallbackIconSize: 52,
            ringColor: (profile?.isSubscribed ?? false)
                ? AppColors.accent
                : null,
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
                if (profile?.isSubscribed ?? false) ...[
                  const SizedBox(height: 8),
                  const _PlusBadge(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlusBadge extends StatelessWidget {
  const _PlusBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars, size: 18, color: AppColors.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              AppLocalizations.of(context).pointsPlusTitle,
              style: AppTextStyle.bold12.copyWith(color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
