import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/overlays/loading_overlay.dart';

/// Debug-only screen that keeps [LoadingOverlay] (and its pulse animation)
/// on screen indefinitely, so it can be eyeballed on demand instead of only
/// during a real network fetch.
class LoadingPreviewPage extends StatelessWidget {
  const LoadingPreviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: const AppToolBar(title: 'Loading Preview'),
      body: const LoadingOverlay(label: 'Loading...'),
    );
  }
}
