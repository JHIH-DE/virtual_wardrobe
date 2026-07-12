import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/utils/debug_log.dart';
import 'create_page.dart';
import 'looks_page.dart';
import 'manual_try_on_page.dart';
import 'my_closet_page.dart';
import 'settings_page.dart';
import 'trip_planner_page.dart';
import 'widgets/common/app_card.dart';
import 'widgets/common/loading_overlay.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int? _selectedCardIndex;
  bool _openingCloset = false;
  bool _openingTryOn = false;

  final List<String> _features = [
    'My Closet',
    'Trip Planner',
    'Manual Try-on',
    'Looks',
    'Finance',
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(context),
        if (_openingCloset)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Closet...'),
          ),
        if (_openingTryOn)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Garments...'),
          ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        backgroundColor: AppColors.backgroundLight,
        title: Image.asset('assets/images/logo.png', height: 60),
        actions: [
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
          ),
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
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
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
                                _handleOpenMyCloset(context);
                              } else if (feature == 'Trip Planner') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const TripPlannerPage(),
                                  ),
                                );
                              } else if (feature == 'Manual Try-on') {
                                _handleOpenManualTryOn(context);
                              } else if (feature == 'Looks') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LooksPage(),
                                  ),
                                );
                              } else if (feature == 'Finance') {}
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

  Future<void> _handleOpenMyCloset(BuildContext context) async {
    setState(() => _openingCloset = true);
    try {
      await ref.read(garmentsProvider.future);
      if (!mounted) return;
      setState(() => _openingCloset = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyClosetPage()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingCloset = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load closet: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to load closet')));
      }
    }
  }

  Future<void> _handleOpenManualTryOn(BuildContext context) async {
    setState(() => _openingTryOn = true);
    try {
      final garments = await ManualTryOnPage.preload();
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualTryOnPage(
            preloadedGarments: garments,
            onBack: () =>
                Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load garments: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load garments')),
        );
      }
    }
  }

  Widget _buildQuickAddButton(BuildContext context) {
    return AppHorizontalCard(
      label: 'Create',
      iconPath: 'assets/images/create.png',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CreatePage()),
      ),
    );
  }

  String _getIconPath(String feature) {
    switch (feature) {
      case 'My Closet':
        return 'assets/images/my_closet.png';
      case 'Trip Planner':
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
