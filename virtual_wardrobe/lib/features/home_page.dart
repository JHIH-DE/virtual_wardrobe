import 'package:flutter/material.dart';
import 'login_page.dart';
import 'my_closet_page.dart';
import 'add_garment_page.dart';
import 'account_page.dart';
import '../app/theme/app_colors.dart';
import '../l10n/app_strings.dart';
import 'outfit_planner.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? selectedCardIndex;

  final List<String> features = [
    'My Closet',
    'Outfit Planner',
    'Add Garment',
    'Finance',
    'Account',
    'Share',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome back 👋',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'I picked a few ideas for you today.',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF7A6C5D),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                itemCount: features.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (context, index) {
                  bool isSelected = selectedCardIndex == index;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        selectedCardIndex = index;
                      });

                      final feature = features[index];
                      debugPrint('Tapped: $feature');

                      if (feature == 'My Closet') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyClosetPage()),
                        );
                      } else if (feature == 'Add Garment') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddGarmentPage()),
                        );
                      } else if (feature == 'Outfit Planner') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const OutfitPlannerPage()),
                        );
                      }else if (feature == 'Account') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AccountPage()),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        // Editorial：卡片以白為主，選中微微變灰（不要用 opacity 變髒）
                        color: isSelected ? const Color(0xFFF7F7F7) : AppColors.card,
                        borderRadius: BorderRadius.circular(20),

                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.55)
                              : AppColors.border,
                          width: isSelected ? 2.0 : 1.0,
                        ),

                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isSelected ? 0.06 : 0.04),
                            blurRadius: isSelected ? 14 : 10,
                            offset: Offset(0, isSelected ? 6 : 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIcon(features[index]),
                            size: 48,
                            color: isSelected ? AppColors.primary : AppColors.cardContent,
                          ),

                          Text(
                            features[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppColors.primary : AppColors.cardContent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String feature) {
    switch (feature) {
      case 'My Closet':
        return Icons.checkroom;
      case 'Outfit Planner':
        return Icons.auto_awesome;
      case 'Add Garment':
        return Icons.add_a_photo;
      case 'Finance':
        return Icons.account_balance_wallet;
      case 'Account':
        return Icons.person_outline;
      case 'Share':
        return Icons.share;
      default:
        return Icons.help_outline;
    }
  }
}