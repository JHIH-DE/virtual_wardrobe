import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../app/theme/app_colors.dart';
import '../core/services/auth_api.dart';
import '../core/services/token_storage.dart';
import '../l10n/app_strings.dart';
import '../data/looks_store.dart';
import 'garment_category.dart';
import 'select_garment_page.dart';
import '../core/services/auth_api.dart';

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

  // 暫時用假資料（之後接 ClosetStore / backend）
  final List<Garment> _allGarments = [];

  bool generating = false;

  // TODO: Replace with models later
  final List<Map<String, dynamic>> suggestedOutfits = [];
  Map<String, dynamic>? selectedOutfit;

  // Try-On Job / Result
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
    _loadGarments(); // 呼叫 async 方法
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = selectedOutfit != null;

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

          _buildTryOnResultCard(context),
        ],
      ),
    );
  }

  Widget _buildTryOnSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: tryOnLoading ? null : _startTryOn,
          icon: const Icon(Icons.image_outlined),
          label: Text(tryOnLoading ? AppStrings.tryingOn : AppStrings.tryOn),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),

        const SizedBox(height: 12),

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

          // Image frame
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

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Missing access token. Please login again.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await AuthApi.getGarments(token);

      if (!mounted) return;
      setState(() {
        _allGarments
          ..clear()
          ..addAll(list);
      });
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
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
            // small marker
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

            // 切換模式時，避免狀態混在一起（你可視需求保留/清掉）
            _resetTryOnState(clearSelection: false);
            errorMessage = null;

            if (_mode == OutfitMode.my) {
              selectedOutfit = null;        // AI outfit selection
              suggestedOutfits.clear();     // AI suggestions
            } else {
              // 進 AI 模式時可以選擇不清 manualOutfit（我建議保留）
              // manualOutfit = const OutfitSelection(); // 如果你想清空再打開
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
              // 你若想：選完就清掉舊結果
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

  Widget _buildTryOnResultByMode(BuildContext context) {
    final hasAiSelection = selectedOutfit != null;
    final hasManualSelection = manualOutfit.canTryOn;

      if (!hasManualSelection && !hasAiSelection && tryOnResultUrl == null) {
        return const Text(
        AppStrings.selectOutfitFirst,
        style: TextStyle(color: AppColors.textSecondary),
        );
      }
      return _buildTryOnSection(context);
  }

  Widget _buildTryOnResultCard(BuildContext context) {
    return _sectionCard(
      title: AppStrings.tryOnResult,
      child: _buildTryOnResultByMode(context),
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
                onTap: () {
                  // 防止觸發 row 的 onTap
                  onClear();
                },
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
      // 重新生成時，清掉上一次選擇與結果（避免混亂）
      selectedOutfit = null;
      _resetTryOnState(clearSelection: false);
      suggestedOutfits.clear();
    });

    try {
      // TODO: Call backend /outfits/suggest with seasons/style
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() {
        suggestedOutfits.addAll([
          {
            'outfit_id': 'o1',
            'title': 'Outfit 1',
            'summary': '$style • $seasons',
          },
          {
            'outfit_id': 'o2',
            'title': 'Outfit 2',
            'summary': 'Classic • Work',
          },
          {
            'outfit_id': 'o3',
            'title': 'Outfit 3',
            'summary': 'Street • Date',
          },
        ]);
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to generate outfits. Please try again.';
      });
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> _startTryOn() async {
    if (selectedOutfit == null) return;

    // 先清掉舊結果
    _pollTimer?.cancel();
    setState(() {
      tryOnLoading = true;
      errorMessage = null;
      tryOnJobId = null;
      tryOnResultUrl = null;
      aiAdvice = null;
    });

    try {
      final outfitId = selectedOutfit!['outfit_id'] as String;

      // TODO: 1) POST /tryon -> job_id
      // final jobId = await TryOnService.createJob(outfitId: outfitId);
      final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}'; // demo

      if (!mounted) return;
      setState(() => tryOnJobId = jobId);

      // TODO: 2) Poll GET /tryon/{jobId} until done/failed
      int tick = 0;
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
        tick++;

        // ===== Demo logic =====
        // Replace with real API:
        // final job = await TryOnService.getJob(jobId);
        // if (job.status == 'done') ...
        // if (job.status == 'failed') ...
        if (!mounted) {
          t.cancel();
          return;
        }

        if (tick >= 3) {
          t.cancel();
          setState(() {
            tryOnLoading = false;
            tryOnResultUrl = 'https://picsum.photos/600/800';
            aiAdvice =
            'Looks balanced. Pair with white sneakers for a cleaner silhouette.';
          });
        }
        // ======================
      });
    } catch (e) {
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() {
        tryOnLoading = false;
        errorMessage = 'Try-On failed. Please try again.';
      });
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
            ? Container(
          color: AppColors.border,
          child: const Icon(Icons.image_not_supported, size: 16, color: AppColors.textSecondary),
        )
            : (u.startsWith('http://') || u.startsWith('https://'))
            ? Image.network(u, fit: BoxFit.cover)
            : Image.file(File(u), fit: BoxFit.cover),
      ),
    );
  }

  Future<void> _startTryOnManual() async {
    if (!manualOutfit.canTryOn) {
      setState(() => errorMessage = 'Select Top + Bottom first.');
      return;
    }

    // 清掉舊結果
    _pollTimer?.cancel();
    setState(() {
      tryOnLoading = true;
      errorMessage = null;
      tryOnJobId = null;
      tryOnResultUrl = null;
      aiAdvice = null;

      // 手動 try on 不依賴 suggested outfit
      selectedOutfit = null;
    });

    try {
      // TODO: 你未來後端可以傳 garment ids：
      // POST /tryon/manual {top_id, bottom_id, outer_id?, shoes_id?, accessory_id?, seasons, style}
      final jobId = 'job_${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;
      setState(() => tryOnJobId = jobId);

      int tick = 0;
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
        tick++;
        if (!mounted) {
          t.cancel();
          return;
        }

        if (tick >= 3) {
          t.cancel();
          setState(() {
            tryOnLoading = false;
            tryOnResultUrl = 'https://picsum.photos/600/800';
            aiAdvice = 'Great choice. Consider keeping accessories subtle for a cleaner silhouette.';
          });
        }
      });
    } catch (e) {
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() {
        tryOnLoading = false;
        errorMessage = 'Try-On failed. Please try again.';
      });
    }
  }

  void _discardResult() {
    _pollTimer?.cancel();
    setState(() {
      _resetTryOnState(clearSelection: false);
    });
  }

  Future<void> _saveLook() async {
    if (selectedOutfit == null || tryOnResultUrl == null) return;

    try {
      LooksStore.I.add(
        Look(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          seasons: seasons,
          style: style,
          imageUrl: tryOnResultUrl!,
          advice: aiAdvice,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved to Looks ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save. Please try again.')),
      );
    }
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