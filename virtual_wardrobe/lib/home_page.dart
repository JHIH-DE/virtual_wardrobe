import 'package:flutter/material.dart';
import 'login_page.dart';
import 'my_closet_page.dart';
import 'add_garment_page.dart';
import 'theme/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? selectedCardIndex;

  final List<String> features = [
    'My Closet',
    'Styling Tips',
    'Add Item',
    'Insights',
    'Account',
    'Share with Friends',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Virtual Wardrobe'),
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
              'Manage your wardrobe and explore new styling ideas.',
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
                      } else if (feature == 'Add Item') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AddGarmentPage()),
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
                          width: isSelected ? 1.6 : 1.0,
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
      case 'Styling Tips':
        return Icons.style;
      case 'Add Item':
        return Icons.add_a_photo;
      case 'Insights':
        return Icons.analytics;
      case 'Account':
        return Icons.person_outline;
      case 'Share with Friends':
        return Icons.share;
      default:
        return Icons.help_outline;
    }
  }
}