import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/trip_plan_service.dart';
import '../core/utils/debug_log.dart';
import '../data/garment.dart';
import '../data/trip_plan.dart';
import 'trip_garment_selection_page.dart';
import 'widgets/app_dialog.dart';
import 'widgets/garment_card.dart';
import 'widgets/loading_overlay.dart';
import 'widgets/page_app_bar.dart';

class TripSuitcasePage extends ConsumerStatefulWidget {
  final TripPlan trip;

  const TripSuitcasePage({super.key, required this.trip});

  @override
  ConsumerState<TripSuitcasePage> createState() => _TripSuitcasePageState();
}

class _TripSuitcasePageState extends ConsumerState<TripSuitcasePage> {
  static const _categoryOrder = [
    GarmentCategory.top,
    GarmentCategory.bottom,
    GarmentCategory.outer,
    GarmentCategory.onePiece,
    GarmentCategory.shoes,
    GarmentCategory.socks,
    GarmentCategory.accessory,
  ];

  bool _loading = true;
  Set<int> _packedIds = {};
  final Set<int> _pendingIds = {};

  int get _tripId => int.parse(widget.trip.id);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(garmentsProvider, (_, next) {
        if (next.hasError && next.error is AuthExpiredException) {
          AuthExpiredHandler.handle(context);
        }
      });
      ref.read(garmentsProvider.notifier).refreshIfNeeded();
    });
    _loadPackedItems();
  }

  Future<void> _loadPackedItems() async {
    try {
      final data = await TripPlanService().getTripPlan(_tripId);
      final ids = <int>{};
      final rawItems = data['suitcase_items'];
      if (rawItems is List) {
        for (final item in rawItems) {
          if (item is Map && item['garment_id'] is int) {
            ids.add(item['garment_id'] as int);
          } else if (item is int) {
            ids.add(item);
          }
        }
      }
      if (mounted) setState(() => _packedIds = ids);
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to load suitcase items: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAddGarment(List<Garment> allGarments) async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
    if (!mounted) return;
    final garments = ref.read(garmentsProvider).valueOrNull ?? allGarments;

    final result = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => TripGarmentSelectionPage(
          garments: garments,
          initiallySelectedIds: _packedIds,
        ),
      ),
    );
    if (result == null) return;

    final toAdd = result.difference(_packedIds);
    final toRemove = _packedIds.difference(result);
    if (toAdd.isEmpty && toRemove.isEmpty) return;

    setState(() {
      _pendingIds.addAll(toAdd);
      _pendingIds.addAll(toRemove);
      _packedIds = result;
    });

    try {
      for (final id in toAdd) {
        await TripPlanService().addSuitcaseItem(_tripId, garmentId: id);
      }
      for (final id in toRemove) {
        await TripPlanService().removeSuitcaseItem(_tripId, garmentId: id);
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to update suitcase: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update suitcase')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _pendingIds.removeAll(toAdd);
          _pendingIds.removeAll(toRemove);
        });
      }
    }
  }

  Future<void> _confirmRemoveGarment(Garment garment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Remove garment?',
        body: '${garment.name} will be removed from your suitcase.',
        primaryLabel: 'Remove',
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (ok != true || !mounted) return;
    await _removeGarment(garment);
  }

  Future<void> _removeGarment(Garment garment) async {
    final id = garment.id;
    if (id == null || _pendingIds.contains(id)) return;

    setState(() {
      _pendingIds.add(id);
      _packedIds.remove(id);
    });

    try {
      await TripPlanService().removeSuitcaseItem(_tripId, garmentId: id);
    } catch (e) {
      if (mounted) setState(() => _packedIds.add(id));
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to remove suitcase item: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to remove item')));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final garmentsAsync = ref.watch(garmentsProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.defaultBackground,
          appBar: PageAppBar(
            title: '${widget.trip.name} Suitcase',
            backgroundColor: AppColors.surface,
          ),
          body: SafeArea(
            top: false,
            child: garmentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(e),
              data: (all) => _buildBody(all),
            ),
          ),
        ),
        if (_loading)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Suitcase...'),
          ),
      ],
    );
  }

  Widget _buildBody(List<Garment> allGarments) {
    final byId = {
      for (final g in allGarments)
        if (g.id != null) g.id!: g,
    };
    final packedGarments = _packedIds
        .map((id) => byId[id])
        .whereType<Garment>()
        .toList();

    return RefreshIndicator(
      onRefresh: _loadPackedItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            onPressed: () => _handleAddGarment(allGarments),
            icon: const Icon(Icons.add),
            label: const Text('Add Garment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (packedGarments.isEmpty)
            _buildEmptyState()
          else
            for (final category in _categoryOrder)
              ..._buildCategorySection(
                category,
                packedGarments.where((g) => g.category == category).toList(),
              ),
        ],
      ),
    );
  }

  List<Widget> _buildCategorySection(
    GarmentCategory category,
    List<Garment> garments,
  ) {
    if (garments.isEmpty) return const [];
    return [
      Text(category.label, style: AppTextStyle.bold16),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio:
              AppDimens.garmentCardWidth / AppDimens.garmentCardHeight,
        ),
        itemCount: garments.length,
        itemBuilder: (context, i) {
          final g = garments[i];
          return Stack(
            children: [
              GarmentCard(garment: g, showSelectionIndicator: false),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => _confirmRemoveGarment(g),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: AppColors.nearBlack,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.luggage_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'No garments packed yet',
              style: AppTextStyle.regular16.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object e) {
    if (e is AuthExpiredException) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(e.toString(), style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.read(garmentsProvider.notifier).refresh(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
