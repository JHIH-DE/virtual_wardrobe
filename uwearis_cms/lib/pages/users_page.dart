import 'dart:async';

import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../widgets/cms_scope.dart';
import '../widgets/feedback.dart';
import 'user_detail_page.dart';

/// Every App account, newest first, searchable by email, name or id.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  Timer? _debounce;
  bool _adminsOnly = false;
  List<AdminUserSummary>? _users;
  int _total = 0;
  int _page = 1;
  Object? _error;
  int _requestId = 0;

  /// Sorts only the loaded page: the backend always pages by id, newest first.
  int? _sortColumn = 0;
  bool _sortAscending = true;

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
      final result = await CmsScope.read(context).listUsers(
        query: _search.text,
        isAdmin: _adminsOnly ? true : null,
        page: page,
        size: _pageSize,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _users = result.items;
        _total = result.total;
        _page = page;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    }
  }

  Future<void> _open(AdminUserSummary user) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => UserDetailPage(userId: user.id)),
    );
    if (mounted) await _load(page: _page);
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    final error = _error;
    final pages = (_total / _pageSize).ceil();
    return Scaffold(
      appBar: AppBar(
        title: const Text('使用者'),
        actions: [
          FilterChip(
            label: const Text('只看管理員'),
            selected: _adminsOnly,
            onSelected: (value) {
              setState(() => _adminsOnly = value);
              _load();
            },
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 300,
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: '搜尋 email、名稱或 id',
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
          ),
        ],
      ),
      body: error != null
          ? Center(child: Text(errorText(error)))
          : users == null
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? const Center(child: Text('找不到符合的使用者。'))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_sortColumn != null && pages > 1)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '排序只套用目前這一頁',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: _UserTable(
                            users: users,
                            onOpen: _open,
                            sortColumn: _sortColumn,
                            sortAscending: _sortAscending,
                            onSort: (column, ascending) => setState(() {
                              _sortColumn = column;
                              _sortAscending = ascending;
                            }),
                          ),
                        ),
                      ],
                    ),
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
                        Text('$_page / $pages（共 $_total 位）'),
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

class _UserTable extends StatelessWidget {
  final List<AdminUserSummary> users;
  final ValueChanged<AdminUserSummary> onOpen;
  final int? sortColumn;
  final bool sortAscending;
  final void Function(int column, bool ascending) onSort;

  const _UserTable({
    required this.users,
    required this.onOpen,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  /// One key per column, in column order. Missing values sort last either way.
  static final List<Comparable<Object>? Function(AdminUserSummary)> _keys = [
    (u) => u.id,
    (u) => u.email.toLowerCase(),
    (u) => u.name?.toLowerCase(),
    (u) => u.authProvider,
    (u) => u.pointsBalance,
    (u) => u.subscriptionActive
        ? u.subscriptionExpiresAt?.millisecondsSinceEpoch
        : null,
    (u) => u.isAdmin ? 1 : 0,
    (u) => u.createdAt?.millisecondsSinceEpoch,
  ];

  List<AdminUserSummary> get _sorted {
    final column = sortColumn;
    if (column == null) return users;
    final key = _keys[column];
    return [...users]..sort((a, b) {
      final ka = key(a);
      final kb = key(b);
      if (ka == null || kb == null) {
        return ka == null ? (kb == null ? a.id.compareTo(b.id) : 1) : -1;
      }
      final c = sortAscending ? ka.compareTo(kb) : kb.compareTo(ka);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    DataColumn column(String label, {bool numeric = false}) =>
        DataColumn(label: Text(label), numeric: numeric, onSort: onSort);
    return DataTable(
      showCheckboxColumn: false,
      sortColumnIndex: sortColumn,
      sortAscending: sortAscending,
      columns: [
        column('ID', numeric: true),
        column('Email'),
        column('名稱'),
        column('登入方式'),
        column('點數', numeric: true),
        column('訂閱'),
        column('管理員'),
        column('註冊日'),
      ],
      rows: [
        for (final user in _sorted)
          DataRow(
            onSelectChanged: (_) => onOpen(user),
            cells: [
              DataCell(Text('${user.id}')),
              DataCell(Text(user.email)),
              DataCell(Text(user.name ?? '—')),
              DataCell(Text(authProviderLabel(user.authProvider))),
              DataCell(Text('${user.pointsBalance}')),
              DataCell(
                Text(
                  user.subscriptionActive
                      ? '到 ${_date(user.subscriptionExpiresAt)}'
                      : '—',
                ),
              ),
              DataCell(
                user.isAdmin
                    ? const Icon(Icons.verified_user_outlined, size: 18)
                    : const SizedBox.shrink(),
              ),
              DataCell(Text(_date(user.createdAt))),
            ],
          ),
      ],
    );
  }

  static String _date(DateTime? t) => t == null ? '—' : formatTaipeiDate(t);
}
