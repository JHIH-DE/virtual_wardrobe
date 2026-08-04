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
import 'widgets/common/app_dialog.dart';
import 'widgets/common/app_text_field.dart';
import 'widgets/common/app_tool_bar.dart';
import 'widgets/common/bottom_action_button.dart';
import 'widgets/common/floating_nav_bar.dart';
import 'widgets/common/labeled_divider.dart';
import 'widgets/common/loading_overlay.dart';
import 'widgets/common/refreshable_network_image.dart';
import 'widgets/garment/garment_detail_dialog.dart';
import 'widgets/garment/garment_list_card.dart';
import 'widgets/look/look_image.dart';

enum _LookMenuAction { rename, share, regenerate, delete }

class LookDetailsPage extends ConsumerStatefulWidget {
  final Look look;
  final bool isNew;

  /// When [isNew] is true, back normally prompts to save/discard before
  /// leaving. Set this to false to skip that prompt and pop straight back
  /// (e.g. when the look is a daily outfit that already exists server-side,
  /// so there's nothing unsaved to lose).
  final bool confirmLeaveOnBack;

  /// After tapping "Save Look", whether to jump to the Looks tab (popping
  /// back to the shell root) or just pop this page. Jumping to Looks makes
  /// sense when the look was created standalone (Home / Add Look), but not
  /// when it was opened from a specific flow like Trip Details, where the
  /// user expects Save to return them to what they were doing.
  final bool navigateToLooksTabOnSave;

  /// Once the look is saved, whether to still offer the "Remix Look" bottom
  /// bar. Set this to false for entry points (e.g. Trip Details) where a
  /// saved look shouldn't offer to be remixed from here — the bottom bar is
  /// hidden entirely in that case instead.
  final bool showRemixWhenSaved;

  const LookDetailsPage({
    super.key,
    required this.look,
    this.isNew = false,
    this.confirmLeaveOnBack = true,
    this.navigateToLooksTabOnSave = true,
    this.showRemixWhenSaved = true,
  });

  @override
  ConsumerState<LookDetailsPage> createState() => _LooksDetailsPageState();
}

class _LooksDetailsPageState extends ConsumerState<LookDetailsPage> {
  bool _isDeleting = false;
  bool _isSaving = false;
  bool _isSaved = false;
  // True while we're waiting on _fetchLookDetails to confirm the real
  // isSaved status for entry points that hide the bar once saved — avoids
  // flashing the "Save Look" button before we know it's already saved.
  bool _resolvingSavedStatus = false;
  String? _name;
  List<String>? _seasons;
  List<String>? _style;
  List<Garment>? _garments;
  bool _loadingGarments = false;
  bool _openingTryOn = false;
  bool _isRegenerating = false;
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
    _isSaved = widget.look.isSaved;
    if (widget.look.garmentIds.isNotEmpty) _loadGarments();
    if (widget.isNew) {
      _resolvingSavedStatus = !widget.showRemixWhenSaved;
      _fetchLookDetails();
    }
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
      final fresh = await fetchFreshLookImageUrl(widget.look.id);
      if (mounted) setState(() => _imageUrl = fresh);
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
          Positioned.fill(child: LoadingOverlay(label: _l10n.loadingGarments)),
        if (_isRegenerating)
          Positioned.fill(
            child: LoadingOverlay(label: _l10n.generatingEllipsis),
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
              PopupMenuItem(
                value: _LookMenuAction.regenerate,
                enabled: !_isRegenerating,
                child: Row(
                  children: [
                    const Icon(Icons.refresh, color: AppColors.icon),
                    const SizedBox(width: 12),
                    Text(_l10n.regenerate),
                  ],
                ),
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
      case _LookMenuAction.regenerate:
        _regenerateLook();
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
    if (_resolvingSavedStatus) {
      return const SizedBox.shrink();
    }
    if (widget.isNew && !_isSaved) {
      return BottomActionButton(
        label: _l10n.saveLook,
        onPressed: _isSaving ? null : _saveLook,
        isLoading: _isSaving,
      );
    }
    if (_isSaved && !widget.showRemixWhenSaved) {
      return const SizedBox.shrink();
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

  Future<String?> _refreshOutfitImageUrl() async {
    final fresh = await fetchFreshLookImageUrl(widget.look.id);
    if (mounted) setState(() => _imageUrl = fresh);
    return fresh;
  }

  Widget _buildOutfitImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: RefreshableNetworkImage(
          imageUrl: _imageUrl,
          fit: BoxFit.cover,
          placeholderBuilder: (_) =>
              const Center(child: CircularProgressIndicator()),
          errorLabel: _l10n.failedToLoadImage,
          onRefreshUrl: _refreshOutfitImageUrl,
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
        onTap: () => GarmentDetailDialog.show(context, g),
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
        _isSaved = data['is_saved'] == true || data['is_saved'] == 1;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _resolvingSavedStatus = false);
    }
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

  /// Creates a fresh try-on job from the same garments, waits for it to
  /// finish, then deletes the original job — the old look is only removed
  /// once the replacement has actually succeeded.
  Future<void> _regenerateLook() async {
    if (_isRegenerating) return;
    final garmentIds = widget.look.garmentIds;
    if (garmentIds.isEmpty) return;

    setState(() => _isRegenerating = true);
    try {
      final jobResponse = await LookService().createLook(
        garmentIds: garmentIds,
        type: 'general',
      );
      final newJobId = jobResponse['job_id'] as int;

      final newLookData = await _waitForLookCompletion(newJobId);
      if (newLookData == null) {
        throw Exception('Regenerate timed out or failed.');
      }

      if (widget.look.isSaved) {
        await LookService().setSaved(newJobId, isSaved: true);
      }
      // The old job's custom name doesn't carry over server-side, so the
      // new job needs it re-applied explicitly — otherwise it reverts to
      // whatever default the backend assigns a fresh look.
      final name = _name;
      if (name != null && name.isNotEmpty) {
        await LookService().setName(newJobId, name: name);
      }
      await LookService().deleteLook(widget.look.id);
      await ref.read(looksProvider.notifier).refresh();
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LookDetailsPage(
            look: Look(
              id: newJobId,
              name: name,
              imageUrl: newLookData['result_image_url'] ?? '',
              garmentIds: garmentIds,
              seasons: _parseStringList(newLookData['season']),
              style: _parseStringList(newLookData['style']),
              advice: newLookData['ai_notes'],
              isSaved: widget.look.isSaved,
            ),
            navigateToLooksTabOnSave: widget.navigateToLooksTabOnSave,
            showRemixWhenSaved: widget.showRemixWhenSaved,
          ),
        ),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.failedToRegenerateLook)));
    } finally {
      if (mounted) setState(() => _isRegenerating = false);
    }
  }

  /// Polls a freshly-created job until it completes (or fails/times out),
  /// mirroring TryOnMixin's polling without pulling in its unrelated state.
  Future<Map<String, dynamic>?> _waitForLookCompletion(int jobId) async {
    for (var attempt = 0; attempt < 180; attempt++) {
      final data = await LookService().getLook(jobId);
      final status = data['status'];
      if (status == 'completed') return data;
      if (status == 'failed') return null;
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<void> _saveLook() async {
    setState(() => _isSaving = true);
    try {
      await LookService().setSaved(widget.look.id, isSaved: true);
      await ref.read(looksProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _isSaved = true);
      if (widget.navigateToLooksTabOnSave) {
        final feedback = ref.read(lookFeedbackProvider.notifier);
        MainShellScope.of(context)?.selectTab(AppTab.looks);
        Navigator.popUntil(context, (route) => route.isFirst);
        feedback.state = LookFeedbackKind.saved;
      } else {
        Navigator.pop(context);
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
        title: _l10n.deleteLookTitle,
        body: _l10n.deleteLookConfirmation,
        primaryLabel: _l10n.delete,
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
      final feedback = ref.read(lookFeedbackProvider.notifier);
      if (mounted) Navigator.pop(context);
      feedback.state = LookFeedbackKind.deleted;
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
