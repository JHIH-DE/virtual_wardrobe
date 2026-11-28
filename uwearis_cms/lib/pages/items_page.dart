import 'dart:async';

import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../widgets/cms_scope.dart';
import '../widgets/feedback.dart';
import 'item_editor_page.dart';

/// Every featured item the magazine can show, searchable.
class ItemsPage extends StatefulWidget {
  const ItemsPage({super.key});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  static const _pageSize = 50;

  final _search = TextEditingController();
  Timer? _debounce;
  List<AdminItem>? _items;
  int _total = 0;
  int _page = 1;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    final id = ++_requestId;
    setState(() => _error = null);
    try {
      final result = await CmsScope.read(
        context,
      ).listItems(query: _search.text, page: page, size: _pageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = page;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    }
  }

  Future<void> _open(AdminItem? item) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ItemEditorPage(item: item)),
    );
    if (mounted) await _load(page: _page);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final error = _error;
    final pages = (_total / _pageSize).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('單品'),
        actions: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: '搜尋名稱或品牌',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), _load);
              },
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _open(null),
              icon: const Icon(Icons.add),
              label: const Text('新增單品'),
            ),
          ),
        ],
      ),
      body: error != null
          ? Center(child: Text(errorText(error)))
          : items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
          ? Center(
              child: Text(
                _search.text.isEmpty ? '還沒有單品。按右上角「新增單品」開始。' : '找不到符合的單品。',
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, i) =>
                        _ItemTile(item: items[i], onTap: () => _open(items[i])),
                  ),
                ),
                if (pages > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _page > 1
                              ? () => _load(page: _page - 1)
                              : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('$_page / $pages（共 $_total 個）'),
                        IconButton(
                          onPressed: _page < pages
                              ? () => _load(page: _page + 1)
                              : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final AdminItem item;
  final VoidCallback onTap;
  const _ItemTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = item.imageUrl;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: url == null
                    ? Icon(
                        Icons.checkroom_outlined,
                        size: 40,
                        color: scheme.outline,
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (item.brand != null) item.brand!,
                      item.product == null ? '只介紹' : '可購買',
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
