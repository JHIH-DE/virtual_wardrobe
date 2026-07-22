import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/garments_provider.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garment_service.dart';
import '../core/services/look_service.dart';
import '../core/utils/signed_url.dart';
import '../data/garment.dart';
import '../data/look.dart';
import '../l10n/generated/app_localizations.dart';
import 'add_look_page.dart';
import 'full_screen_image_page.dart';
import 'widgets/common/app_dialog.dart';
import 'widgets/common/app_text_field.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/labeled_divider.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/garment/garment_list_card.dart';

enum _LookMenuAction { rename, share, delete }

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
  bool _isSaved = false;
  String? _name;
  List<String>? _seasons;
  List<String>? _style;
  List<Garment>? _garments;
  bool _loadingGarments = false;
  bool _openingTryOn = false;
  late String _imageUrl;

  List<String> get _effectiveSeasons => _seasons ?? widget.look.seasons;
  List<String> get _effectiveStyle => _style ?? widget.look.style;
  bool get _shouldConfirmLeave => widget.isNew && widget.confirmLeaveOnBack;
  AppLocalizations get _l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _name = widget.look.name;
    _imageUrl = widget.look.imageUrl;
    if (widget.look.garmentIds.isNotEmpty) _loadGarments();
    if (widget.isNew) _fetchLookDetails();
    // A freshly-created look's URL was just signed, but one opened from a
    // list (looks_page.dart, garment_looks_page.dart) may have sat in
    // memory long enough for its signed URL to expire.
    if (!widget.isNew) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureFreshOutfitImage(),
      );
    }
  }

  Future<void> _ensureFreshOutfitImage() async {
    if (!isSignedUrlExpired(_imageUrl)) return;
    try {
      final data = await LookService().getLook(widget.look.id);
      final fresh = Look.fromJson(data);
      if (mounted) setState(() => _imageUrl = fresh.imageUrl);
    } catch (_) {
      // Leave the existing URL; the image's errorWidget covers the fallback.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildScaffold(context),
        if (_openingTryOn)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.loadingGarments),
          ),
      ],
    );
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(
      title: _l10n.details,
      onBack: _shouldConfirmLeave ? _showLeaveDialog : null,
      actions: [
        if (!widget.isNew)
          PopupMenuButton<_LookMenuAction>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, color: AppColors.icon),
            color: AppColors.surface,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              _menuItem(
                _LookMenuAction.rename,
                Icons.edit_outlined,
                _l10n.rename,
              ),
              _menuItem(
                _LookMenuAction.share,
                Icons.share_outlined,
                _l10n.share,
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _LookMenuAction.delete,
                enabled: !_isDeleting,
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: AppColors.icon),
                    const SizedBox(width: 12),
                    Text(
                      _l10n.delete,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  PopupMenuItem<_LookMenuAction> _menuItem(
    _LookMenuAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppColors.icon),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  void _handleMenuAction(_LookMenuAction action) {
    switch (action) {
      case _LookMenuAction.rename:
        _showEditNameDialog();
        break;
      case _LookMenuAction.share:
        _shareLook();
        break;
      case _LookMenuAction.delete:
        _deleteLook();
        break;
    }
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
        extendBody: true,
        appBar: _buildAppBar(),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          children: [
            _buildTitleRow(),
            const SizedBox(height: 12),
            _buildOutfitImage(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 12),
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
        label: _l10n.saveLook,
        onPressed: _isSaving ? null : _saveLook,
        isLoading: _isSaving,
      );
    }
    return BottomActionButton(
      label: _l10n.remixLook,
      leading: Image.asset(
        'assets/images/ai_process_inv.png',
        width: 18,
        height: 18,
      ),
      onPressed: () => _remixLook(context),
      enabled: !_loadingGarments && !_openingTryOn,
      height: 48,
      panelPadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
    );
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  Widget _buildInfoCard() {
    final seasons = _effectiveSeasons.map(_titleCase).toList();
    final styles = _effectiveStyle.map(_titleCase).toList();
    final hasTags = seasons.isNotEmpty || styles.isNotEmpty;
    final tagStyle = AppTextStyle.regular14.copyWith(
      color: AppColors.textSecondary,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: hasTags
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (seasons.isNotEmpty)
                  Text(seasons.join(' • '), style: tagStyle),
                if (seasons.isNotEmpty && styles.isNotEmpty)
                  const SizedBox(height: 4),
                if (styles.isNotEmpty)
                  Text(styles.join(' • '), style: tagStyle),
              ],
            )
          : Text(_l10n.myCollection, style: tagStyle),
    );
  }

  Widget _buildCreateDateFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1, color: AppColors.borderStrong),
        const SizedBox(height: 16),
        Text(
          _l10n.createdOnDate(_formattedDate),
          style: AppTextStyle.bold14.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildTitleRow() {
    return Text(
      _title,
      textAlign: TextAlign.center,
      style: AppTextStyle.title22,
    );
  }

  void _shareLook() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_l10n.shareComingSoon)));
  }

  Widget _buildOutfitImage() {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => FullScreenImagePage(imageUrl: _imageUrl),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Hero(
            tag: 'outfit_image_${widget.look.id}',
            child: CachedNetworkImage(
              imageUrl: _imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => Center(
                child: Text(
                  _l10n.failedToLoadImage,
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
          label: _l10n.garmentsCount(
            _garments?.length ?? widget.look.garmentIds.length,
          ),
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
      // instead of always hitting the network per garment — but skip stale
      // cache entries whose signed image URL has expired, so photos don't
      // render as broken images.
      final cached = ref.read(garmentsProvider).valueOrNull ?? const [];
      final cachedById = _indexGarmentsById(cached);

      final results = await Future.wait(
        widget.look.garmentIds.map((id) {
          final cachedGarment = cachedById[id];
          final imageUrl = cachedGarment?.imageUrl;
          final isFresh =
              cachedGarment != null &&
              (imageUrl == null ||
                  imageUrl.isEmpty ||
                  !isSignedUrlExpired(imageUrl));
          return isFresh
              ? Future.value(cachedGarment)
              : GarmentService().getGarment(id);
        }),
      );
      if (mounted) setState(() => _garments = results);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGarments = false);
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
          builder: (_) => AddLookPage(
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.failedToLoadGarments)));
      }
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
        title: _l10n.saveThisLookTitle,
        body: _l10n.saveThisLookBody,
        primaryLabel: _l10n.save,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.discard,
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
        title: _l10n.removeLookTitle,
        body: _l10n.removeLookBody,
        primaryLabel: _l10n.remove,
        onPrimary: () => Navigator.pop(ctx, true),
        secondaryLabel: _l10n.cancel,
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
    if (parts.isEmpty) return _l10n.myLook;
    final word = parts.first;
    final capitalized = word.isEmpty
        ? word
        : '${word[0].toUpperCase()}${word.substring(1)}';
    return _l10n.outfitTitle(capitalized);
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AppDialog(
        title: _l10n.renameLook,
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: AppTextStyle.bold16,
          decoration: appInputDecoration(hint: _l10n.lookNameLabel),
        ),
        primaryLabel: _l10n.save,
        onPrimary: () => Navigator.pop(ctx, controller.text.trim()),
        secondaryLabel: _l10n.cancel,
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
