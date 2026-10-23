import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons_300.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import '../../data/profile_data.dart';
import '../../data/user_tier.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../l10n/user_tier_localization.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/app_list_card.dart';
import '../widgets/common/fields/number_stepper.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/app_dialog.dart';
import '../widgets/common/overlays/error_dialog.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/overlays/picker_sheet.dart';
import '../widgets/common/profile_avatar.dart';
import 'account_page.dart';
import 'debug_tools_page.dart';
import 'login_page.dart';
import 'my_virtual_model_page.dart';
import 'style_taste_page.dart';

/// Tells a chosen `null` locale (System Default) apart from a dismissed
/// sheet, which also pops `null`.
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

  // The backend field is write-only (not in /users/me), so the last saved
  // value is cached locally.
  static const _temperatureOffsetKey = 'temperature_offset';
  static const _minTemperatureOffset = -5;
  static const _maxTemperatureOffset = 5;
  int _temperatureOffset = 0;
  bool _savingTemperatureOffset = false;

  @override
  void initState() {
    super.initState();
    _loadTemperatureOffset();
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
  String? get _fullBodyUrl => _data?.bodyRefUrl;
  String? get _faceRefUrl => _data?.faceRefUrl;

  bool get _hasFaceReference =>
      _faceRefUrl != null && _faceRefUrl!.isNotEmpty && _faceRefUrl != 'string';

  bool get _hasBodyReference =>
      _fullBodyUrl != null &&
      _fullBodyUrl!.isNotEmpty &&
      _fullBodyUrl != 'string';

  String _aiModelStatusLabel() {
    final count = (_hasFaceReference ? 1 : 0) + (_hasBodyReference ? 1 : 0);
    return count == 2
        ? _l10n.aiModelReady
        : _l10n.aiModelReferencesAdded(count);
  }

  Future<void> _loadTemperatureOffset() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_temperatureOffsetKey);
    if (saved == null || !mounted) return;
    setState(() => _temperatureOffset = saved);
  }

  String _temperatureOffsetLabel(int offset) =>
      '${offset > 0 ? '+' : ''}$offset°C';

  /// Saves once on close rather than per tap.
  Future<void> _openTemperatureOffsetPicker() async {
    final draft = ValueNotifier(_temperatureOffset);
    await showPickerSheet<void>(
      context,
      fitContent: true,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerSheetHeader(_l10n.temperaturePreference),
          const SizedBox(height: 12),
          // Same − / + spread as Create Outfit's half-width temperature tile.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(
                constraints.maxWidth,
                math.max(
                  (constraints.maxWidth - AppDimens.cardSpacing) / 2 - 2 * 12,
                  NumberStepper.tileWidthFor(
                    context,
                    _temperatureOffsetLabel(_maxTemperatureOffset),
                  ),
                ),
              );
              return Center(
                child: SizedBox(
                  width: width,
                  child: ValueListenableBuilder<int>(
                    valueListenable: draft,
                    builder: (_, offset, _) => NumberStepper(
                      variant: NumberStepperVariant.tile,
                      valueLabel: _temperatureOffsetLabel(offset),
                      onDecrement: offset > _minTemperatureOffset
                          ? () => draft.value = offset - 1
                          : null,
                      onIncrement: offset < _maxTemperatureOffset
                          ? () => draft.value = offset + 1
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
    final selected = draft.value;
    draft.dispose();
    if (selected == _temperatureOffset || !mounted) return;
    await _saveTemperatureOffset(selected);
  }

  /// Optimistic; rolls back with a Retry offer on failure.
  Future<void> _saveTemperatureOffset(int offset) async {
    if (_savingTemperatureOffset) return;
    final previous = _temperatureOffset;
    setState(() {
      _temperatureOffset = offset;
      _savingTemperatureOffset = true;
    });
    try {
      await ProfileService().updateMyProfile(temperatureOffsetC: offset);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_temperatureOffsetKey, offset);
    } on AuthExpiredException {
      if (!mounted) return;
      setState(() => _temperatureOffset = previous);
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      debugLog('SettingsPage save temperature offset failed: $e');
      if (!mounted) return;
      setState(() => _temperatureOffset = previous);
      showErrorDialog(
        context,
        message: apiErrorMessage(_l10n, e, fallback: _l10n.profileSaveFailed),
        onRetry: () => _saveTemperatureOffset(offset),
      );
    } finally {
      if (mounted) setState(() => _savingTemperatureOffset = false);
    }
  }

  void _openAccount() {
    // Those pages update profileProvider themselves — no reload on return.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
  }

  void _openMyVirtualModel() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyVirtualModelPage()),
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
      _buildTryOnProfileCard(),
      _buildStyleTasteCard(),
      _buildTemperatureOffsetCard(),
      _buildLanguageCard(),
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

  Widget _buildTryOnProfileCard() {
    final ready = _hasFaceReference && _hasBodyReference;
    return AppListCard(
      onTap: _openMyVirtualModel,
      leadingAsset: 'assets/images/figure_setting.png',
      showArrow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_l10n.myVirtualModelTitle, style: AppTextStyle.bold16),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: ready ? AppColors.statusOngoing : AppColors.hintText,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _aiModelStatusLabel(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.regular12.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyleTasteCard() {
    // Unknown (loading / failed) counts as having outfits, so the card is
    // never locked by mistake.
    final hasOutfits = ref.watch(outfitsProvider).value?.isNotEmpty ?? true;
    return AppListCard(
      enabled: hasOutfits,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StyleTastePage()),
      ),
      leading: _buildLeadingIcon(LucideIcons300.sparkles),
      showArrow: true,
      summary: hasOutfits
          ? _l10n.styleTasteSummary
          : _l10n.styleTasteLockedSummary,
      child: Text(_l10n.styleTaste, style: AppTextStyle.bold16),
    );
  }

  Widget _buildTemperatureOffsetCard() {
    return AppListCard(
      onTap: _savingTemperatureOffset ? null : _openTemperatureOffsetPicker,
      leading: _buildLeadingIcon(LucideIcons300.thermometer),
      showArrow: true,
      status: _temperatureOffsetLabel(_temperatureOffset),
      child: Text(_l10n.temperaturePreference, style: AppTextStyle.bold16),
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
