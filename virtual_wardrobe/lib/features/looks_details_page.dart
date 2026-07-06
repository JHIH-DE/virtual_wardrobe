import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/theme/app_colors.dart';
import '../app/theme/app_dimens.dart';
import '../app/theme/app_text_styles.dart';
import '../core/providers/looks_provider.dart';
import '../core/services/auth_handler.dart';
import '../core/services/garments_service.dart';
import '../core/services/looks_service.dart';
import '../data/garment.dart';
import '../data/look.dart';
import 'manual_try_on_page.dart';
import 'widgets/app_dialog.dart';
import 'widgets/bottom_action_button.dart';
import 'widgets/category_tag.dart';
import 'widgets/full_screen_image_page.dart';
import 'widgets/garment_list_card.dart';
import 'widgets/labeled_divider.dart';
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
  bool _isDeleting = false;
  bool _isFavoriteLoading = false;
  late bool _isFavorite;
  bool _isSaved = false;
  String? _name;
  List<String>? _seasons;
  List<String>? _style;
  List<Garment>? _garments;
  bool _loadingGarments = false;

  List<String> get _effectiveSeasons => _seasons ?? widget.look.seasons;
  List<String> get _effectiveStyle => _style ?? widget.look.style;

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
    return PopScope(
      canPop: !widget.isNew,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showLeaveDialog();
      },
      child: Scaffold(
      backgroundColor: AppColors.defaultBackground,
      appBar: PageAppBar(
        title: 'Details',
        onBack: widget.isNew ? _showLeaveDialog : null,
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: Image.asset('assets/images/delete.png', height: AppDimens.iconMediumSize),
              onPressed: _isDeleting ? null : _deleteLook,
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _buildTitleRow(),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 6, color: AppColors.defaultDivider),
            _buildInfoCard(),
            const Divider(height: 1, thickness: 2, color: AppColors.defaultDivider),
            const SizedBox(height: 16),
            _buildOutfitImage(),
            const SizedBox(height: 16),
            _buildActionButtons(),
            if (widget.look.garmentIds.isNotEmpty) ...[
              _buildGarmentSection(),
            ],
          ],
        ),
      ),
      bottomNavigationBar: widget.isNew
          ? null
          : BottomActionButton(
              label: 'Remix Look',
              trailing: const Icon(Icons.shuffle_rounded, size: 18),
              onPressed: _remixLook,
              enabled: !_loadingGarments,
            ),
    ),
    );
  }

  Widget _buildInfoCard() {
    final tags = [
      ..._effectiveSeasons,
      ..._effectiveStyle,
    ];

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
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.isNotEmpty
                    ? tags.map((t) => CategoryTag(label: t)).toList()
                    : [const CategoryTag(label: 'My Collection')],
              ),
            ),
            Container(
              width: 1,
              color: AppColors.defaultDivider,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Create Date', style: AppTextStyle.bold16),
                const SizedBox(height: 2),
                Text(_formattedDate, style: AppTextStyle.bold16),
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
        Text(_title, style: AppTextStyle.title22),
        const Spacer(),
        GestureDetector(
          onTap: _showEditNameDialog,
          child: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return IntrinsicHeight(
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
              iconColor: _isFavorite ? Colors.red : AppColors.textPrimary,
              label: 'Favorite',
              onTap: _isFavoriteLoading
                  ? null
                  : (widget.isNew ? _saveWithFavorite : _toggleFavorite),
            ),
          ),
          Expanded(
            child: _buildActionButton(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: _shareLook,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: iconColor ?? AppColors.textPrimary),
            const SizedBox(height: 4),
            Text(label, style: AppTextStyle.regular14.copyWith(color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  void _shareLook() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share coming soon')),
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
        LabeledDivider(label: 'Garment List'),
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

  Future<void> _fetchLookDetails() async {
    try {
      final data = await LookService().getLook(widget.look.id);
      if (!mounted) return;
      List<String> parseStrings(dynamic v) {
        if (v is List) return v.map((e) => e.toString()).toList();
        if (v is String && v.isNotEmpty) return [v];
        return [];
      }
      setState(() {
        _name = (data['name'] as String?)?.isNotEmpty == true ? data['name'] as String : _name;
        _seasons = parseStrings(data['season']);
        _style = parseStrings(data['style']);
      });
    } catch (_) {}
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

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() {
      _isFavorite = next;
      _isFavoriteLoading = true;
    });
    try {
      await LookService().setFavorite(widget.look.id, isFavorite: next);
      ref.read(looksProvider.notifier).updateFavorite(widget.look.id, isFavorite: next);
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !next);
    } finally {
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  void _remixLook() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualTryOnPage(initialGarments: _garments ?? []),
      ),
    );
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
        body: 'This look will be saved to your collection and marked as favorite.',
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
      if (mounted) setState(() { _isFavorite = true; _isSaved = true; });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isFavoriteLoading = false);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String get _title {
    if (_name != null && _name!.isNotEmpty) return _name!;
    final parts = [..._effectiveSeasons, ..._effectiveStyle];
    if (parts.isEmpty) return 'My Look';
    final word = parts.first;
    final capitalized = word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}';
    return '$capitalized Outfit';
  }

  Future<void> _showEditNameDialog() async {
    final controller = TextEditingController(text: _name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SizedBox(
          width: 292,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Edit Name', style: AppTextStyle.dialogTitle, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Enter look name',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    elevation: 0,
                  ),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black, width: 1.6),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          ),
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  String get _formattedDate {
    final d = widget.look.createdAt;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }

}
