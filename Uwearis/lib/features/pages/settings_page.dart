import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/auth_storage.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/debug_log.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/profile_avatar.dart';
import 'account_page.dart';
import 'lifestyle_page.dart';
import 'login_page.dart';
import 'style_taste_page.dart';
import 'tryon_profile_page.dart';

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
  String? _email;
  // Read-only here — editing the avatar now happens on AccountPage; this
  // just mirrors whatever's saved there.
  String? _avatarUrl;
  String? _fullBodyUrl;
  String? _faceRefUrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ProfileService().getMyProfile(),
        ProfileService().getBodyRef(),
        ProfileService().getFaceReference(),
      ]);
      if (!mounted) return;
      final profile = results[0] as Map<String, dynamic>;
      final fullBodyUrl = results[1] as String?;
      final faceRefUrl = results[2] as String?;
      setState(() {
        _name = profile['name'] as String?;
        _email = profile['email'] as String?;
        _avatarUrl = profile['avatar_object_url'] as String?;
        _fullBodyUrl = fullBodyUrl;
        _faceRefUrl = faceRefUrl;
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

  bool get _hasFaceReference =>
      _faceRefUrl != null && _faceRefUrl!.isNotEmpty && _faceRefUrl != 'string';

  bool get _hasBodyReference =>
      _fullBodyUrl != null &&
      _fullBodyUrl!.isNotEmpty &&
      _fullBodyUrl != 'string';

  String _aiModelStatusLabel(AppLocalizations l10n) {
    final count = (_hasFaceReference ? 1 : 0) + (_hasBodyReference ? 1 : 0);
    return count == 2 ? l10n.aiModelReady : l10n.aiModelReferencesAdded(count);
  }

  Future<void> _openAccount() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
    _loadProfile();
  }

  Future<void> _openTryOnProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TryonProfilePage()),
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
          ? const Center(child: AppSpinner())
          : ListView(
              children: [
                _buildProfileCard(l10n),
                const SizedBox(height: AppDimens.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildAccountCard(l10n),
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildTryOnProfileCard(l10n),
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStyleTasteCard(l10n),
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLifestyleCard(l10n),
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildLanguageCard(l10n),
                ),
                const SizedBox(height: AppDimens.sectionSpacing),
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
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          // Read-only — see AccountPage for the editable version.
          ProfileAvatar(image: avatarProvider, size: 120, showEditLabel: false),
          const SizedBox(height: 16),
          Text(
            (_name != null && _name!.isNotEmpty) ? _name! : '---',
            style: AppTextStyle.bold20,
          ),
          const SizedBox(height: 4),
          Text(
            (_email != null && _email!.isNotEmpty) ? _email! : '---',
            style: AppTextStyle.regular14.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: _openAccount,
      leadingAsset: 'assets/images/account.png',
      showArrow: true,
      child: Text(l10n.account, style: AppTextStyle.bold16),
    );
  }

  Widget _buildTryOnProfileCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: _openTryOnProfile,
      leadingAsset: 'assets/images/figure_setting.png',
      showArrow: true,
      summary: _aiModelStatusLabel(l10n),
      child: Text(l10n.aiModel, style: AppTextStyle.bold16),
    );
  }

  Widget _buildStyleTasteCard(AppLocalizations l10n) {
    return AppListCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StyleTastePage()),
      ),
      leading: const Icon(Icons.auto_awesome_outlined, color: AppColors.icon),
      showArrow: true,
      summary: l10n.styleTasteSummary,
      child: Text(l10n.styleTaste, style: AppTextStyle.bold16),
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
