import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../core/services/look_service.dart';
import '../data/garment.dart';
import '../data/look.dart';
import 'full_screen_image_page.dart';
import 'manual_try_on_page.dart';
import 'widgets/common/action_button.dart';
import 'widgets/common/app_dialog.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/category_tag.dart';
import 'widgets/common/labeled_divider.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/garment/garment_list_card.dart';

class LooksDetailsPage extends ConsumerStatefulWidget {
  final Look look;
  final bool isNew;

  /// When [isNew] is true, back normally prompts to save/discard before
  /// leaving. Set this to false to skip that prompt and pop straight back
  /// (e.g. when the look is a daily outfit that already exists server-side,
  /// so there's nothing unsaved to lose).
  final bool confirmLeaveOnBack;

  const LooksDetailsPage({
    super.key,
    required this.look,
    this.isNew = false,
    this.confirmLeaveOnBack = true,
  });

  @override
  ConsumerState<LooksDetailsPage> createState() => _LooksDetailsPageState();
}

class _LooksDetailsPageState extends ConsumerState<LooksDetailsPage> {
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isFavoriteLoading = false;
  late bool _isFavorite;
  bool _isSaved = false;
  String? _name;
  List<String>? _seasons;
  List<String>? _style;
  List<Garment>? _garments;
  bool _loadingGarments = false;
  bool _openingTryOn = false;

  List<String> get _effectiveSeasons => _seasons ?? widget.look.seasons;
  List<String> get _effectiveStyle => _style ?? widget.look.style;
  bool get _shouldConfirmLeave => widget.isNew && widget.confirmLeaveOnBack;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.look.isFavorite;
    _name = widget.look.name;
    if (widget.look.garmentIds.isNotEmpty) _loadGarments();
    if (widget.isNew) _fetchLookDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(context),
        if (_openingTryOn)
          const Positioned.fill(
            child: LoadingOverlay(label: 'Loading Garments...'),
          ),
      ],
    );
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: 'Details',
      onBack: _shouldConfirmLeave ? _showLeaveDialog : null,
      actions: [
        if (!widget.isNew)
          IconButton(
            icon: Image.asset(
              'assets/images/delete.png',
              height: AppDimens.iconMediumSize,
            ),
            onPressed: _isDeleting ? null : _deleteLook,
          ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return PopScope(
      canPop: !_shouldConfirmLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showLeaveDialog();
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBackground,
        appBar: _buildAppBar(),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _buildTitleRow(),
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              thickness: 6,
              color: AppColors.dividerStrong,
            ),
            _buildInfoCard(),
            const Divider(
              height: 1,
              thickness: 2,
              color: AppColors.dividerStrong,
            ),
            const SizedBox(height: 16),
            _buildOutfitImage(),
            const SizedBox(height: 12),
            _buildActionButtons(),
            if (widget.look.garmentIds.isNotEmpty) ...[_buildGarmentSection()],
            const SizedBox(height: 12),
            _buildCreateDateFooter(),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(context),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    if (widget.isNew) {
      return BottomActionButton(
        label: 'Save Look',
        onPressed: _isSaving ? null : _saveLook,
        isLoading: _isSaving,
      );
    }
    return BottomActionButton(
      label: 'Remix Look',
      leading: Image.asset(
        'assets/images/ai_process_inv.png',
        width: 18,
        height: 18,
      ),
      onPressed: () => _remixLook(context),
      enabled: !_loadingGarments && !_openingTryOn,
    );
  }

  Widget _buildInfoCard() {
    final tags = [..._effectiveSeasons, ..._effectiveStyle];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowResting,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: tags.isNotEmpty
            ? tags.map((t) => CategoryTag(label: t)).toList()
            : [const CategoryTag(label: 'My Collection')],
      ),
    );
  }

  Widget _buildCreateDateFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: AppColors.borderStrong),
        const SizedBox(height: 16),
        Text(
          'Created on $_formattedDate',
          style: AppTextStyle.bold14.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTitleRow() {
    return Row(
      children: [
        Text(_title, style: AppTextStyle.title22),
        const Spacer(),
        GestureDetector(
          onTap: _showEditNameDialog,
          child: Image.asset('assets/images/edit.png', width: 20, height: 20),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return ActionButtonRow(
      buttons: [
        ActionButton(
          icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
          iconColor: _isFavorite ? AppColors.favorite : AppColors.icon,
          label: 'Favorite',
          horizontal: true,
          onTap: _isFavoriteLoading
              ? null
              : (widget.isNew ? _saveWithFavorite : _toggleFavorite),
        ),
        ActionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          horizontal: true,
          onTap: _shareLook,
        ),
      ],
    );
  }

  void _shareLook() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Share coming soon')));
  }

  Widget _buildOutfitImage() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) =>
              FullScreenImagePage(imageUrl: widget.look.imageUrl),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Hero(
            tag: 'outfit_image_${widget.look.id}',
            child: CachedNetworkImage(
              imageUrl: widget.look.imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  'Failed to load image',
                  style: AppTextStyle.regular14.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
        LabeledDivider(
          label:
              'Garment List (${_garments?.length ?? widget.look.garmentIds.length})',
        ),
        const SizedBox(height: 16),
        if (_loadingGarments)
          const Center(child: CircularProgressIndicator())
        else if (_garments != null)
          ..._garments!.map(_buildGarmentCard),
      ],
    );
  }

  Widget _buildGarmentCard(Garment g) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GarmentListCard(
        garment: g,
        onTap: (g.imageUrl?.isNotEmpty == true)
            ? () => Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (_, __, ___) => FullScreenImagePage(
                    imageUrl: g.imageUrl!,
                    backgroundColor: AppColors.surface,
                    aspectRatio: 1.0,
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _fetchLookDetails() async {
    try {
      final data = await LookService().getLook(widget.look.id);
      if (!mounted) return;
      setState(() {
        _name = (data['name'] as String?)?.isNotEmpty == true
            ? data['name'] as String
            : _name;
        _seasons = _parseStringList(data['season']);
        _style = _parseStringList(data['style']);
      });
    } catch (_) {}
  }

  List<String> _parseStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return [];
  }

  Map<int, Garment> _indexGarmentsById(List<Garment> garments) {
    return {
      for (final g in garments)
        if (g.id != null) g.id!: g,
    };
  }

  Future<void> _loadGarments() async {
    setState(() => _loadingGarments = true);
    try {
      // Reuse whatever My Closet has already loaded into garmentsProvider
      // instead of always hitting the network per garment.
      final cached = ref.read(garmentsProvider).valueOrNull ?? const [];
      final cachedById = _indexGarmentsById(cached);

      final results = await Future.wait(
        widget.look.garmentIds.map(
          (id) => cachedById[id] != null
              ? Future.value(cachedById[id]!)
              : GarmentService().getGarment(id),
        ),
      );
      if (mounted) setState(() => _garments = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGarments = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() {
      _isFavorite = next;
      _isFavoriteLoading = true;
    });
    try {
      await LookService().setFavorite(widget.look.id, isFavorite: next);
      ref
          .read(looksProvider.notifier)
          .updateFavorite(widget.look.id, isFavorite: next);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !next);
    } finally {
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  Future<void> _remixLook(BuildContext context) async {
    setState(() => _openingTryOn = true);
    try {
      final garments = await ref.read(garmentsProvider.future);
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManualTryOnPage(
            initialGarments: _garments ?? [],
            preloadedGarments: garments,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _openingTryOn = false);
      if (e is AuthExpiredException) {
        await AuthExpiredHandler.handle(context);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load garments')),
        );
      }
    }
  }

  Future<void> _saveWithFavorite() async {
    if (_isSaved) {
      _toggleFavorite();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Save this look?',
        body:
            'This look will be saved to your collection and marked as favorite.',
        primaryLabel: 'Save',
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _isFavoriteLoading = true);
    try {
      await LookService().setSaved(widget.look.id, isSaved: true);
      await LookService().setFavorite(widget.look.id, isFavorite: true);
      await ref.read(looksProvider.notifier).refresh();
      if (mounted) {
        setState(() {
          _isFavorite = true;
          _isSaved = true;
        });
      }
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  Future<void> _saveLook() async {
    setState(() => _isSaving = true);
    try {
      await LookService().setSaved(widget.look.id, isSaved: true);
      await ref.read(looksProvider.notifier).refresh();
      if (mounted) setState(() => _isSaved = true);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showLeaveDialog() async {
    if (_isSaved) {
      Navigator.pop(context);
      return;
    }
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Save this look?',
        body: 'Would you like to save this look to your collection?',
        primaryLabel: 'Save',
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: 'Discard',
        onSecondary: () => Navigator.pop(ctx, false),
      ),
    );
    if (!mounted || save == null) return;

    try {
      if (save) {
        await LookService().setSaved(widget.look.id, isSaved: true);
        await ref.read(looksProvider.notifier).refresh();
      } else {
        await LookService().deleteLook(widget.look.id);
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteLook() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Remove look?',
        body: 'This look will be removed from your Looks.',
        primaryLabel: 'Remove',
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx, false),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String get _title {
    if (_name != null && _name!.isNotEmpty) return _name!;
    final parts = [..._effectiveSeasons, ..._effectiveStyle];
    if (parts.isEmpty) return 'My Look';
    final word = parts.first;
    final capitalized = word.isEmpty
        ? word
        : '${word[0].toUpperCase()}${word.substring(1)}';
    return '$capitalized Outfit';
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: 'Edit Name',
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Enter look name',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        primaryLabel: 'Save',
        onPrimary: () => Navigator.pop(ctx, controller.text.trim()),
        secondaryLabel: 'Cancel',
        onSecondary: () => Navigator.pop(ctx),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());

    if (result == null || result.isEmpty || !mounted) return;
    try {
      await LookService().setName(widget.look.id, name: result);
      if (!mounted) return;
      setState(() => _name = result);
      ref.read(looksProvider.notifier).updateName(widget.look.id, name: result);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String get _formattedDate =>
      DateFormat('MMM d, yyyy').format(widget.look.createdAt);
}
