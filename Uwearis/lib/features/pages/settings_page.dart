import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../core/config/env.dart';
import '../../core/providers/locale_provider.dart';
import '../../core/providers/outfits_provider.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/auth_storage.dart';
import '../../core/services/profile_service.dart';
import '../../core/utils/api_error_text.dart';
import '../../core/utils/debug_log.dart';
import '../../core/utils/external_links.dart';
import '../../data/profile_data.dart';
import '../../data/user_tier.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/user_tier_localization.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/ai_consent_dialog.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/profile_avatar.dart';
import 'account_page.dart';
import 'debug_tools_page.dart';
import 'login_page.dart';
import 'my_outfit_profile_page.dart';
import 'style_taste_page.dart';

/// Tells a chosen `null` locale (System Default) apart from a dismissed
/// sheet, which also pops `null`.
enum _HelpAction { privacyPolicy, termsOfService, contactSupport }

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
  bool _deletingAccount = false;
  String? _appVersion;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => _appVersion = '${info.version} (${info.buildNumber})');
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.listenManual(profileProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException && mounted) {
          AuthExpiredHandler.handle(context);
        }
      });
    });
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  ProfileData? get _data => ref.watch(profileProvider).value;
  bool get _loading => ref.watch(profileProvider).isLoading && _data == null;

  String? get _name => _data?.profile.name;
  String? get _email => _data?.profile.email;
  String? get _avatarUrl => _data?.profile.avatarObjectUrl;
  void _openAccount() {
    // Those pages update profileProvider themselves — no reload on return.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
  }

  void _openMyOutfitProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyOutfitProfilePage()),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.logoutConfirmTitle,
        body: _l10n.logoutConfirmBody,
        primaryLabel: _l10n.logout,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed != true || !mounted) return;

    final refreshToken = await AuthStorage.getRefreshToken() ?? '';
    try {
      await AuthService().logout(refreshToken);
    } catch (e) {
      debugLog('Logout API error (ignored): $e');
    }
    if (!mounted) return;
    await clearSignedInSession();
    if (!mounted) return;
    // Providers are invalidated on the next successful login instead.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.deleteAccountConfirmTitle,
        body: _l10n.deleteAccountConfirmBody,
        primaryLabel: _l10n.deleteAccount,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (confirmed != true || _deletingAccount) return;

    setState(() => _deletingAccount = true);
    try {
      await ProfileService().deleteMyAccount();
      if (!mounted) return;
      await clearSignedInSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('SettingsPage delete account failed: $e');
      if (!mounted) return;
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.deleteAccountFailed),
      );
    } finally {
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.settings);
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _buildAccountCard(),
      _buildOutfitProfileCard(),
      _buildStyleTasteCard(),
      _buildLanguageCard(),
      _buildHelpAndLegalCard(),
      if (Env.enableDebugTools) _buildDebugToolsCard(),
      _buildLogoutCard(),
    ];
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _loading
              ? const Center(child: AppSpinner())
              : ListView(
                  children: [
                    _buildProfileCard(),
                    for (final card in cards) ...[
                      const SizedBox(height: AppDimens.sectionSpacing),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: card,
                      ),
                    ],
                    const SizedBox(height: AppDimens.sectionSpacing),
                    _buildDeleteAccountButton(),
                    const SizedBox(height: 32),
                  ],
                ),
          if (_deletingAccount)
            Positioned.fill(
              child: LoadingOverlay(label: _l10n.deletingAccount),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final url =
        (_avatarUrl != null && _avatarUrl!.isNotEmpty && _avatarUrl != 'string')
        ? _avatarUrl
        : null;
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
            ringColor: _data?.profile.tier.colors.fill,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (_name != null && _name!.isNotEmpty) ? _name! : '---',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.bold20,
                ),
                const SizedBox(height: 2),
                Text(
                  (_email != null && _email!.isNotEmpty) ? _email! : '---',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_data != null) ...[
                  const SizedBox(height: 8),
                  _TierBadge(tier: _data!.profile.tier),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(IconData icon) {
    return SizedBox.square(
      dimension: 40,
      child: Icon(icon, size: 32, color: AppColors.icon),
    );
  }

  Widget _buildAccountCard() {
    return AppListCard(
      onTap: _openAccount,
      leading: _buildLeadingIcon(LucideIcons300.user),
      showArrow: true,
      summary: _l10n.accountSummary,
      child: Text(_l10n.account, style: AppTextStyle.bold16),
    );
  }

  Widget _buildOutfitProfileCard() {
    return AppListCard(
      onTap: _openMyOutfitProfile,
      leading: _buildLeadingIcon(LucideIcons300.personStanding),
      showArrow: true,
      summary: _l10n.myOutfitProfileSummary,
      child: Text(_l10n.myOutfitProfileTitle, style: AppTextStyle.bold16),
    );
  }

  Widget _buildStyleTasteCard() {
    // Unknown (loading / failed) counts as having outfits, so the card is
    // never locked by mistake.
    final hasOutfits = ref.watch(outfitsProvider).value?.isNotEmpty ?? true;
    return AppListCard(
      enabled: hasOutfits,
      onTap: _openStyleTaste,
      leading: _buildLeadingIcon(LucideIcons300.sparkles),
      showArrow: true,
      summary: hasOutfits
          ? _l10n.styleTasteSummary
          : _l10n.styleTasteLockedSummary,
      child: Text(_l10n.styleTaste, style: AppTextStyle.bold16),
    );
  }

  /// The page's load runs the AI style analysis.
  Future<void> _openStyleTaste() async {
    if (!await ensureAiConsent(context) || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StyleTastePage()),
    );
  }

  Widget _buildLanguageCard() {
    final locale = ref.watch(localeProvider);
    return AppListCard(
      onTap: _openLanguagePicker,
      leading: _buildLeadingIcon(LucideIcons300.globe),
      showArrow: true,
      status: _localeDisplayLabel(locale),
      child: Text(_l10n.language, style: AppTextStyle.bold16),
    );
  }

  String _localeDisplayLabel(Locale? locale) {
    if (locale == null) return _l10n.languageSystemDefault;
    return locale.languageCode == 'zh'
        ? _l10n.languageTraditionalChinese
        : _l10n.languageEnglish;
  }

  Future<void> _openLanguagePicker() async {
    final current = ref.read(localeProvider);
    const options = <Locale?>[null, Locale('en'), Locale('zh', 'TW')];

    final choice = await showPickerSheet<_LanguageChoice>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PickerSheetHeader(_l10n.selectLanguageTitle),
          for (final option in options)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.language_outlined,
                color: option == current ? AppColors.accent : AppColors.icon,
              ),
              title: Text(
                _localeDisplayLabel(option),
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

  Widget _buildHelpAndLegalCard() {
    return AppListCard(
      onTap: _openHelpAndLegal,
      leading: _buildLeadingIcon(LucideIcons300.lifeBuoy),
      showArrow: true,
      summary: _appVersion == null ? null : _l10n.appVersionLabel(_appVersion!),
      child: Text(_l10n.helpAndLegal, style: AppTextStyle.bold16),
    );
  }

  Future<void> _openHelpAndLegal() async {
    Widget option(
      BuildContext sheetContext,
      _HelpAction action,
      IconData icon,
      String label,
    ) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.icon),
      title: Text(label, style: AppTextStyle.regular16),
      onTap: () => Navigator.pop(sheetContext, action),
    );

    final action = await showPickerSheet<_HelpAction>(
      context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PickerSheetHeader(_l10n.helpAndLegal),
          option(
            sheetContext,
            _HelpAction.privacyPolicy,
            LucideIcons300.shieldCheck,
            _l10n.privacyPolicy,
          ),
          option(
            sheetContext,
            _HelpAction.termsOfService,
            LucideIcons300.fileText,
            _l10n.termsOfService,
          ),
          option(
            sheetContext,
            _HelpAction.contactSupport,
            LucideIcons300.mail,
            _l10n.contactSupport,
          ),
        ],
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _HelpAction.privacyPolicy:
        await openPrivacyPolicy(context);
      case _HelpAction.termsOfService:
        await openTermsOfService(context);
      case _HelpAction.contactSupport:
        await contactSupport(context);
    }
  }

  Widget _buildDebugToolsCard() {
    return AppListCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DebugToolsPage()),
      ),
      leading: _buildLeadingIcon(LucideIcons300.bug),
      showArrow: true,
      child: Text(_l10n.debugTools, style: AppTextStyle.bold16),
    );
  }

  Widget _buildLogoutCard() {
    return AppListCard(
      onTap: _logout,
      leading: _buildLeadingIcon(LucideIcons300.logOut),
      child: Text(_l10n.logout, style: AppTextStyle.bold16),
    );
  }

  Widget _buildDeleteAccountButton() {
    return Center(
      child: TextButton.icon(
        onPressed: _deletingAccount ? null : _deleteAccount,
        style: TextButton.styleFrom(foregroundColor: AppColors.error),
        icon: const Icon(LucideIcons300.trash2),
        label: Text(
          _l10n.deleteAccount,
          style: AppTextStyle.medium16.copyWith(color: AppColors.error),
        ),
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
