import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/services/auth_storage.dart';
import 'login_page.dart';
import 'settings_page.dart';
import 'my_closet_page.dart';
import 'outfit_planner.dart';
import 'looks_page.dart';
import 'manual_try_on_page.dart';
import 'widgets/app_card.dart';
import 'create_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int? _selectedCardIndex;

  final List<String> _features = [
    'My Closet',
    'Planner',
    'Manual Try-on',
    'Looks',
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
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '登出',
            onPressed: () async {
              await AuthStorage.clear();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()),
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
                      width: 50,
                      height: 50,
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 50),
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
                        return AppVerticalCard(
                          label: feature,
                          iconPath: _getIconPath(feature),
                          isSelected: _selectedCardIndex == index,
                          onTap: () {
                            setState(() => _selectedCardIndex = index);
                            if (feature == 'My Closet') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const MyClosetPage()));
                            } else if (feature == 'Planner') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const OutfitPlannerPage()));
                            } else if (feature == 'Manual Try-on') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const ManualTryOnPage()));
                            } else if (feature == 'Looks') {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const LooksPage()));
                            } else if (feature == 'Finance') {
                            }
                          },
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
      ),
    );
  }

  Widget _buildQuickAddButton(BuildContext context) {
    return AppHorizontalCard(
      label: 'Create',
      iconPath: 'assets/images/create.png',
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePage())),
    );
  }

  String _getIconPath(String feature) {
    switch (feature) {
      case 'My Closet':
        return 'assets/images/my_closet.png';
      case 'Planner':
        return 'assets/images/ai_planner.png';
      case 'Manual Try-on':
        return 'assets/images/manul.png';
      case 'Looks':
        return 'assets/images/looks.png';
      case 'Finance':
        return 'assets/images/finance.png';
      default:
        return '';
    }
  }
}
