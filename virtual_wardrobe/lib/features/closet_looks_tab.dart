import 'dart:io';

import 'package:flutter/material.dart';
import 'package:virtual_wardrobe/core/services/outfit_service.dart';
import 'package:virtual_wardrobe/core/services/garments_service.dart';

import '../app/theme/app_colors.dart';
import '../data/look_category.dart';
import '../data/garment_category.dart';
import '../core/services/error_handler.dart';

class ClosetLooksTab extends StatefulWidget {
  const ClosetLooksTab({super.key});

  @override
  State<ClosetLooksTab> createState() => _ClosetLooksTabState();
}

class _ClosetLooksTabState extends State<ClosetLooksTab> {
  static const List<String> _seasons = [
    'All',
    'Spring',
    'Summer',
    'Autumn',
    'Winter',
  ];
  static const List<String> _styles = [
    'All',
    'Minimal',
    'Street',
    'Classic',
    'Sporty'
  ];

  bool _loading = false;
  String? _error;
  String _selectedSeasons = 'All';
  String _selectedStyle = 'All';

  List<Look> get _filteredLooks {
    return LooksStore.I.looks.where((l) {
      final okSeasons = _selectedSeasons == 'All' ||
          l.seasons == _selectedSeasons;
      final okStyle = _selectedStyle == 'All' || l.style == _selectedStyle;
      return okSeasons && okStyle;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _getOutfits();
  }

  Future<void> _getOutfits() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await OutfitService().getOutfits();
      if (!mounted) return;
      LooksStore.I.setLooks(list);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteOutfit(int jobId) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await OutfitService().deleteOutfit(jobId);
      if (!mounted) return;
      LooksStore.I.removeById(jobId);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.all(16),
      child: AnimatedBuilder(
        animation: LooksStore.I,
        builder: (context, _) {
          final looks = _filteredLooks;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionCard(
                title: 'Filters',
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedSeasons,
                        items: _seasons
                            .map((v) =>
                            DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() =>
                            _selectedSeasons = v ?? _selectedSeasons),
                        decoration: _inputDecoration(label: 'Seasons'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStyle,
                        items: _styles
                            .map((v) =>
                            DropdownMenuItem(value: v, child: Text(v)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedStyle = v ?? _selectedStyle),
                        decoration: _inputDecoration(label: 'Style'),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _getOutfits,
                  color: AppColors.primary,
                  child: _buildListContent(looks),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListContent(List<Look> looks) {
    if (_loading && looks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (looks.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Text(
            'No looks yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
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
      itemBuilder: (context, index) {
        final look = looks[index];
        return _lookCard(context, look);
      },
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
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
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
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                              child: CircularProgressIndicator());
                        },
                        errorBuilder: (context, error, stack) {
                          return const Center(
                            child: Text(
                              'Failed to load image',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          );
                        },
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
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 10),
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
                        style: const TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 18,
                        color: AppColors.textSecondary),
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
                      child: Image.network(
                        look.imageUrl,
                        fit: BoxFit.cover,
                      ),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 12),

                      FutureBuilder<List<Garment>>(
                        future: Future.wait(look.garmentIds.map((id) => GarmentService().getGarment(id))),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              height: 90,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          
                          if (snapshot.hasError) {
                            if (snapshot.error is AuthExpiredException) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                AuthExpiredHandler.handle(context);
                              });
                            }
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
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              itemCount: garments.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final garment = garments[index];
                                return _buildSmallGarmentItem(garment.category.label, garment);
                              },
                            ),
                          );
                        }
                      ),

                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _deleteOutfit(look.id);
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textPrimary,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
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
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16),
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

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      filled: true,
      fillColor: AppColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Look look) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Remove look?',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700),
            ),
            content: const Text(
              'This look will be removed from your Looks.',
              style: TextStyle(color: AppColors.textSecondary),
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
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
    );

    if (ok == true) {
      _deleteOutfit(look.id);
    }
  }

  Widget _buildSmallGarmentItem(String label, Garment garment) {
    final String imageUrl = (garment.imageUrl != null && garment.imageUrl!.isNotEmpty)
        ? garment.imageUrl!
        : garment.uploadUrl;

    final bool isNetwork = imageUrl.startsWith('http');

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
                    ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, size: 20, color: AppColors.textSecondary),
                    );
                  },
                )
                    : Image.file(
                  File(imageUrl),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image, size: 20, color: AppColors.textSecondary),
                  ),
                ),
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
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGarmentDetail(Garment garment) {
    final String imageUrl = (garment.imageUrl != null && garment.imageUrl!.isNotEmpty)
        ? garment.imageUrl!
        : garment.uploadUrl;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
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
            Text(
              garment.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '${garment.category.label} • ${garment.subCategory}',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
            ),
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
