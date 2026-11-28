import 'package:flutter/material.dart';

import '../models/admin_models.dart';
import '../models/story_draft.dart';
import '../widgets/bilingual_field.dart';
import '../widgets/cms_scope.dart';
import '../widgets/feedback.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/status_chip.dart';
import '../widgets/import_draft_dialog.dart';
import 'story_editor_page.dart';

/// One issue: its fields, publishing, and its stories in reading order.
class IssueEditorPage extends StatefulWidget {
  /// Null creates a new issue.
  final int? issueId;
  const IssueEditorPage({super.key, this.issueId});

  @override
  State<IssueEditorPage> createState() => _IssueEditorPageState();
}

class _IssueEditorPageState extends State<IssueEditorPage> {
  final _slug = TextEditingController();
  final _number = TextEditingController();
  final _title = Bilingual();
  final _subtitle = Bilingual();
  String? _coverObjectName;
  String? _coverUrl;

  AdminIssue? _issue;
  List<AdminStorySummary> _stories = [];
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  Object? _loadError;

  /// Changes when the loaded issue does, so the text fields re-read it.
  int _formVersion = 0;

  int? get _issueId => _issue?.id ?? widget.issueId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _slug.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = _issueId;
    if (id == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = CmsScope.read(context);
      final results = await Future.wait([
        api.getIssue(id),
        api.listStories(id),
      ]);
      if (!mounted) return;
      _apply(results[0] as AdminIssue);
      setState(() => _stories = results[1] as List<AdminStorySummary>);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(AdminIssue issue) {
    setState(() {
      _issue = issue;
      _slug.text = issue.slug;
      _number.text = issue.issueNumber?.toString() ?? '';
      _title
        ..zhTw = issue.titleZhTw ?? ''
        ..en = issue.titleEn ?? '';
      _subtitle
        ..zhTw = issue.subtitleZhTw ?? ''
        ..en = issue.subtitleEn ?? '';
      _coverObjectName = issue.coverObjectName;
      _coverUrl = issue.coverUrl;
      _dirty = false;
      _formVersion++;
    });
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

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
    final slug = _slug.text.trim();
    if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(slug)) {
      showMessage(context, '網址代稱只能用小寫英文、數字和 -（例：issue-01）');
      return;
    }
    final number = _number.text.trim();
    final issue = await CmsScope.read(context).saveIssue(_issueId, {
      'slug': slug,
      'issue_number': number.isEmpty ? null : int.tryParse(number),
      'title_zh_tw': _title.zhTw,
      'title_en': _title.en,
      'subtitle_zh_tw': _subtitle.zhTw,
      'subtitle_en': _subtitle.en,
      'cover_object_name': _coverObjectName,
    });
    if (!mounted) return;
    _apply(issue);
    showMessage(context, '已儲存');
  });

  Future<void> _togglePublished() => _run(() async {
    final issue = _issue!;
    final publish = issue.status != PublishStatus.published;
    if (_dirty) {
      showMessage(context, '請先儲存修改');
      return;
    }
    if (publish && !_stories.any((s) => s.status == PublishStatus.published)) {
      final go = await confirm(
        context,
        title: '這一期還沒有已發佈的文章',
        body: '發佈後 App 會顯示這一期，但沒有任何文章。確定要發佈嗎？',
        confirmLabel: '仍要發佈',
      );
      if (!go || !mounted) return;
    }
    final updated = await CmsScope.read(
      context,
    ).setIssuePublished(issue.id, publish);
    if (!mounted) return;
    _apply(updated);
    showMessage(context, publish ? '已發佈，App 現在看得到這一期' : '已取消發佈');
  });

  Future<void> _delete() => _run(() async {
    final ok = await confirm(
      context,
      title: '刪除這一期？',
      body: '只能刪除沒有文章的期數。刪除後無法復原。',
      confirmLabel: '刪除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await CmsScope.read(context).deleteIssue(_issue!.id);
    if (mounted) Navigator.pop(context);
  });

  Future<void> _openStory(int? storyId, {StoryDraft? imported}) async {
    final issueId = _issueId;
    if (issueId == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => StoryEditorPage(
          issueId: issueId,
          storyId: storyId,
          initialDraft: imported,
        ),
      ),
    );
    if (!mounted) return;
    try {
      final stories = await CmsScope.read(context).listStories(issueId);
      if (mounted) setState(() => _stories = stories);
    } catch (_) {}
  }

  /// Pastes a story written outside the CMS and opens it, unsaved, so the
  /// photos can be added before the first save.
  Future<void> _import() async {
    final issueId = _issueId;
    if (issueId == null) return;
    final draft = await showImportDraftDialog(context, issueId: issueId);
    if (draft != null && mounted) await _openStory(null, imported: draft);
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    final previous = List.of(_stories);
    final next = List.of(_stories);
    final moved = next.removeAt(oldIndex);
    next.insert(newIndex, moved);
    setState(() => _stories = next);
    try {
      final saved = await CmsScope.read(
        context,
      ).reorderStories(_issueId!, [for (final s in next) s.id]);
      if (mounted) setState(() => _stories = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _stories = previous);
      await showErrorDialog(context, e, title: '排序失敗');
    }
  }

  Future<void> _leave() async {
    if (_dirty && !await confirmDiscard(context)) return;
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final issue = _issue;
    final isNew = _issueId == null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: Text(isNew ? '新增一期' : '編輯期數'),
          actions: [
            if (issue != null) ...[
              Center(child: StatusChip(issue.status)),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _busy ? null : _togglePublished,
                child: Text(
                  issue.status == PublishStatus.published ? '取消發佈' : '發佈',
                ),
              ),
              IconButton(
                tooltip: '刪除',
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _busy || (!_dirty && !isNew) ? null : _save,
                child: Text(isNew ? '建立' : '儲存'),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? Center(child: Text(errorText(_loadError!)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      key: ValueKey(_formVersion),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _slug,
                                decoration: const InputDecoration(
                                  labelText: '網址代稱（slug）',
                                  helperText: '小寫英文、數字和 -，例：issue-01',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (_) => _markDirty(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _number,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '期數編號（選填）',
                                  helperText: ' ',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (_) => _markDirty(),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        BilingualField(
                          label: '標題',
                          value: _title,
                          onChanged: _markDirty,
                          maxLength: 200,
                        ),
                        const SizedBox(height: 16),
                        BilingualField(
                          label: '副標',
                          value: _subtitle,
                          onChanged: _markDirty,
                          maxLength: 500,
                        ),
                        const SizedBox(height: 16),
                        ImageUploadField(
                          label: '封面',
                          url: _coverUrl,
                          objectName: _coverObjectName,
                          onUploaded: (img) => setState(() {
                            _coverObjectName = img.objectName;
                            _coverUrl = img.readUrl;
                            _dirty = true;
                          }),
                          onRemoved: () => setState(() {
                            _coverObjectName = null;
                            _coverUrl = null;
                            _dirty = true;
                          }),
                        ),
                        const SizedBox(height: 32),
                        _buildStories(isNew),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStories(bool isNew) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('文章', style: theme.textTheme.titleLarge),
            const SizedBox(width: 12),
            if (!isNew)
              Text(
                '拖拉調整 App 上的順序',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: isNew ? null : _import,
              icon: const Icon(Icons.file_open_outlined),
              label: const Text('匯入草稿'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: isNew ? null : () => _openStory(null),
              icon: const Icon(Icons.add),
              label: const Text('新增文章'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isNew)
          const Text('先建立這一期，才能新增文章。')
        else if (_stories.isEmpty)
          const Text('這一期還沒有文章。')
        else
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: _reorder,
            children: [
              for (final (i, story) in _stories.indexed)
                Card(
                  key: ValueKey(story.id),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(story.displayTitle),
                    subtitle: Text(
                      '${story.slug} · 對象：${_audienceLabel(story)}',
                    ),
                    trailing: StatusChip(story.status),
                    onTap: () => _openStory(story.id),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  static String _audienceLabel(AdminStorySummary story) =>
      switch (story.audience.apiValue) {
        'men' => '男生',
        'women' => '女生',
        _ => '全部',
      };
}
