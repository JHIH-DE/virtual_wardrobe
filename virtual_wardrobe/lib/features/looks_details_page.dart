import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/looks_service.dart';
import '../data/look.dart';
import 'widgets/app_list_card.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/full_screen_image_page.dart';
import 'widgets/page_app_bar.dart';

class LooksDetailsPage extends ConsumerStatefulWidget {
  final String imageUrl;
  final String? aiAdvice;
  final int jobId;

  const LooksDetailsPage({
    super.key,
    required this.imageUrl,
    this.aiAdvice,
    required this.jobId,
  });

  @override
  ConsumerState<LooksDetailsPage> createState() => _LooksDetailsPageState();
}

class _LooksDetailsPageState extends ConsumerState<LooksDetailsPage> {
  bool _saved = false;
  bool _isSaving = false;

  Future<void> _saveLook() async {
    setState(() => _isSaving = true);
    try {
      ref.read(looksProvider.notifier).add(Look(
        id: widget.jobId,
        imageUrl: widget.imageUrl,
        seasons: const [],
        style: const [],
        advice: widget.aiAdvice,
      ));
      setState(() => _saved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved ✅')),
        );
        Navigator.pop(context);
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _discard() async {
    try {
      await LookService().deleteLook(widget.jobId);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: 'Try-On Result',
        actions: [
          TextButton(
            onPressed: _saved ? null : _discard,
            child: Text(
              'Discard',
              style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).push(PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => FullScreenImagePage(imageUrl: widget.imageUrl),
              )),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Hero(
                    tag: 'outfit_image',
                    child: Image.network(
                      widget.imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) =>
                          progress == null ? child : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          'Failed to load image',
                          style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.aiAdvice != null) ...[
              const SizedBox(height: 20),
              AppListCard(
                title: 'AI Styling Notes',
                child: Text(
                  widget.aiAdvice!,
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: BottomActionButton(
        label: 'Save Look',
        onPressed: _saveLook,
        enabled: !_saved && !_isSaving,
        isLoading: _isSaving,
      ),
    );
  }
}
