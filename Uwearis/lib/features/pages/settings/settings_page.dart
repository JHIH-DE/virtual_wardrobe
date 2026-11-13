import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/config/app_config.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/outfits_provider.dart';
import '../../../core/providers/points_provider.dart';
import '../../../core/providers/profile_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/auth_storage.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/utils/analytics.dart';
import '../../../core/utils/api_error_text.dart';
import '../../../core/utils/debug_log.dart';
import '../../../core/utils/external_links.dart';
import '../../../core/utils/user_acknowledgement.dart';
import '../../../data/profile_data.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../widgets/common/app_tool_bar.dart';
import '../../widgets/common/cards/app_list_card.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/overlays/ai_consent_dialog.dart';
import '../../widgets/common/overlays/app_dialog.dart';
import '../../widgets/common/overlays/app_snack_bar.dart';
import '../../widgets/common/overlays/error_dialog.dart';
import '../../widgets/common/overlays/loading_overlay.dart';
import '../../widgets/common/overlays/picker_sheet.dart';
import '../../widgets/common/profile_summary_header.dart';
import '../common/debug_tools_page.dart';
import '../common/login_page.dart';
import 'my_outfit_profile_page.dart';
import 'personal_details_page.dart';
import 'points_page.dart';
import 'style_taste_page.dart';

/// Tells a chosen `null` locale (System Default) apart from a dismissed
/// sheet, which also pops `null`.
enum _HelpAction {
  privacyPolicy,
  termsOfService,
  contactSupport,
  withdrawAiConsent,
}

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

  void _openPersonalDetails() {
    // Those pages update profileProvider themselves — no reload on return.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalDetailsPage()),
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
      ),
    );
    if (confirmed != true || _deletingAccount) return;

    setState(() => _deletingAccount = true);
    try {
      await ProfileService().deleteMyAccount();
      await Analytics.resetData();
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
      _buildPersonalDetailsCard(),
      _buildPointsCard(),
      _buildOutfitProfileCard(),
      _buildStyleTasteCard(),
      _buildLanguageCard(),
      _buildHelpAndLegalCard(),
      if (AppConfig.enableDebugTools) _buildDebugToolsCard(),
      _buildLogoutCard(),
      _buildDeleteAccountCard(),
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
                    ProfileSummaryHeader(data: _data),
                    for (final card in cards) ...[
                      const SizedBox(height: AppDimens.sectionSpacing),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: card,
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
          if (_deletingAccount)
            Positioned.fill(
              child: LoadingOverlay(label: _l10n.deletingAccountEllipsis),
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

  Widget _buildPointsCard() {
    final balance = ref.watch(pointsProvider).value?.balance;
    return AppListCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PointsPage()),
      ),
      leading: _buildLeadingIcon(LucideIcons300.coins),
      showArrow: true,
      summary: balance == null
          ? null
          : NumberFormat.decimalPattern(_l10n.localeName).format(balance),
      child: Text(_l10n.uwearisPoints, style: AppTextStyle.bold16),
    );
  }

  Widget _buildPersonalDetailsCard() {
    return AppListCard(
      onTap: _openPersonalDetails,
      leading: _buildLeadingIcon(LucideIcons300.user),
      showArrow: true,
      child: Text(_l10n.personalDetails, style: AppTextStyle.bold16),
    );
  }

  Widget _buildOutfitProfileCard() {
    return AppListCard(
      onTap: _openMyOutfitProfile,
      leading: _buildLeadingIcon(LucideIcons300.personStanding),
      showArrow: true,
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
      summary: _localeDisplayLabel(locale),
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
    final aiConsentGranted = await UserAcknowledgement.aiConsent.isGranted();
    if (!mounted) return;
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
          if (aiConsentGranted)
            option(
              sheetContext,
              _HelpAction.withdrawAiConsent,
              LucideIcons300.sparkles,
              _l10n.withdrawAiConsent,
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
      case _HelpAction.withdrawAiConsent:
        await _withdrawAiConsent();
    }
  }

  Future<void> _withdrawAiConsent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.withdrawAiConsentConfirmTitle,
        body: _l10n.withdrawAiConsentConfirmBody,
        primaryLabel: _l10n.withdrawAiConsentConfirm,
        onPrimary: () => Navigator.pop(ctx, true),
      ),
    );
    if (confirmed != true || !mounted) return;
    await UserAcknowledgement.aiConsent.revoke();
    if (!mounted) return;
    showAppSnackBar(context, _l10n.aiConsentWithdrawn);
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
      showArrow: true,
      child: Text(_l10n.logout, style: AppTextStyle.bold16),
    );
  }

  Widget _buildDeleteAccountCard() {
    return AppListCard(
      onTap: _deleteAccount,
      leading: _buildLeadingIcon(LucideIcons300.trash2),
      showArrow: true,
      child: Text(_l10n.deleteAccount, style: AppTextStyle.bold16),
    );
  }
}
