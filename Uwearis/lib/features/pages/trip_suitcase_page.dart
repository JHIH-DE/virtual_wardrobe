import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../core/providers/garments_provider.dart';
import '../../core/services/auth_handler.dart';
import '../../core/services/trip_service.dart';
import '../../core/utils/debug_log.dart';
import '../../data/garment.dart';
import '../../data/trip.dart';
import '../../l10n/garment_localization.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/cards/removable_card.dart';
import '../widgets/common/overlays/empty_state_placeholder.dart';
import '../widgets/common/overlays/loading_overlay.dart';
import '../widgets/common/section_title.dart';
import '../widgets/garment/garment_card.dart';
import 'trip_garment_selection_page.dart';

class TripSuitcasePage extends ConsumerStatefulWidget {
  final Trip trip;

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
  List<Garment> _packedGarments = [];
  final Set<int> _pendingIds = {};
  final _deleteGroup = RemovableCardGroup();

  Set<int> get _packedIds => {
    for (final g in _packedGarments)
      if (g.id != null) g.id!,
  };

  int get _tripId => int.parse(widget.trip.id);
  AppLocalizations get _l10n => AppLocalizations.of(context);

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
      final data = await TripService().getTrip(_tripId);
      final rawItems = (data['suitcase_items'] as List?) ?? [];
      // Each item now embeds its own image/category/name
      // (TripSuitcaseItemResponse), so garments are built straight from
      // the trip response — no closet fetch needed to resolve them.
      final garments = rawItems
          .whereType<Map<String, dynamic>>()
          .map(Garment.fromTripItemJson)
          .toList();
      if (mounted) setState(() => _packedGarments = garments);
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to load suitcase items: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAddGarment(List<Garment> allGarments) async {
    await ref.read(garmentsProvider.notifier).refreshIfNeeded();
    if (!mounted) return;
    final garments = ref.read(garmentsProvider).value ?? allGarments;

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

    final closetById = _indexGarmentsById(garments);
    setState(() {
      _pendingIds.addAll(toAdd);
      _pendingIds.addAll(toRemove);
      _packedGarments = [
        for (final g in _packedGarments)
          if (!toRemove.contains(g.id)) g,
        for (final id in toAdd)
          if (closetById[id] != null) closetById[id]!,
      ];
    });

    try {
      for (final id in toAdd) {
        await TripService().addSuitcaseItem(_tripId, garmentId: id);
      }
      for (final id in toRemove) {
        await TripService().removeSuitcaseItem(_tripId, garmentId: id);
      }
    } on AuthExpiredException {
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('Failed to update suitcase: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToUpdateSuitcase)));
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

    final previousGarments = _packedGarments;
    setState(() {
      _pendingIds.add(id);
      _packedGarments = _packedGarments.where((g) => g.id != id).toList();
    });

    try {
      await TripService().removeSuitcaseItem(_tripId, garmentId: id);
    } catch (e) {
      if (mounted) setState(() => _packedGarments = previousGarments);
      if (e is AuthExpiredException) {
        if (mounted) await AuthExpiredHandler.handle(context);
        return;
      }
      debugLog('Failed to remove suitcase item: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToRemoveItem)));
      }
    } finally {
      if (mounted) setState(() => _pendingIds.remove(id));
    }
  }

  AppToolBar _buildAppBar(List<Garment> closetGarments) {
    return AppToolBar(
      title: _l10n.suitcaseLabel,
      actions: [
        InkWell(
          onTap: () => _handleAddGarment(closetGarments),
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Image.asset(
                'assets/images/plus.png',
                height: AppDimens.iconSmallSize,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Only needed for the "Add" picker's full closet — the packed list
    // itself now renders straight from _packedGarments (embedded fields
    // from the trip response), so it isn't gated on this loading/erroring.
    final closetGarments = ref.watch(garmentsProvider).value ?? [];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: _buildAppBar(closetGarments),
          body: _buildBody(closetGarments),
        ),
        if (_loading)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingSuitcaseEllipsis),
          ),
      ],
    );
  }

  Widget _buildBody(List<Garment> closetGarments) {
    return RefreshIndicator(
      onRefresh: _loadPackedItems,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_packedGarments.isEmpty)
            EmptyStatePlaceholder(
              message: _l10n.noGarmentsPackedYet,
              icon: Icons.luggage_outlined,
              padding: EdgeInsets.only(top: 80),
            )
          else
            for (final category in _categoryOrder)
              ..._buildCategorySection(
                category,
                _packedGarments.where((g) => g.category == category).toList(),
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
      SectionTitle(category.localizedLabel(context)),
      const SizedBox(height: AppDimens.cardHeaderGap),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: AppDimens.cardSpacing,
          mainAxisSpacing: AppDimens.cardSpacing,
          mainAxisExtent: AppDimens.garmentCardHeight,
        ),
        itemCount: garments.length,
        itemBuilder: (context, i) => _buildGarmentCard(garments[i]),
      ),
      const SizedBox(height: AppDimens.sectionSpacing),
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
