import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/look.dart';

class LooksGridView extends StatelessWidget {
  final List<Look> looks;
  final Future<void> Function() onRefresh;
  final void Function(Look look) onTap;
  final String emptyMessage;

  const LooksGridView({
    super.key,
    required this.looks,
    required this.onRefresh,
    required this.onTap,
    this.emptyMessage = 'No looks yet.',
  });

  @override
  Widget build(BuildContext context) {
    if (looks.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: AppDimens.lookCardWidth / AppDimens.lookCardHeight,
        ),
        itemCount: looks.length,
        itemBuilder: (context, index) {
          final look = looks[index];
          return _LookCard(look: look, onTap: () => onTap(look));
        },
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  final Look look;
  final VoidCallback onTap;

  const _LookCard({required this.look, required this.onTap});

  String get _label {
    if (look.name != null && look.name!.isNotEmpty) return look.name!;
    final parts = [...look.style, ...look.seasons]
        .where((s) => s.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'Look #${look.id}';
    return parts.map(_capitalize).join(' ');
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: AppDimens.lookCardWidth,
        height: AppDimens.lookCardHeight,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: look.imageUrl.isNotEmpty
                        ? Image.network(
                            look.imageUrl,
                            fit: BoxFit.cover,
                            alignment: Alignment.topCenter,
                            loadingBuilder: (_, child, progress) =>
                                progress == null
                                    ? child
                                    : const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 36,
                                color: AppColors.placeholderIcon,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 36,
                              color: AppColors.placeholderIcon,
                            ),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                  child: Text(
                    _label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.bold14.copyWith(color: AppColors.nearBlack),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
