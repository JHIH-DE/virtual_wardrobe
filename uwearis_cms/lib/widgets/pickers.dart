import 'dart:async';

import 'package:flutter/material.dart';

import '../api/cms_api.dart';
import '../models/admin_models.dart';
import 'cms_scope.dart';
import 'feedback.dart';

/// Search the featured items and pick one.
Future<AdminItem?> pickItem(BuildContext context) => showDialog<AdminItem>(
  context: context,
  builder: (_) => _SearchDialog<AdminItem>(
    title: '選擇單品',
    hint: '搜尋名稱或品牌',
    search: (api, q) async => (await api.listItems(query: q)).items,
    tileBuilder: (item) => ListTile(
      leading: _Thumb(item.imageUrl),
      title: Text(item.displayName),
      subtitle: Text(
        [
          if (item.brand != null) item.brand!,
          if (item.product != null) '已連結商品',
        ].join(' · '),
      ),
    ),
    emptyText: '找不到單品。請先到「單品」頁新增。',
  ),
);

/// Search the mall catalog and pick a product to link.
Future<CatalogProduct?> pickProduct(BuildContext context) =>
    showDialog<CatalogProduct>(
      context: context,
      builder: (_) => _SearchDialog<CatalogProduct>(
        title: '連結商城商品',
        hint: '搜尋商品名稱或商品代碼',
        search: (api, q) async => (await api.searchProducts(q)).items,
        tileBuilder: (p) => ListTile(
          leading: _Thumb(p.imageUrl),
          title: Text(p.product.name),
          subtitle: Text(
            [
              p.product.brand,
              p.productCode,
              if (p.product.price != null)
                '${p.product.currency} ${p.product.price}',
              if (!p.product.isAvailable) '已下架',
            ].join(' · '),
          ),
        ),
        emptyText: '找不到商品。',
      ),
    );

class _Thumb extends StatelessWidget {
  final String? url;
  const _Thumb(this.url);

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    return SizedBox.square(
      dimension: 48,
      child: url == null
          ? const Icon(Icons.image_outlined)
          : ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    const Icon(Icons.broken_image_outlined),
              ),
            ),
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  final String title;
  final String hint;
  final Future<List<T>> Function(CmsApi api, String query) search;
  final Widget Function(T value) tileBuilder;
  final String emptyText;

  const _SearchDialog({
    required this.title,
    required this.hint,
    required this.search,
    required this.tileBuilder,
    required this.emptyText,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  Timer? _debounce;
  List<T>? _results;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run(''));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _run(String query) async {
    final id = ++_requestId;
    setState(() => _error = null);
    try {
      final results = await widget.search(CmsScope.read(context), query);
      if (mounted && id == _requestId) setState(() => _results = results);
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 560,
        height: 520,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.hint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (q) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 300),
                  () => _run(q),
                );
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _error != null
                  ? Center(child: Text(errorText(_error!)))
                  : results == null
                  ? const Center(child: CircularProgressIndicator())
                  : results.isEmpty
                  ? Center(child: Text(widget.emptyText))
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) => InkWell(
                        onTap: () => Navigator.pop(context, results[i]),
                        child: widget.tileBuilder(results[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
