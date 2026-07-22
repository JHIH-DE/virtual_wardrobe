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
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/removable_card.dart';
import 'widgets/common/empty_state_placeholder.dart';
import 'widgets/common/error_state_widget.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/common/primary_action_button.dart';
import 'widgets/garment/garment_card.dart';

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
  final _deleteGroup = RemovableCardGroup();

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
      final ids = _parseSuitcaseItemIds(data['suitcase_items']);
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

  Set<int> _parseSuitcaseItemIds(dynamic rawItems) {
    final ids = <int>{};
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map && item['garment_id'] is int) {
          ids.add(item['garment_id'] as int);
        } else if (item is int) {
          ids.add(item);
        }
      }
    }
    return ids;
  }

  Future<void> _handleAddGarment(List<Garment> allGarments) async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
    if (!mounted) return;
    final garments = ref.read(garmentsProvider).valueOrNull ?? allGarments;

    final result = await Navigator.push<Set<int>>(
      context,
      MaterialPageRoute(
        builder: (_) => TripGarmentSelectionPage(
          tripId: _tripId,
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

  AppToolBar _buildAppBar() {
    return AppToolBar(title: '${widget.trip.name} Suitcase');
  }

  @override
  Widget build(BuildContext context) {
    final garmentsAsync = ref.watch(garmentsProvider);

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: _buildAppBar(),
          body: garmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorStateWidget(
              error: e,
              onRetry: () => ref.read(garmentsProvider.notifier).refresh(),
            ),
            data: (all) => _buildBody(all),
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
    final byId = _indexGarmentsById(allGarments);
    final packedGarments = _packedIds
        .map((id) => byId[id])
        .whereType<Garment>()
        .toList();

    return RefreshIndicator(
      onRefresh: _loadPackedItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PrimaryActionButton(
            label: 'Add Garment',
            icon: Icons.add,
            fullWidth: true,
            onPressed: () => _handleAddGarment(allGarments),
          ),
          const SizedBox(height: 20),
          if (packedGarments.isEmpty)
            const EmptyStatePlaceholder(
              message: 'No garments packed yet',
              icon: Icons.luggage_outlined,
              padding: EdgeInsets.only(top: 80),
            )
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

  Map<int, Garment> _indexGarmentsById(List<Garment> garments) {
    return {
      for (final g in garments)
        if (g.id != null) g.id!: g,
    };
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
          mainAxisExtent: AppDimens.garmentCardHeight,
        ),
        itemCount: garments.length,
        itemBuilder: (context, i) => _buildGarmentCard(garments[i]),
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _buildGarmentCard(Garment g) {
    return RemovableCard(
      group: _deleteGroup,
      onDelete: () => _removeGarment(g),
      child: GarmentCard(garment: g, showSelectionIndicator: false),
    );
  }
}
