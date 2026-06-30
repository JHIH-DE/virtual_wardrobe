import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garments_service.dart';
import '../core/services/looks_service.dart';
import '../data/garment.dart';
import '../data/look.dart';
import 'widgets/full_screen_image_page.dart';
import 'widgets/garment_list_card.dart';
import 'widgets/page_app_bar.dart';

class LooksDetailsPage extends ConsumerStatefulWidget {
  final Look look;
  final bool isNew;

  const LooksDetailsPage({
    super.key,
    required this.look,
    this.isNew = false,
  });

  @override
  ConsumerState<LooksDetailsPage> createState() => _LooksDetailsPageState();
}

class _LooksDetailsPageState extends ConsumerState<LooksDetailsPage> {
  bool _saved = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  List<Garment>? _garments;
  bool _loadingGarments = false;

  @override
  void initState() {
    super.initState();
    if (widget.look.garmentIds.isNotEmpty) _loadGarments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: 'Details',
        actions: [
          if (widget.isNew)
            TextButton(
              onPressed: _saved ? null : _discard,
              child: Text(
                'Discard',
                style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
              ),
            )
          else
            IconButton(
              icon: Image.asset(
                'assets/images/delete.png',
                height: 28,
              ),
              onPressed: _isDeleting ? null : _deleteLook,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const SizedBox(height: 4),
            const Divider(height: 1, thickness: 6, color: AppColors.defaultDivider),
            _buildInfoCard(),
            const Divider(height: 1, thickness: 2, color: AppColors.defaultDivider),
            const SizedBox(height: 16),
            _buildTitleRow(),
            const SizedBox(height: 16),
            _buildOutfitImage(),
            if (widget.look.garmentIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildGarmentSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    final seasonText = widget.look.seasons.isNotEmpty
        ? widget.look.seasons.join(' / ')
        : 'My Collection';
    final styleText = widget.look.style.isNotEmpty
        ? widget.look.style.join(' / ')
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(seasonText, style: AppTextStyle.bold14),
                  if (styleText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      styleText,
                      style: AppTextStyle.regular12.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 1,
              color: AppColors.textBoxBorder,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Create Date',
                  style: AppTextStyle.regular12.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(_formattedDate, style: AppTextStyle.bold14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Text(_title, style: AppTextStyle.title18),
        const Spacer(),
        const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
      ],
    );
  }

  Widget _buildOutfitImage() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => FullScreenImagePage(imageUrl: widget.look.imageUrl),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Hero(
            tag: 'outfit_image_${widget.look.id}',
            child: Image.network(
              widget.look.imageUrl,
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
    );
  }

  Widget _buildGarmentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 2, color: AppColors.defaultDivider),
        const SizedBox(height: 16),
        if (_loadingGarments)
          const Center(child: CircularProgressIndicator())
        else if (_garments != null)
          ...(_garments!.map((g) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GarmentListCard(garment: g),
          ))),
      ],
    );
  }

  Future<void> _loadGarments() async {
    setState(() => _loadingGarments = true);
    try {
      final results = await Future.wait(
        widget.look.garmentIds.map((id) => GarmentService().getGarment(id)),
      );
      if (mounted) setState(() => _garments = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGarments = false);
    }
  }

  Future<void> _saveLook() async {
    setState(() => _isSaving = true);
    try {
      ref.read(looksProvider.notifier).add(widget.look);
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
      await LookService().deleteLook(widget.look.id);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteLook() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove look?', style: AppTextStyle.bold16),
        content: Text(
          'This look will be removed from your Looks.',
          style: AppTextStyle.regular14.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await LookService().deleteLook(widget.look.id);
      ref.read(looksProvider.notifier).removeById(widget.look.id);
      if (mounted) Navigator.pop(context);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String get _title {
    final parts = [...widget.look.seasons, ...widget.look.style];
    if (parts.isEmpty) return 'My Look';
    return '${parts.first} Outfit';
  }

  String get _formattedDate {
    final d = widget.look.createdAt;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

}
