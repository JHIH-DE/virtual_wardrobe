import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme/app_colors.dart';
import '../core/services/error_handler.dart';
import '../core/services/garments_service.dart';
import '../core/services/outfit_service.dart';
import '../../data/look_category.dart';
import '../../data/garment_category.dart';
import '../l10n/app_strings.dart';
import 'select_garment_page.dart';

class ClosetOutfitTab extends StatefulWidget {
  const ClosetOutfitTab({super.key});

  @override
  State<ClosetOutfitTab> createState() => _ClosetOutfitTabState();
}

enum OutfitMode { my, ai }

class _ClosetOutfitTabState extends State<ClosetOutfitTab> {
  final List<Garment> _allGarments = [];
  final List<Map<String, dynamic>> _suggestedOutfits = [];

  String _selectedSeason = 'Spring';
  String _selectedStyle = 'Minimal';
  String? _tryOnResultUrl;
  String? _aiAdvice;
  String? _errorMessage;
  String? _error;
  bool _isLoading = false;
  bool _isGenerating = false;
  bool _isOutfitLoading = false;
  int _tryOnJobId = 0;
  OutfitMode _mode = OutfitMode.my;
  OutfitSelection _manualOutfit = const OutfitSelection();
  Map<String, dynamic>? _selectedOutfit;
  Timer? _pollTimer;

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
          if (_selectedOutfit != null || _manualOutfit.canTryOn || _tryOnResultUrl != null)
            _buildOutfitResultCard(context),
        ],
      ),
    );
  }

  Widget _buildOutfitResultCard(BuildContext context) {
    final bool isVisible = _tryOnResultUrl != null || _isOutfitLoading || _errorMessage != null;

    if (!isVisible) return const SizedBox.shrink();

    return _sectionCard(
      title: AppStrings.tryOnResult,
      child: _buildOutfitSection(context),
    );
  }

  Widget _buildOutfitSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isOutfitLoading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(minHeight: 4),
          ),
          const SizedBox(height: 10),
          Text(
            _tryOnJobId == 0 ? 'Creating job...' : 'Generating image…',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],

        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.25)),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
          ),
        ],

        if (_tryOnResultUrl != null) ...[
          const SizedBox(height: 12),

          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                PageRouteBuilder(
                  opaque: false,
                  pageBuilder: (_, __, ___) => FullScreenImagePage(imageUrl: _tryOnResultUrl!),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio:  3/4,
                  child: Hero(
                    tag: 'outfit_image',
                    child: Image.network(
                      _tryOnResultUrl!,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
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
            ),
          ),

          const SizedBox(height: 12),

          if (_aiAdvice != null) ...[
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
              _aiAdvice!,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 12),
          ],

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isOutfitLoading ? null : _discardResult,
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
                  onPressed: _isOutfitLoading ? null : _saveLook,
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
    setState(() => _isLoading = true);
    try {
      final list = await GarmentService().getGarments();
      if (mounted) setState(() => _allGarments..clear()..addAll(list));
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _outfitCard(Map<String, dynamic> outfit) {
    final bool isSelected = _selectedOutfit?['outfit_id'] == outfit['outfit_id'];

    return InkWell(
      onTap: _isOutfitLoading
          ? null
          : () {
        setState(() {
          _selectedOutfit = outfit;
          _resetOutfitState(clearSelection: false);
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
            _resetOutfitState(clearSelection: false);
            _errorMessage = null;
            if (_mode == OutfitMode.my) {
              _selectedOutfit = null;
              _suggestedOutfits.clear();
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
                  value: _selectedSeason,
                  items: const [
                    DropdownMenuItem(value: 'Spring', child: Text('Spring')),
                    DropdownMenuItem(value: 'Summer', child: Text('Summer')),
                    DropdownMenuItem(value: 'Autumn', child: Text('Autumn')),
                    DropdownMenuItem(value: 'Winter', child: Text('Winter')),
                  ],
                  onChanged: _isGenerating || _isOutfitLoading
                      ? null
                      : (v) => setState(() => _selectedSeason = v ?? _selectedSeason),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStyle,
                  items: const [
                    DropdownMenuItem(value: 'Minimal', child: Text('Minimal')),
                    DropdownMenuItem(value: 'Street', child: Text('Street')),
                    DropdownMenuItem(value: 'Classic', child: Text('Classic')),
                    DropdownMenuItem(value: 'Sporty', child: Text('Sporty')),
                  ],
                  onChanged: _isGenerating || _isOutfitLoading
                      ? null
                      : (v) => setState(() => _selectedStyle = v ?? _selectedStyle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _isGenerating || _isOutfitLoading ? null : _generateOutfits,
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
                  _isGenerating ? AppStrings.generating : AppStrings.generateOutfits,
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
            value: _manualOutfit.top,
            category: GarmentCategory.top,
            onPicked: (g) => setState(() {
              _manualOutfit = _manualOutfit.copyWith(top: g);
              _resetOutfitState(clearSelection: false);
            }),
            onClear: _manualOutfit.top == null
                ? null
                : () => setState(() {
              _manualOutfit = _manualOutfit.copyWith(top: null);
              _resetOutfitState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Middle',
            value: _manualOutfit.middle,
            category: GarmentCategory.top,
            onPicked: (g) => setState(() {
              _manualOutfit = _manualOutfit.copyWith(middle: g);
              _resetOutfitState(clearSelection: false);
            }),
            onClear: _manualOutfit.middle == null
                ? null
                : () => setState(() {
              _manualOutfit = _manualOutfit.copyWith(clearMiddle: true);
              _resetOutfitState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Outer',
            value: _manualOutfit.outer,
            category: GarmentCategory.outer,
            onPicked: (g) => setState(() {
              _manualOutfit = _manualOutfit.copyWith(outer: g);
              _resetOutfitState(clearSelection: false);
            }),
            onClear: _manualOutfit.outer == null
                ? null
                : () => setState(() {
              _manualOutfit = _manualOutfit.copyWith(clearOuter: true);
              _resetOutfitState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Bottom',
            value: _manualOutfit.bottom,
            category: GarmentCategory.bottom,
            onPicked: (g) => setState(() {
              _manualOutfit = _manualOutfit.copyWith(bottom: g);
              _resetOutfitState(clearSelection: false);
            }),
            onClear: _manualOutfit.bottom == null
                ? null
                : () => setState(() {
              _manualOutfit = _manualOutfit.copyWith(bottom: null);
              _resetOutfitState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Shoes',
            value: _manualOutfit.shoes,
            category: GarmentCategory.shoes,
            onPicked: (g) => setState(() {
              _manualOutfit = _manualOutfit.copyWith(shoes: g);
              _resetOutfitState(clearSelection: false);
            }),
            onClear: _manualOutfit.shoes == null
                ? null
                : () => setState(() {
              _manualOutfit = _manualOutfit.copyWith(clearShoes: true);
              _resetOutfitState(clearSelection: false);
            }),
          ),
          const SizedBox(height: 10),
          _slotRow(
            title: 'Accessory',
            value: _manualOutfit.accessory,
            category: GarmentCategory.accessory,
            onPicked: (g) => setState(() {
              _manualOutfit = _manualOutfit.copyWith(accessory: g);
              _resetOutfitState(clearSelection: false);
            }),
            onClear: _manualOutfit.accessory == null
                ? null
                : () => setState(() {
              _manualOutfit = _manualOutfit.copyWith(clearAccessory: true);
              _resetOutfitState(clearSelection: false);
            }),
          ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: (_isOutfitLoading || !_manualOutfit.canTryOn)
                ? null
                : _startTryOn,
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
                  _manualOutfit.canTryOn ? 'Try On My Outfit' : 'Select Top + Bottom first',
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
      child: _suggestedOutfits.isEmpty
          ? const Text(
        AppStrings.suggestedWarning,
        style: TextStyle(color: AppColors.textSecondary),
      )
          : Column(
        children: [
          ..._suggestedOutfits.map(_outfitCard),
        ],
      ),
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
      onTap: _isOutfitLoading
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
                  _garmentThumb(value.imageUrl),
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
      _isGenerating = true;
      _selectedOutfit = null;
      _resetOutfitState(clearSelection: false);
      _suggestedOutfits.clear();
    });

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() {
        _suggestedOutfits.addAll([
          {'outfit_id': 'o1', 'title': 'Outfit 1', 'summary': '$_selectedStyle • $_selectedSeason'},
          {'outfit_id': 'o2', 'title': 'Outfit 2', 'summary': 'Classic • Work'},
          {'outfit_id': 'o3', 'title': 'Outfit 3', 'summary': 'Street • Date'},
        ]);
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to generate outfits.');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Widget _garmentThumb(String? urlOrPath) {
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

  Future<void> _startTryOn() async {
    if (!_manualOutfit.canTryOn) {
      setState(() => _errorMessage = 'Select Top + Bottom first.');
      return;
    }

    _pollTimer?.cancel();
    setState(() {
      _isOutfitLoading = true;
      _errorMessage = null;
      _tryOnResultUrl = null;
      _aiAdvice = null;
      _selectedOutfit = null;
    });

    try {
      final List<int> ids = [];
      if (_manualOutfit.top?.id != null) ids.add(_manualOutfit.top!.id!);
      if (_manualOutfit.bottom?.id != null) ids.add(_manualOutfit.bottom!.id!);
      if (_manualOutfit.outer?.id != null) ids.add(_manualOutfit.outer!.id!);
      if (_manualOutfit.shoes?.id != null) ids.add(_manualOutfit.shoes!.id!);
      if (_manualOutfit.accessory?.id != null) ids.add(_manualOutfit.accessory!.id!);

      final jobResponse = await OutfitService().createOutfit(
        garmentIds: ids
      );

      final jobId = jobResponse['job_id'];
      if (!mounted) return;
      setState(() => _tryOnJobId = jobId);

      _startPolling(jobId);

    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isOutfitLoading = false;
        _errorMessage = 'Failed: $e';
      });
    }
  }

  void _startPolling(int jobId) {
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      attempts++;
      if (attempts > 180) {
        timer.cancel();
        if (mounted) setState(() { _isOutfitLoading = false; _errorMessage = 'Timeout.'; });
        return;
      }
      try {
        final statusRes = await OutfitService().getOutfit(jobId);
        final status = statusRes['status'];
        print('--- Try-On Job Id: $jobId ---');
        print('--- Try-On Job Status: $status ---');
        if (!mounted) { timer.cancel(); return; }

        if (status == 'completed') {
          timer.cancel();
          setState(() {
            _isOutfitLoading = false;
            _tryOnResultUrl = statusRes['result_image_url'];
            _aiAdvice = statusRes['ai_notes'] ?? 'Looking good!';
          });
          print('--- Try-On Job tryOnResultUrl: $_tryOnResultUrl ---');
        } else if (status == 'failed') {
          timer.cancel();
          setState(() { _isOutfitLoading = false; _errorMessage = 'Failed on server.'; });
        }
      } catch (_) {}
    });
  }

  void _discardResult() {
    _pollTimer?.cancel();
    _deleteOutfit(_tryOnJobId);
    setState(() { _resetOutfitState(clearSelection: false); });
  }

  Future<void> _saveLook() async { 
    if (_tryOnResultUrl == null) return;
    try {
      Look look = Look(
        id: _tryOnJobId,
        imageUrl: _tryOnResultUrl!,
        seasons: _selectedSeason,
        style: _selectedStyle,
        advice: _aiAdvice,
      );

      LooksStore.I.add(look);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved ✅')));
    } catch (_) {}
  }

  void _resetOutfitState({required bool clearSelection}) {
    _pollTimer?.cancel();
    _isOutfitLoading = false;
    _errorMessage = null;
    _tryOnResultUrl = null;
    _aiAdvice = null;
    if (clearSelection) _selectedOutfit = null;
  }

  Future<void> _deleteOutfit(int jobId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await OutfitService().deleteOutfit(jobId);
      if (!mounted) return;
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.center,
          child: Hero(
            tag: 'outfit_image',
            child: AspectRatio(
              aspectRatio: 0.6,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
