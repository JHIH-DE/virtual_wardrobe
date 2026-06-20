import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garments_service.dart';
import '../core/services/outfit_service.dart';
import '../data/look.dart';
import '../data/garment.dart';
import 'widgets/app_card.dart';
import 'widgets/app_text_field.dart';

class ClosetLooksTab extends ConsumerStatefulWidget {
  const ClosetLooksTab({super.key});

  @override
  ConsumerState<ClosetLooksTab> createState() => _ClosetLooksTabState();
}

class _ClosetLooksTabState extends ConsumerState<ClosetLooksTab> {
  static const List<String> _seasons = ['All', 'Spring', 'Summer', 'Autumn', 'Winter'];
  static const List<String> _styles = ['All', 'Minimal', 'Street', 'Classic', 'Sporty'];

  String _selectedSeasons = 'All';
  String _selectedStyle = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(looksProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
    });
  }

  List<Look> _filtered(List<Look> all) {
    return all.where((l) {
      final okSeason = _selectedSeasons == 'All' || l.seasons == _selectedSeasons;
      final okStyle = _selectedStyle == 'All' || l.style == _selectedStyle;
      return okSeason && okStyle;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final looksAsync = ref.watch(looksProvider);

    return Container(
      color: AppColors.defaultBackground,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            title: 'Filters',
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSeasons,
                    items: _seasons
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedSeasons = v ?? _selectedSeasons),
                    decoration: appInputDecoration(label: 'Seasons'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStyle,
                    items: _styles
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedStyle = v ?? _selectedStyle),
                    decoration: appInputDecoration(label: 'Style'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: looksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                if (e is AuthExpiredException) return const SizedBox.shrink();
                return Center(child: Text(e.toString()));
              },
              data: (all) {
                final looks = _filtered(all);
                return RefreshIndicator(
                  onRefresh: () => ref.read(looksProvider.notifier).refresh(),
                  color: AppColors.primary,
                  child: _buildListContent(looks),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(List<Look> looks) {
    if (looks.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Text('No looks yet.', style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: looks.length,
      itemBuilder: (context, index) => _lookCard(context, looks[index]),
    );
  }

  Widget _lookCard(BuildContext context, Look look) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (_) => _lookDetailSheet(look),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: Colors.white,
                      child: Image.network(
                        look.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) =>
                            progress == null ? child : const Center(child: CircularProgressIndicator()),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Text('Failed to load image', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => _confirmDelete(context, look),
                        borderRadius: BorderRadius.circular(99),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.delete_outline, size: 18, color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${look.seasons} • ${look.style}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.8, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lookDetailSheet(Look look) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 0.65,
                      child: Image.network(look.imageUrl, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${look.seasons} • ${look.style}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Garment>>(
                        future: Future.wait(look.garmentIds.map((id) => GarmentService().getGarment(id))),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(height: 90, child: Center(child: CircularProgressIndicator()));
                          }
                          if (snapshot.hasError) {
                            return const SizedBox(
                              height: 90,
                              child: Center(child: Text('Failed to load garments', style: TextStyle(color: Colors.red, fontSize: 12))),
                            );
                          }
                          final garments = snapshot.data ?? [];
                          return SizedBox(
                            height: 90,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: garments.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) => _buildSmallGarmentItem(garments[i]),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _deleteLook(look.id);
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Remove'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteLook(int id) async {
    try {
      await OutfitService().deleteOutfit(id);
      ref.read(looksProvider.notifier).removeById(id);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDelete(BuildContext context, Look look) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove look?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('This look will be removed from your Looks.', style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
    if (ok == true) _deleteLook(look.id);
  }

  Widget _buildSmallGarmentItem(Garment garment) {
    final imageUrl = (garment.imageUrl != null && garment.imageUrl!.isNotEmpty)
        ? garment.imageUrl!
        : garment.uploadUrl;
    final isNetwork = imageUrl.startsWith('http');

    return InkWell(
      onTap: () => _showGarmentDetail(garment),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                child: isNetwork
                    ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity,
                        filterQuality: FilterQuality.low,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 20, color: AppColors.textSecondary)))
                    : Image.file(File(imageUrl), fit: BoxFit.cover, width: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, size: 20, color: AppColors.textSecondary))),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              ),
              child: Text(
                garment.name,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGarmentDetail(Garment garment) {
    final imageUrl = (garment.imageUrl != null && garment.imageUrl!.isNotEmpty)
        ? garment.imageUrl!
        : garment.uploadUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: imageUrl.startsWith('http')
                    ? Image.network(imageUrl, fit: BoxFit.contain)
                    : Image.file(File(imageUrl), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 20),
            Text(garment.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text('${garment.category.label} • ${garment.subCategory}',
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const Divider(height: 32),
            if (garment.brand != null) _infoRow('Brand', garment.brand!),
            if (garment.color != null) _infoRow('Color', garment.color!),
            if (garment.price != null) _infoRow('Price', '\$${garment.price!.toStringAsFixed(0)}'),
            if (garment.purchaseDate != null)
              _infoRow('Purchased', '${garment.purchaseDate!.year}/${garment.purchaseDate!.month}/${garment.purchaseDate!.day}'),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

}
