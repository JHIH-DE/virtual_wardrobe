import 'package:flutter/material.dart';
import 'package:uwearis/data/magazine.dart';

import '../models/admin_models.dart';
import '../models/story_draft.dart';
import '../widgets/bilingual_field.dart';
import '../widgets/cms_scope.dart';
import '../widgets/feedback.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/pickers.dart';

/// A featured item. Linking a catalog product makes it buyable in the App.
class ItemEditorPage extends StatefulWidget {
  /// Null creates a new item.
  final AdminItem? item;
  const ItemEditorPage({super.key, this.item});

  @override
  State<ItemEditorPage> createState() => _ItemEditorPageState();
}

class _ItemEditorPageState extends State<ItemEditorPage> {
  late AdminItem? _item = widget.item;
  final _name = Bilingual();
  final _description = Bilingual();
  final _brand = TextEditingController();
  final _category = TextEditingController();
  final _subCategory = TextEditingController();
  String? _imageObjectName;
  String? _imageUrl;
  String? _tryOnObjectName;
  String? _tryOnUrl;
  MagazineProduct? _product;
  bool _busy = false;
  bool _dirty = false;
  int _formVersion = 0;

  @override
  void initState() {
    super.initState();
    final item = _item;
    if (item != null) _apply(item);
  }

  @override
  void dispose() {
    _brand.dispose();
    _category.dispose();
    _subCategory.dispose();
    super.dispose();
  }

  void _apply(AdminItem item) {
    _item = item;
    _name
      ..zhTw = item.nameZhTw ?? ''
      ..en = item.nameEn ?? '';
    _description
      ..zhTw = item.descriptionZhTw ?? ''
      ..en = item.descriptionEn ?? '';
    _brand.text = item.brand ?? '';
    _category.text = item.category ?? '';
    _subCategory.text = item.subCategory ?? '';
    _imageObjectName = item.imageObjectName;
    _imageUrl = item.imageUrl;
    _tryOnObjectName = item.tryOnObjectName;
    _tryOnUrl = item.tryOnUrl;
    _product = item.product;
    _dirty = false;
    _formVersion++;
  }

  void _changed([VoidCallback? change]) => setState(() {
    change?.call();
    _dirty = true;
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) await showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
    if (_name.isEmpty) {
      showMessage(context, '請至少填一種語言的名稱');
      return;
    }
    final saved = await CmsScope.read(context).saveItem(_item?.id, {
      'name_zh_tw': _name.zhTw,
      'name_en': _name.en,
      'brand': _brand.text,
      'category': _category.text,
      'sub_category': _subCategory.text,
      'description_zh_tw': _description.zhTw,
      'description_en': _description.en,
      'image_object_name': _imageObjectName,
      'tryon_object_name': _tryOnObjectName,
      'product_id': _product?.id,
    });
    if (!mounted) return;
    setState(() => _apply(saved));
    showMessage(context, '已儲存');
  });

  Future<void> _delete() => _run(() async {
    final ok = await confirm(
      context,
      title: '刪除這個單品？',
      body: '還被文章使用的單品不能刪除。刪除後無法復原。',
      confirmLabel: '刪除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await CmsScope.read(context).deleteItem(_item!.id);
    if (mounted) Navigator.pop(context);
  });

  Future<void> _linkProduct() async {
    final picked = await pickProduct(context);
    if (picked == null || !mounted) return;
    _changed(() {
      _product = picked.product;
      if (_brand.text.trim().isEmpty) _brand.text = picked.product.brand;
    });
  }

  Future<void> _leave() async {
    if (_dirty && !await confirmDiscard(context)) return;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = _item == null;
    final product = _product;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: Text(isNew ? '新增單品' : '編輯單品'),
          actions: [
            if (!isNew)
              IconButton(
                tooltip: '刪除',
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _busy || (!_dirty && !isNew) ? null : _save,
                child: Text(isNew ? '建立' : '儲存'),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                key: ValueKey(_formVersion),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BilingualField(
                    label: '名稱',
                    value: _name,
                    onChanged: _changed,
                    maxLength: 255,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _textField(_brand, '品牌')),
                      const SizedBox(width: 12),
                      Expanded(child: _textField(_category, '類別（選填，例：Top）')),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _textField(_subCategory, '子類別（選填，例：Shirts）'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  BilingualField(
                    label: '介紹（選填）',
                    value: _description,
                    onChanged: _changed,
                    multiline: true,
                    maxLength: 2000,
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 48,
                    runSpacing: 24,
                    children: [
                      ImageUploadField(
                        label: '商品圖（白底效果最好）',
                        url: _imageUrl,
                        objectName: _imageObjectName,
                        previewHeight: 180,
                        onUploaded: (img) => _changed(() {
                          _imageObjectName = img.objectName;
                          _imageUrl = img.readUrl;
                        }),
                        onRemoved: () => _changed(() {
                          _imageObjectName = null;
                          _imageUrl = null;
                        }),
                      ),
                      ImageUploadField(
                        label: '試穿用去背圖（選填，之後的試穿功能用）',
                        url: _tryOnUrl,
                        previewHeight: 180,
                        onUploaded: (img) => _changed(() {
                          _tryOnObjectName = img.objectName;
                          _tryOnUrl = img.readUrl;
                        }),
                        onRemoved: () => _changed(() {
                          _tryOnObjectName = null;
                          _tryOnUrl = null;
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('商城商品', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '連結商品後，App 會在這個單品顯示價格和「前往購買」。沒連結就只是介紹。',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        product == null
                            ? Icons.link_off
                            : Icons.shopping_bag_outlined,
                      ),
                      title: Text(product == null ? '沒有連結商品' : product.name),
                      subtitle: product == null
                          ? null
                          : Text(
                              [
                                product.brand,
                                if (product.price != null)
                                  '${product.currency} ${product.price}',
                                product.isAvailable ? '販售中' : '已下架（App 不會顯示購買）',
                              ].join(' · '),
                            ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _linkProduct,
                            child: Text(product == null ? '連結商品' : '更換'),
                          ),
                          if (product != null)
                            TextButton(
                              onPressed: () => _changed(() => _product = null),
                              child: const Text('取消連結'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (_) => _changed(),
      );
}
