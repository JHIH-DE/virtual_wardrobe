import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme/app_colors.dart';
import '../data/garment_category.dart';
import 'account_page.dart';
import 'add_garment_page.dart';
import 'camera_capture_page.dart';
import 'login_page.dart';
import 'my_closet_page.dart';
import 'outfit_planner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _selectedCardIndex;

  final List<String> _features = [
    'My Closet',
    'Fitting Room',
    'Outfit Planner',
    'Finance',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.backgroundLight,
        title: Image.asset(
          'assets/images/logo.png',
          height: 60,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              borderRadius: BorderRadius.circular(25),
              child: Material(
                color: Colors.black,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: Center(
                    child: Image.asset(
                      'assets/images/setting.png',
                      width: 23,
                      height: 23,
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 120,
                  bottom: -180,
                  child: Image.asset(
                    'assets/images/main-character_small.png',
                    height: 450,
                  ),
                ),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'What kind of outfit\ninspiration are you in the\nmood for today?',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7A6C5D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  children: [
                    _buildQuickAddButton(context),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _features.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 18,
                        mainAxisSpacing: 18,
                        childAspectRatio: 1.0,
                      ),
                      itemBuilder: (context, index) {
                        final feature = _features[index];
                        bool isSelected = _selectedCardIndex == index;
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCardIndex = index;
                            });

                            if (feature == 'My Closet') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MyClosetPage()),
                              );
                            } else if (feature == 'Outfit Planner') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const OutfitPlannerPage()),
                              );
                            } else if (feature == 'Account') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const AccountPage()),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(32),
                          child: AnimatedScale(
                            scale: isSelected ? 0.98 : 1.0, // 縮放變小一點 (微調 0.98)
                            duration: const Duration(milliseconds: 150),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: _getBackgroundColor(feature),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  // 右下深色影子 (變淡、變小)
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    offset: const Offset(3, 3),
                                    blurRadius: 8,
                                  ),
                                  // 左上亮色高光 (變更淡)
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.5),
                                    offset: const Offset(-2, -2),
                                    blurRadius: 6,
                                  ),
                                ],
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary.withOpacity(0.4)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      _getIcon(feature),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    feature,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1A1A1A),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddButton(BuildContext context) {
    return InkWell(
      onTap: () {
        _showAddClothingDialog(context);
      },
      borderRadius: BorderRadius.circular(32),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.5),
              offset: const Offset(-2, -2),
              blurRadius: 6,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                Image.asset(
                  'assets/images/add.png',
                  height: 64,
                  width: 64,
                  fit: BoxFit.contain,
                ),
              ],
            ),
            const SizedBox(width: 16),
            const Text(
              'Quick Add Clothing',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddClothingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/add.png',
                height: 80,
                width: 80,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const Text(
                'How would you like to add a new clothing?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 24),
              _buildDialogOption(
                dialogCtx,
                icon: Icons.camera_alt_outlined,
                label: 'Camera',
                onTap: () => _onPickImage(dialogCtx, ImageSource.camera),
              ),
              const SizedBox(height: 16),
              _buildDialogOption(
                dialogCtx,
                icon: Icons.photo_library_outlined,
                label: 'Photo Album',
                onTap: () => _onPickImage(dialogCtx, ImageSource.gallery),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(dialogCtx),
                icon: const Icon(Icons.arrow_back_ios, size: 16, color: Color(0xFF1A1A1A)),
                label: const Text(
                  'Back',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogOption(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            Icon(icon, size: 28, color: const Color(0xFF1A1A1A)),
          ],
        ),
      ),
    );
  }

  Future<void> _onPickImage(BuildContext dialogContext, ImageSource source) async {
    Navigator.pop(dialogContext); // 關閉彈窗

    String? imagePath;

    if (source == ImageSource.camera) {
      // 使用自定義相機頁面
      imagePath = await Navigator.push<String>(
        context,
        MaterialPageRoute(builder: (_) => const CameraCapturePage()),
      );
    } else {
      // 使用系統相簿
      final picker = ImagePicker();
      final xFile = await picker.pickImage(source: ImageSource.gallery);
      imagePath = xFile?.path;
    }

    if (imagePath != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddGarmentPage(
            initialGarment: Garment(
              name: '',
              category: GarmentCategory.top,
              subCategory: '',
              uploadUrl: '',
              objectName: '',
              imageUrl: imagePath,
            ),
          ),
        ),
      );
    }
  }

  Color _getBackgroundColor(String feature) {
    switch (feature) {
      case 'My Closet':
        return const Color(0xFFC9FFE5);
      case 'Fitting Room':
        return const Color(0xFFFFE5D1);
      case 'Outfit Planner':
        return const Color(0xFFBDE0FF);
      case 'Finance':
        return const Color(0xFFFFC9E5);
      default:
        return Colors.white;
    }
  }

  Widget _getIcon(String feature) {
    String assetPath = '';
    switch (feature) {
      case 'My Closet':
        assetPath = 'assets/images/my_closet.png';
        break;
      case 'Fitting Room':
        assetPath = 'assets/images/fitting_room.png';
        break;
      case 'Outfit Planner':
        assetPath = 'assets/images/outfit_planner.png';
        break;
      case 'Finance':
        assetPath = 'assets/images/finance.png';
        break;
      default:
        return const Icon(Icons.help_outline, size: 40);
    }
    return Image.asset(
      assetPath,
      height: 64,
      width: 64,
      fit: BoxFit.contain,
    );
  }
}
