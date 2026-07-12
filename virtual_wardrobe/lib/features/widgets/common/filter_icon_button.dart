import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Filter icon with a small dot badge in the corner when a filter is active.
class FilterIconButton extends StatelessWidget {
  final bool isFiltered;
  final VoidCallback onPressed;

  const FilterIconButton({
    super.key,
    required this.isFiltered,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: const Icon(Icons.filter_list), onPressed: onPressed),
        if (isFiltered)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
