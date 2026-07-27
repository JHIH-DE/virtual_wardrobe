import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/locale_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/auth_service.dart';
import '../core/services/auth_storage.dart';
import '../core/services/profile_service.dart';
import '../core/utils/debug_log.dart';
import '../l10n/generated/app_localizations.dart';
import 'body_profile_page.dart';
import 'lifestyle_page.dart';
import 'login_page.dart';
import 'personal_details_page.dart';
import 'style_profile_page.dart';
import 'widgets/common/app_list_card.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/picker_sheet.dart';
import 'widgets/common/profile_avatar.dart';

/// Wraps the bottom sheet's chosen locale so a `null` result (System
/// Default, itself a valid choice) can be told apart from the sheet being
/// dismissed without a choice (which also pops `null`).
class _LanguageChoice {
  final Locale? locale;
  const _LanguageChoice(this.locale);
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
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
                  child: _buildLifestyleCard(l10n),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLanguageCard(l10n),
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
        MaterialPageRoute(builder: (_) => const StyleProfilePage()),
      ),
      leading: const Icon(Icons.style_outlined, color: AppColors.icon),
      showArrow: true,
      child: Text(l10n.styleProfile, style: AppTextStyle.bold16),
    );
  }

  Widget _buildLifestyleCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LifestylePage()),
      ),
      leadingAsset: 'assets/images/daily_planner.png',
      showArrow: true,
      child: Text(l10n.lifestyle, style: AppTextStyle.bold16),
    );
  }

  Widget _buildLanguageCard(AppLocalizations l10n) {
    final locale = ref.watch(localeProvider);
    return AppListCard(
      onTap: () => _openLanguagePicker(l10n),
      leading: const Icon(Icons.language_outlined, color: AppColors.icon),
      showArrow: true,
      summary: _localeDisplayLabel(locale, l10n),
      child: Text(l10n.language, style: AppTextStyle.bold16),
    );
  }

  String _localeDisplayLabel(Locale? locale, AppLocalizations l10n) {
    if (locale == null) return l10n.languageSystemDefault;
    return locale.languageCode == 'zh'
        ? l10n.languageTraditionalChinese
        : l10n.languageEnglish;
  }

  Future<void> _openLanguagePicker(AppLocalizations l10n) async {
    final current = ref.read(localeProvider);
    const options = <Locale?>[null, Locale('en'), Locale('zh', 'TW')];

    final choice = await showPickerSheet<_LanguageChoice>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PickerSheetHeader(l10n.selectLanguageTitle),
          for (final option in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.language_outlined,
                color: option == current ? AppColors.accent : AppColors.icon,
              ),
              title: Text(
                _localeDisplayLabel(option, l10n),
                style: option == current
                    ? AppTextStyle.semibold16.copyWith(color: AppColors.accent)
                    : AppTextStyle.regular16,
              ),
              trailing: option == current
                  ? const Icon(Icons.check, color: AppColors.accent)
                  : null,
              onTap: () => Navigator.pop(sheetContext, _LanguageChoice(option)),
            ),
        ],
      ),
    );

    if (choice == null || choice.locale == current) return;
    ref.read(localeProvider.notifier).setLocale(choice.locale);
  }

  Widget _buildLogoutCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: _logout,
      leadingAsset: 'assets/images/logout.png',
      child: Text(l10n.logout, style: AppTextStyle.bold16),
    );
  }
}
