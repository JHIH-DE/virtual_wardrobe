import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../widgets/cms_scope.dart';
import '../widgets/feedback.dart';
import '../widgets/status_chip.dart';
import 'issue_editor_page.dart';

class IssuesPage extends StatefulWidget {
  const IssuesPage({super.key});

  @override
  State<IssuesPage> createState() => _IssuesPageState();
}

class _IssuesPageState extends State<IssuesPage> {
  List<AdminIssue>? _issues;
  Object? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final issues = await CmsScope.read(context).listIssues();
      if (mounted) setState(() => _issues = issues);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(AdminIssue? issue) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => IssueEditorPage(issueId: issue?.id),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final issues = _issues;
    final error = _error;
    return Scaffold(
      appBar: AppBar(
        title: const Text('期數與文章'),
        actions: [
          IconButton(
            tooltip: '重新整理',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: FilledButton.icon(
              onPressed: () => _open(null),
              icon: const Icon(Icons.add),
              label: const Text('新增一期'),
            ),
          ),
        ],
      ),
      body: error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorText(error)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('重試')),
                ],
              ),
            )
          : issues == null
          ? const Center(child: CircularProgressIndicator())
          : issues.isEmpty
          ? const Center(child: Text('還沒有任何一期。按右上角「新增一期」開始。'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: issues.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final issue = issues[i];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: SizedBox.square(
                      dimension: 56,
                      child: issue.coverUrl == null
                          ? const Icon(Icons.menu_book_outlined)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(
                                issue.coverUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                    title: Text(
                      [
                        if (issue.issueNumber != null)
                          '第 ${issue.issueNumber} 期',
                        issue.displayTitle,
                      ].join('　'),
                    ),
                    subtitle: Text('${issue.slug} · ${issue.storyCount} 篇文章'),
                    trailing: StatusChip(issue.status),
                    onTap: () => _open(issue),
                  ),
                );
              },
            ),
    );
  }
}
