import 'package:flutter/material.dart';

import '../models/media_asset.dart';
import 'cms_scope.dart';
import 'feedback.dart';

/// An image's usage-rights status; tapping it records or edits them.
/// [onChanged] fires after a save, so a page can recount what's left
/// before publishing.
class ImageRightsChip extends StatefulWidget {
  final String objectName;
  final VoidCallback? onChanged;

  const ImageRightsChip({super.key, required this.objectName, this.onChanged});

  @override
  State<ImageRightsChip> createState() => _ImageRightsChipState();
}

class _ImageRightsChipState extends State<ImageRightsChip> {
  MediaAsset? _asset;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void didUpdateWidget(ImageRightsChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objectName != widget.objectName) {
      setState(() {
        _asset = null;
        _failed = false;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final name = widget.objectName;
    try {
      final assets = await CmsScope.read(context).listAssets([name]);
      if (!mounted || name != widget.objectName) return;
      setState(() {
        _asset = assets.firstOrNull ?? MediaAsset(objectName: name);
        _failed = false;
      });
    } catch (_) {
      if (mounted && name == widget.objectName) setState(() => _failed = true);
    }
  }

  Future<void> _edit() async {
    if (_failed) {
      setState(() => _failed = false);
      return _load();
    }
    final asset = _asset;
    if (asset == null) return;
    final saved = await showImageRightsDialog(context, asset);
    if (saved == null || !mounted) return;
    setState(() => _asset = saved);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final asset = _asset;
    final (icon, text, color) = switch (asset) {
      _ when _failed => (Icons.refresh, '使用權：讀取失敗，點此重試', scheme.error),
      null => (Icons.hourglass_empty, '使用權：讀取中', scheme.outline),
      MediaAsset(:final usable) when usable => (
        Icons.verified_outlined,
        '使用權：已確認',
        Colors.green.shade700,
      ),
      MediaAsset(:final expired) when expired => (
        Icons.event_busy_outlined,
        '使用權：已過期',
        scheme.error,
      ),
      MediaAsset(:final exists) when exists => (
        Icons.pending_outlined,
        '使用權：未確認',
        Colors.orange.shade800,
      ),
      _ => (Icons.report_gmailerrorred_outlined, '使用權：未登記', scheme.error),
    };
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(text),
      onPressed: _edit,
    );
  }
}

/// Edits one image's credit and usage rights; returns the saved record, or
/// null when cancelled.
Future<MediaAsset?> showImageRightsDialog(
  BuildContext context,
  MediaAsset asset,
) => showDialog<MediaAsset>(
  context: context,
  builder: (context) => _ImageRightsDialog(asset),
);

class _ImageRightsDialog extends StatefulWidget {
  final MediaAsset asset;
  const _ImageRightsDialog(this.asset);

  @override
  State<_ImageRightsDialog> createState() => _ImageRightsDialogState();
}

class _ImageRightsDialogState extends State<_ImageRightsDialog> {
  late final _credit = TextEditingController(text: widget.asset.credit);
  late final _sourceUrl = TextEditingController(text: widget.asset.sourceUrl);
  late final _holder = TextEditingController(text: widget.asset.rightsHolder);
  late final _note = TextEditingController(text: widget.asset.licenseNote);
  late LicenseType _type = widget.asset.licenseType;
  late DateTime? _expires = widget.asset.licenseExpiresOn;
  late bool _confirmed = widget.asset.rightsConfirmed;
  bool _saving = false;

  @override
  void dispose() {
    _credit.dispose();
    _sourceUrl.dispose();
    _holder.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expires ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _expires = picked);
  }

  bool get _ai => _type == LicenseType.aiGenerated;

  Future<void> _save() async {
    if (_saving) return;
    if (_ai && _credit.text.trim().isEmpty) {
      showMessage(context, 'AI 生成的圖要填生成工具');
      return;
    }
    final url = _sourceUrl.text.trim();
    if (url.isNotEmpty && !RegExp(r'^https?://\S+$').hasMatch(url)) {
      showMessage(context, '取得網址要以 http:// 或 https:// 開頭');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await CmsScope.read(context).saveAsset(
        mediaAssetBody(
          objectName: widget.asset.objectName,
          credit: _credit.text,
          sourceUrl: url,
          licenseType: _type,
          rightsHolder: _holder.text,
          licenseNote: _note.text,
          licenseExpiresOn: _expires,
          rightsConfirmed: _confirmed && _type != LicenseType.unknown,
        ),
      );
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) await showErrorDialog(context, e, title: '儲存失敗');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expires = _expires;
    InputDecoration field(String label, {String? helper}) => InputDecoration(
      labelText: label,
      helperText: helper,
      border: const OutlineInputBorder(),
      isDense: true,
    );
    return AlertDialog(
      title: const Text('圖片出處與使用權'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '登記出處不等於取得使用權。只有確認取得使用權、且未過期的圖片，'
                '才能用在要發佈的內容。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _credit,
                maxLength: 100,
                decoration: _ai
                    ? field(
                        '生成工具（必填，例：Midjourney v7）',
                        helper: 'App 的出處資訊會顯示為「AI 生成影像」',
                      )
                    : field('攝影／出處署名', helper: 'App 會顯示在文章的出處資訊'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sourceUrl,
                maxLength: 500,
                decoration: field('取得網址（選填）'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<LicenseType>(
                initialValue: _type,
                decoration: field('使用權來源'),
                items: [
                  for (final type in LicenseType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (type) => setState(() {
                  _type = type ?? LicenseType.unknown;
                  if (_type == LicenseType.unknown) _confirmed = false;
                }),
              ),
              if (_ai) ...[const SizedBox(height: 8), _AiNotice()],
              const SizedBox(height: 16),
              TextField(
                controller: _holder,
                maxLength: 100,
                decoration: field('權利人（選填）'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _note,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: field('授權說明（選填）', helper: '使用範圍、授權證明放在哪裡等'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expires == null
                          ? '授權期限：不限'
                          : '授權期限：${MaterialLocalizations.of(context).formatMediumDate(expires)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickExpiry,
                    child: const Text('設定到期日'),
                  ),
                  if (expires != null)
                    TextButton(
                      onPressed: () => setState(() => _expires = null),
                      child: const Text('清除'),
                    ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmed && _type != LicenseType.unknown,
                onChanged: _type == LicenseType.unknown
                    ? null
                    : (value) => setState(() => _confirmed = value ?? false),
                title: const Text('我已確認取得這張圖片的使用權'),
                subtitle: _type == LicenseType.unknown
                    ? const Text('先選擇使用權來源')
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('儲存'),
        ),
      ],
    );
  }
}

class _AiNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          '・使用權依生成工具的條款：確認你的方案允許商用，並在授權說明記下工具、方案與生成日期。\n'
          '・不要用來呈現真實商品（單品照、Selection、Breakdown 的單品），也避免畫出真實品牌標誌或像真人的臉。',
          style: TextStyle(color: scheme.onTertiaryContainer),
        ),
      ),
    );
  }
}
