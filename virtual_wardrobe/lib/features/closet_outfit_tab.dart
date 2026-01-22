import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/services/auth_error_handler.dart';
import '../core/services/garment_service.dart';
import '../core/services/token_storage.dart';
import '../core/services/tryon_service.dart';
import '../data/looks_store.dart';
import '../l10n/app_strings.dart';
import 'garment_category.dart';
import 'select_garment_page.dart';

class ClosetOutfitTab extends StatefulWidget {
  const ClosetOutfitTab({super.key});

  @override
  State<ClosetOutfitTab> createState() => _ClosetOutfitTabState();
}

enum OutfitMode { my, ai }

class _ClosetOutfitTabState extends State<ClosetOutfitTab> {
  String seasons = 'Spring';
  String style = 'Minimal';
  OutfitSelection manualOutfit = const OutfitSelection();
  OutfitMode _mode = OutfitMode.my;

  final List<Garment> _allGarments = [];
  bool generating = false;

  final List<Map<String, dynamic>> suggestedOutfits = [];
  Map<String, dynamic>? selectedOutfit;

  String? tryOnJobId;
  String? tryOnResultUrl;
  String? aiAdvice;

  Timer? _pollTimer;
  bool tryOnLoading = false;
  String? errorMessage;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGarments(); 
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _modeSwitcher(),
          const SizedBox(height: 14),

          if (_mode == OutfitMode.my) ...[
            _buildMyOutfitCard(),
          ] else ...[
            _buildAiOutfitCard(),
            const SizedBox(height: 14),
            _buildSuggestedOutfitsCard(),
          ],

          const SizedBox(height: 14),
          if (selectedOutfit != null || manualOutfit.canTryOn || tryOnResultUrl != null)
            _buildTryOnResultCard(context),
        ],
      ),
    );
  }

  Widget _buildTryOnSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tryOnLoading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(minHeight: 4),
          ),
          const SizedBox(height: 10),
          Text(
            tryOnJobId == null ? 'Creating job...' : 'Generating image… (job: $tryOnJobId)',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],

        if (errorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],

        if (tryOnResultUrl != null) ...[
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  tryOnResultUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stack) {
                    return const Center(
                      child: Text(
                        AppStrings.loadingImageWarning,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (aiAdvice != null) ...[
            const Text(
              AppStrings.aiStylingNotes,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              aiAdvice!,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: tryOnLoading ? null : _discardResult,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Discard'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: tryOnLoading ? null : _saveLook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Save Look'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _loadGarments() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;
    setState(() => _loading = true);
    try {
      final list = await GarmentService().getGarments(token);
      if (mounted) setState(() => _allGarments..clear()..addAll(list));
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

  Widget _outfitCard(Map<String, dynamic> outfit) {
    final bool isSelected = selectedOutfit?['outfit_id'] == outfit['outfit_id'];

    return InkWell(
      onTap: tryOnLoading
          ? null
          : () {
        setState(() {
          selectedOutfit = outfit;
          _resetTryOnState(clearSelection: false);
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary.withOpacity(0.45) : AppColors.border,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.border,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit['title'] ?? 'Outfit',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    outfit['summary'] ?? 'Top + Bottom + Outer',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            if (isSelected)
              Icon(Icons.check_circle, color: AppColors.primary)
            else
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _modeSwitcher() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: SegmentedButton<OutfitMode>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: OutfitMode.my,
            icon: Icon(Icons.account_circle),
            label: Text('My Outfit'),
          ),
          ButtonSegment(
            value: OutfitMode.ai,
            icon: Icon(Icons.auto_awesome_outlined),
            label: Text('AI Outfit'),
          ),
        ],
        selected: {_mode},
        onSelectionChanged: (s) {
          setState(() {
            _mode = s.first;
            _resetTryOnState(clearSelection: false);
            errorMessage = null;
            if (_mode == OutfitMode.my) {
              selectedOutfit = null;
              suggestedOutfits.clear();
            }
          });
        },
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary.withOpacity(0.10);
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.textPrimary;
            return AppColors.textSecondary;
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
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
              fontWeight: FontWeight.w700,
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

  Widget _buildAiOutfitCard() {
    return _sectionCard(
      title: 'Ai Outfit',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: seasons,
                  items: const [
                    DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                    DropdownMenuItem(value: 'Summer', child: Text('Summer')),
                    DropdownMenuItem(value: 'Autumn', child: Text('Autumn')),
                    DropdownMenuItem(value: 'Winter', child: Text('Winter')),
                  ],
                  onChanged: generating || tryOnLoading
                      ? null
                      : (v) => setState(() => seasons = v ?? seasons),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: style,
                  items: const [
                    DropdownMenuItem(value: 'Minimal', child: Text('Minimal')),
                    DropdownMenuItem(value: 'Street', child: Text('Street')),
                    DropdownMenuItem(value: 'Classic', child: Text('Classic')),
                    DropdownMenuItem(value: 'Sporty', child: Text('Sporty')),
                  ],
                  onChanged: generating || tryOnLoading
                      ? null
                      : (v) => setState(() => style = v ?? style),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: generating || tryOnLoading ? null : _generateOutfits,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  generating ? AppStrings.generating : AppStrings.generateOutfits,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyOutfitCard() {
    return _sectionCard(
      title: 'My Outfit',
      child: Column(
        children: [
          _slotRow(
            title: 'Top',
            value: manualOutfit.top,
            category: GarmentCategory.top,
            onPicked: (g) => setState(() {
              manualOutfit = manualOutfit.copyWith(top: g);
              _resetTryOnState(clearSelection: false);
            }),
            onClear: manualOutfit.top == null
                ? null
                : () => setState(() {
              manualOutfit = manualOutfit.copyWith(top: null);
              _resetTryOnState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Middle',
            value: manualOutfit.middle,
            category: GarmentCategory.top,
            onPicked: (g) => setState(() {
              manualOutfit = manualOutfit.copyWith(middle: g);
              _resetTryOnState(clearSelection: false);
            }),
            onClear: manualOutfit.middle == null
                ? null
                : () => setState(() {
              manualOutfit = manualOutfit.copyWith(clearMiddle: true);
              _resetTryOnState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Outer',
            value: manualOutfit.outer,
            category: GarmentCategory.outer,
            onPicked: (g) => setState(() {
              manualOutfit = manualOutfit.copyWith(outer: g);
              _resetTryOnState(clearSelection: false);
            }),
            onClear: manualOutfit.outer == null
                ? null
                : () => setState(() {
              manualOutfit = manualOutfit.copyWith(clearOuter: true);
              _resetTryOnState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Bottom',
            value: manualOutfit.bottom,
            category: GarmentCategory.bottom,
            onPicked: (g) => setState(() {
              manualOutfit = manualOutfit.copyWith(bottom: g);
              _resetTryOnState(clearSelection: false);
            }),
            onClear: manualOutfit.bottom == null
                ? null
                : () => setState(() {
              manualOutfit = manualOutfit.copyWith(bottom: null);
              _resetTryOnState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Shoes',
            value: manualOutfit.shoes,
            category: GarmentCategory.shoes,
            onPicked: (g) => setState(() {
              manualOutfit = manualOutfit.copyWith(shoes: g);
              _resetTryOnState(clearSelection: false);
            }),
            onClear: manualOutfit.shoes == null
                ? null
                : () => setState(() {
              manualOutfit = manualOutfit.copyWith(clearShoes: true);
              _resetTryOnState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Accessory',
            value: manualOutfit.accessory,
            category: GarmentCategory.accessory,
            onPicked: (g) => setState(() {
              manualOutfit = manualOutfit.copyWith(accessory: g);
              _resetTryOnState(clearSelection: false);
            }),
            onClear: manualOutfit.accessory == null
                ? null
                : () => setState(() {
              manualOutfit = manualOutfit.copyWith(clearAccessory: true);
              _resetTryOnState(clearSelection: false);
            }),
          ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: (tryOnLoading || !manualOutfit.canTryOn)
                ? null
                : _startTryOnManual,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  manualOutfit.canTryOn ? 'Try On My Outfit' : 'Select Top + Bottom first',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestedOutfitsCard() {
    return _sectionCard(
      title: AppStrings.suggestedOutfits,
      child: suggestedOutfits.isEmpty
          ? const Text(
        AppStrings.suggestedWarning,
        style: TextStyle(color: AppColors.textSecondary),
      )
          : Column(
        children: [
          ...suggestedOutfits.map(_outfitCard),
        ],
      ),
    );
  }

  Widget _buildTryOnResultCard(BuildContext context) {
    //判斷是否有選中的套裝、是否手動組合完成、或者是否有現成的試穿結果
    final bool hasSelection = selectedOutfit != null || manualOutfit.canTryOn;
    final bool showSection = hasSelection || tryOnResultUrl != null;

    return _sectionCard(
      title: AppStrings.tryOnResult,
      child: showSection
          ? _buildTryOnSection(context)
          : const SizedBox.shrink(),
    );
  }

  Widget _slotRow({
    required String title,
    required Garment? value,
    required GarmentCategory category,
    required void Function(Garment g) onPicked,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: tryOnLoading
          ? null
          : () async {
        final picked = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SelectGarmentPage(
              title: 'Select $title',
              category: category,
              garments: _allGarments,
            ),
          ),
        );

        if (picked is Garment) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),

            Expanded(
              child: value == null
                  ? const Text(
                'Select',
                style: TextStyle(color: AppColors.textSecondary),
              )
                  : Row(
                children: [
                  _GarmentThumb(value.imageUrl),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      value.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

            if (onClear != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(99),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ] else ...[
              const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateOutfits() async {
    setState(() {
      generating = true;
      selectedOutfit = null;
      _resetTryOnState(clearSelection: false);
      suggestedOutfits.clear();
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        suggestedOutfits.addAll([
          {'outfit_id': 'o1', 'title': 'Outfit 1', 'summary': '$style • $seasons'},
          {'outfit_id': 'o2', 'title': 'Outfit 2', 'summary': 'Classic • Work'},
          {'outfit_id': 'o3', 'title': 'Outfit 3', 'summary': 'Street • Date'},
        ]);
      });
    } catch (e) {
      setState(() => errorMessage = 'Failed to generate outfits.');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> _startTryOn() async {
    if (selectedOutfit == null) return;
    _pollTimer?.cancel();
    setState(() {
      tryOnLoading = true;
      errorMessage = null;
      tryOnJobId = null;
      tryOnResultUrl = null;
      aiAdvice = null;
    });

    try {
      final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';
      if (!mounted) return;
      setState(() => tryOnJobId = jobId);
      _startPolling('token_placeholder', jobId); 
    } catch (e) {
      if (mounted) setState(() { tryOnLoading = false; errorMessage = 'Try-On failed.'; });
    }
  }

  Widget _GarmentThumb(String? urlOrPath) {
    final u = (urlOrPath ?? '').trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 32,
        height: 32,
        child: u.isEmpty
            ? Container(color: AppColors.border, child: const Icon(Icons.image_not_supported, size: 16))
            : (u.startsWith('http')) ? Image.network(u, fit: BoxFit.cover) : Image.file(File(u), fit: BoxFit.cover),
      ),
    );
  }

  Future<void> _startTryOnManual() async {
    if (!manualOutfit.canTryOn) {
      setState(() => errorMessage = 'Select Top + Bottom first.');
      return;
    }

    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    _pollTimer?.cancel();
    setState(() {
      tryOnLoading = true;
      errorMessage = null;
      tryOnJobId = null;
      tryOnResultUrl = null;
      aiAdvice = null;
      selectedOutfit = null;
    });

    try {
      final List<int> ids = [];
      if (manualOutfit.top?.id != null) ids.add(manualOutfit.top!.id!);
      if (manualOutfit.bottom?.id != null) ids.add(manualOutfit.bottom!.id!);
      if (manualOutfit.outer?.id != null) ids.add(manualOutfit.outer!.id!);
      if (manualOutfit.shoes?.id != null) ids.add(manualOutfit.shoes!.id!);
      if (manualOutfit.accessory?.id != null) ids.add(manualOutfit.accessory!.id!);

      final jobResponse = await TryOnService().createTryOnJob(
        token,
        garmentIds: ids
      );

      final jobId = jobResponse['job_id'].toString();
      if (!mounted) return;
      setState(() => tryOnJobId = jobId);

      _startPolling(token, jobId);

    } catch (e) {
      if (!mounted) return;
      setState(() {
        tryOnLoading = false;
        errorMessage = 'Failed: $e';
      });
    }
  }

  void _startPolling(String token, String jobId) {
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 180) {
        timer.cancel();
        if (mounted) setState(() { tryOnLoading = false; errorMessage = 'Timeout.'; });
        return;
      }
      try {
        final statusRes = await TryOnService().getTryOnJobStatus(token, jobId);
        final status = statusRes['status'];
        if (!mounted) { timer.cancel(); return; }

        if (status == 'done') {
          timer.cancel();
          setState(() {
            tryOnLoading = false;
            tryOnResultUrl = statusRes['result_image_url'];
            aiAdvice = statusRes['ai_notes'] ?? 'Looking good!';
          });
        } else if (status == 'failed') {
          timer.cancel();
          setState(() { tryOnLoading = false; errorMessage = 'Failed on server.'; });
        }
      } catch (_) {}
    });
  }

  void _discardResult() {
    _pollTimer?.cancel();
    setState(() { _resetTryOnState(clearSelection: false); });
  }

  Future<void> _saveLook() async { 
    if (tryOnResultUrl == null) return;
    try {
      LooksStore.I.add(Look(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        seasons: seasons,
        style: style,
        imageUrl: tryOnResultUrl!,
        advice: aiAdvice,
        items: [
          if (manualOutfit.top != null) manualOutfit.top!,
          if (manualOutfit.bottom != null) manualOutfit.bottom!,
          if (manualOutfit.outer != null) manualOutfit.outer!,
          if (manualOutfit.shoes != null) manualOutfit.shoes!,
        ],
      ));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved ✅')));
    } catch (_) {}
  }

  void _resetTryOnState({required bool clearSelection}) {
    _pollTimer?.cancel();
    tryOnLoading = false;
    errorMessage = null;
    tryOnJobId = null;
    tryOnResultUrl = null;
    aiAdvice = null;
    if (clearSelection) selectedOutfit = null;
  }
}
