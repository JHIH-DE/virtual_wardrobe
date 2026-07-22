import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/services/auth_handler.dart';
import '../core/services/profile_service.dart';
import 'personal_details_page.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';

/// Style label -> its illustration, per gender bucket — Male and Female
/// need different photos for the same style label (e.g. "Streetwear" shows
/// a male model under 'Male', a female model under 'Female'). Missing
/// entries (no matching asset shot for that gender yet) fall back to
/// [_stylePlaceholderImage].
const Map<String, Map<String, String>> _styleImagesByGender = {
  // The only photoshoot so far is male-modeled, so these are the 'Male' set.
  'Male': {
    'Minimalist': 'assets/images/male_minimalist.png',
    'City Boy': 'assets/images/male_city_boy.png',
    'Streetwear': 'assets/images/male_streetwear.png',
    'Smart Casual': 'assets/images/male_smart_casual.png',
    'Workwear': 'assets/images/male_workwear.png',
    'Athleisure': 'assets/images/male_athleisure.png',
    'Old Money': 'assets/images/male_old_money.png',
    'Vintage': 'assets/images/male_vintage.png',
    'Outdoor': 'assets/images/male_outdoor.png',
    'Techwear': 'assets/images/male_techwear.png',
  },
  // No female-modeled shoot yet — every entry falls back to the
  // placeholder until dedicated assets exist.
  'Female': {
    'Minimalist': 'assets/images/female_minimalist.png',
    'Korean': 'assets/images/female_korean.png',
    'Streetwear': 'assets/images/female_streetwear.png',
    'Smart Casual': 'assets/images/female_smart_casual.png',
    'Chic': 'assets/images/female_chic.png',
    'Athleisure': 'assets/images/female_athleisure.png',
    'Old Money': 'assets/images/female_old_money.png',
    'Romantic': 'assets/images/female_romantic.png',
    'Vintage': 'assets/images/female_vintage.png',
    'Bohemian': 'assets/images/female_bohemian.png',
  },
  // See the Other-bucket note below before adding assets here.
  'Other': {},
};

const String _stylePlaceholderImage = 'assets/images/vintage.png';

String _imageForStyle(String? styleGender, String style) =>
    _styleImagesByGender[styleGender]?[style] ?? _stylePlaceholderImage;

/// Style tags shown per gender. Editorial placeholder list — swap in
/// whatever taxonomy the backend actually wants to store/recommend against.
const Map<String, List<String>> _styleOptionsByGender = {
  'Male': [
    'Minimalist',
    'City Boy',
    'Streetwear',
    'Smart Casual',
    'Workwear',
    'Athleisure',
    'Old Money',
    'Vintage',
    'Outdoor',
    'Techwear',
  ],

  'Female': [
    'Minimalist',
    'Korean',
    'Streetwear',
    'Smart Casual',
    'Chic',
    'Athleisure',
    'Old Money',
    'Romantic',
    'Vintage',
    'Bohemian',
  ],

  'Other': [
    'Minimalist',
    'Streetwear',
    'Smart Casual',
    'Athleisure',
    'Vintage',
    'Workwear',
    'Techwear',
    'Outdoor',
  ],
};

/// Personal Details' gender options don't map 1:1 onto the style catalog
/// above ("Prefer not to say" has no dedicated tag set) — this resolves a
/// profile gender to the catalog key to actually show, or null if the user
/// hasn't set a gender yet.
String? _styleGenderFor(String? profileGender) {
  switch (profileGender) {
    case 'Male':
      return 'Male';
    case 'Female':
      return 'Female';
    case 'Other':
    case 'Prefer not to say':
      return 'Other';
    default:
      return null;
  }
}

class StylePreferencesPage extends StatefulWidget {
  const StylePreferencesPage({super.key});

  @override
  State<StylePreferencesPage> createState() => _StylePreferencesPageState();
}

class _StylePreferencesPageState extends State<StylePreferencesPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _profileGender;
  Set<String> _selectedStyles = {};
  Set<String> _initialStyles = {};

  String? get _styleGender => _styleGenderFor(_profileGender);

  List<String> get _availableStyles =>
      _styleOptionsByGender[_styleGender] ?? const [];

  bool get _isModified => !setEquals(_selectedStyles, _initialStyles);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ProfileService().getMyProfile();
      final savedStyle = await ProfileService().getMyStyle();
      if (!mounted) return;
      setState(() {
        _profileGender = profile['gender'] as String?;
        final validStyles = _styleOptionsByGender[_styleGender] ?? const [];
        _selectedStyles = savedStyle != null
            ? savedStyle.toSet().intersection(validStyles.toSet())
            : {};
        _initialStyles = Set.of(_selectedStyles);
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileService().updateMyProfile(style: _selectedStyles.toList());
      if (!mounted) return;
      Navigator.pop(context);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openPersonalDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalDetailsPage()),
    );
    // Gender may have just been set/changed — refresh so the style list
    // reflects it.
    _loadProfile();
  }

  void _toggleStyle(String style) {
    setState(() {
      if (_selectedStyles.contains(style)) {
        _selectedStyles.remove(style);
      } else {
        _selectedStyles.add(style);
      }
    });
  }

  AppToolBar _buildAppBar() {
    return const AppToolBar(title: 'Personal Style');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      extendBody: true,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _styleGender == null
          ? _buildNoGenderState()
          : _buildStyleForm(),
      bottomNavigationBar: _loading || _styleGender == null
          ? null
          : BottomActionButton(
              label: 'Save',
              onPressed: _save,
              isLoading: _saving,
              enabled: _isModified,
            ),
    );
  }

  Widget _buildNoGenderState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined, size: 40, color: AppColors.icon),
            const SizedBox(height: 16),
            Text(
              'Set your gender in Personal Details first — style tags are '
              'picked based on it.',
              textAlign: TextAlign.center,
              style: AppTextStyle.regular14.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _openPersonalDetails,
              child: const Text('Open Personal Details'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStyleForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) _buildErrorBanner(),
          Text(
            'Pick the styles you like — we\'ll personalize your recommendations.',
            textAlign: TextAlign.center,
            style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          _buildStyleChips(),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        _error!,
        style: AppTextStyle.regular13.copyWith(color: AppColors.error),
      ),
    );
  }

  Widget _buildStyleChips() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: AppDimens.lookCardHeight,
      ),
      itemCount: _availableStyles.length,
      itemBuilder: (context, i) => _buildStyleCard(_availableStyles[i]),
    );
  }

  // Mirrors LookCard's look (see widgets/look/look_card.dart) — full-bleed
  // image over a label — with a GarmentCard-style selection badge added on
  // top for the Create Look-style picking interaction.
  Widget _buildStyleCard(String style) {
    final isSelected = _selectedStyles.contains(style);

    return GestureDetector(
      onTap: () => _toggleStyle(style),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowResting,
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        foregroundDecoration: isSelected
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderStrong, width: 1.5),
              )
            : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: AppColors.surface,
                      child: Image.asset(
                        _imageForStyle(_styleGender, style),
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.styleSelected
                              : AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadowResting,
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: AppColors.textOnPrimary,
                                size: 14,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Text(
                  style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.bold14.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
