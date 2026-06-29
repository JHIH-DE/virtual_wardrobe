import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/services/auth_handler.dart';
import '../core/services/profile_service.dart';
import 'figure_setting_page.dart';
import 'personal_details_page.dart';
import '../app/theme/app_text_styles.dart';
import 'widgets/app_list_card.dart';
import 'widgets/page_app_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
      debugPrint('SettingsPage load error: $e');
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
      MaterialPageRoute(builder: (_) => const FigureSettingPage()),
    );
    _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: const PageAppBar(title: 'Setting'),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileCard(),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildFigureCard(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileCard() {
    ImageProvider? avatarProvider;
    if (_avatarUrl != null &&
        _avatarUrl!.isNotEmpty &&
        _avatarUrl != 'string') {
      avatarProvider = NetworkImage(_avatarUrl!);
    }

    return Container(
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.border,
                  backgroundImage: avatarProvider,
                  child: avatarProvider == null
                      ? const Icon(Icons.person,
                          size: 30, color: AppColors.textSecondary)
                      : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Account name',
                        style: AppTextStyle.bold14,
                      ),
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
                    width: 26,
                    height: 26,
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  Widget _buildFigureCard() {
    return AppListCard(
      onTap: _openFigureSetting,
      leadingAsset: 'assets/images/figure_setting.png',
      showArrow: true,
      summary: '$_weightLabel   $_heightLabel',
      child: const Text(
        'Figure setting',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

}
