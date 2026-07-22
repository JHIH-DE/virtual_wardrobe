import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/auth_service.dart';
import '../core/services/auth_storage.dart';
import '../core/services/profile_service.dart';
import '../core/utils/debug_log.dart';
import '../l10n/generated/app_localizations.dart';
import 'body_profile_page.dart';
import 'daily_preferences_page.dart';
import 'login_page.dart';
import 'personal_details_page.dart';
import 'style_preferences_page.dart';
import 'widgets/common/app_list_card.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/profile_avatar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Profile
  String? _name;
  String? _avatarUrl;
  double? _weight;
  double? _height;
  String _unitSystem = 'metric';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final profile = await ProfileService().getMyProfile();
      if (!mounted) return;
      setState(() {
        _name = profile['name'] as String?;
        _avatarUrl = profile['avatar_object_url'] as String?;
        _unitSystem = (profile['unit_system'] ?? 'metric') as String;
        _weight = profile['weight'] != null
            ? (profile['weight'] as num).toDouble()
            : null;
        _height = profile['height'] != null
            ? (profile['height'] as num).toDouble()
            : null;
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('SettingsPage load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _weightLabel {
    if (_weight == null) return '---';
    return _unitSystem == 'metric'
        ? '${_weight!.toStringAsFixed(0)} kg'
        : '${_weight!.toStringAsFixed(0)} lb';
  }

  String get _heightLabel {
    if (_height == null) return '---';
    return _unitSystem == 'metric'
        ? '${_height!.toStringAsFixed(0)} cm'
        : '${_height!.toStringAsFixed(0)} in';
  }

  Future<void> _openPersonalDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalDetailsPage()),
    );
    _loadProfile();
  }

  Future<void> _openFigureSetting() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BodyProfilePage()),
    );
    _loadProfile();
  }

  Future<void> _logout() async {
    final refreshToken = await AuthStorage.getRefreshToken() ?? '';
    try {
      await AuthService().logout(refreshToken);
    } catch (e) {
      debugLog('Logout API error (ignored): $e');
    }
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  AppToolBar _buildAppBar(AppLocalizations l10n) {
    return AppToolBar(title: l10n.settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(l10n),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _buildProfileCard(l10n),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildFigureCard(l10n),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildOutfitStyleCard(l10n),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildDailyOutfitCard(l10n),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLogoutCard(l10n),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _buildProfileCard(AppLocalizations l10n) {
    ImageProvider? avatarProvider;
    if (_avatarUrl != null &&
        _avatarUrl!.isNotEmpty &&
        _avatarUrl != 'string') {
      avatarProvider = NetworkImage(_avatarUrl!);
    }
    return Container(
      color: AppColors.pageBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AppColors.borderSubtle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                ProfileAvatar(
                  image: avatarProvider,
                  size: 72,
                  showEditLabel: false,
                  fallbackIconSize: 30,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.accountNameLabel, style: AppTextStyle.bold14),
                      const SizedBox(height: 3),
                      Text(
                        (_name != null && _name!.isNotEmpty) ? _name! : '---',
                        style: AppTextStyle.bold20,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _openPersonalDetails,
                  child: Image.asset(
                    'assets/images/edit.png',
                    height: AppDimens.iconMediumSize,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.borderSubtle),
        ],
      ),
    );
  }

  Widget _buildFigureCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: _openFigureSetting,
      leadingAsset: 'assets/images/figure_setting.png',
      showArrow: true,
      summary: '$_weightLabel   $_heightLabel',
      child: Text(l10n.bodyProfile, style: AppTextStyle.bold16),
    );
  }

  Widget _buildOutfitStyleCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StylePreferencesPage()),
      ),
      leading: const Icon(Icons.style_outlined, color: AppColors.icon),
      showArrow: true,
      child: Text(l10n.styleProfile, style: AppTextStyle.bold16),
    );
  }

  Widget _buildDailyOutfitCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DailyPreferencesPage()),
      ),
      leadingAsset: 'assets/images/daily_planner.png',
      showArrow: true,
      child: Text(l10n.dailyPreferences, style: AppTextStyle.bold16),
    );
  }

  Widget _buildLogoutCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: _logout,
      leadingAsset: 'assets/images/logout.png',
      child: Text(l10n.logout, style: AppTextStyle.bold16),
    );
  }
}
