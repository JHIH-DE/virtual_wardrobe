import 'package:flutter/material.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis/features/widgets/magazine/magazine_network_photo.dart';

import '../models/admin_models.dart';
import '../models/story_draft.dart';
import '../models/story_pages.dart';
import '../widgets/bilingual_field.dart';
import '../widgets/cms_scope.dart';
import '../widgets/feedback.dart';
import '../widgets/focal_point_field.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/import_draft_dialog.dart';
import '../widgets/item_row.dart';
import '../widgets/pickers.dart';
import '../widgets/status_chip.dart';
import '../widgets/story_preview.dart';
import '../widgets/story_slides_preview.dart';
import 'story_page_fields.dart';

/// A story's fields and its body (an article's blocks or a story's pages)
/// on the left, the App's rendering of it on the right, updated as you type.
class StoryEditorPage extends StatefulWidget {
  final int issueId;

  /// Null creates a new story in [issueId].
  final int? storyId;

  /// An imported draft to start a new story from (unsaved).
  final StoryDraft? initialDraft;

  const StoryEditorPage({
    super.key,
    required this.issueId,
    this.storyId,
    this.initialDraft,
  });

  @override
  State<StoryEditorPage> createState() => _StoryEditorPageState();
}

class _StoryEditorPageState extends State<StoryEditorPage> {
  static const double _previewBreakpoint = 1100;

  late StoryDraft _draft = StoryDraft(issueId: widget.issueId);
  final _slug = TextEditingController();
  List<AdminIssue> _issues = [];
  ContentLocale _previewLocale = ContentLocale.zhTw;
  bool _loading = true;
  bool _busy = false;
  bool _dirty = false;
  Object? _loadError;
  int _formVersion = 0;

  /// The story-format preview's page (0 = cover).
  int _previewIndex = 0;

  /// Images a reader would see whose rights aren't usable yet, and the set
  /// of images last checked (so typing doesn't re-query).
  int _unusableImages = 0;
  String _rightsChecked = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _slug.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = CmsScope.read(context);
    try {
      final issues = await api.listIssues();
      final storyId = widget.storyId;
      final draft = storyId == null ? null : await api.getStory(storyId);
      if (!mounted) return;
      setState(() => _issues = issues);
      if (draft != null) _apply(draft);
      if (widget.initialDraft case final imported?) {
        _apply(imported);
        setState(() => _dirty = true);
        await _loadMissingItems();
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// An imported draft names items by id only; fetch them for the form and
  /// the preview (an id that doesn't exist shows as missing).
  Future<void> _loadMissingItems() async {
    final api = CmsScope.read(context);
    for (final id in _draft.referencedItemIds.toSet()) {
      if (_draft.items.containsKey(id)) continue;
      try {
        final item = await api.getItem(id);
        if (!mounted) return;
        setState(() => _draft.items[id] = item);
      } catch (_) {}
    }
  }

  void _apply(StoryDraft draft) {
    setState(() {
      _draft = draft;
      _slug.text = draft.slug;
      _dirty = false;
      _formVersion++;
    });
    _refreshRights(force: true);
  }

  void _changed([VoidCallback? change]) {
    setState(() {
      change?.call();
      _dirty = true;
    });
    _refreshRights();
  }

  /// Recounts the images that would block publishing, when the set of
  /// images changed (or [force], after a rights edit or a save).
  Future<void> _refreshRights({bool force = false}) async {
    final names = _draft.readerImageNames;
    final key = names.join('|');
    if (!force && key == _rightsChecked) return;
    _rightsChecked = key;
    try {
      final assets = await CmsScope.read(context).listAssets(names);
      if (!mounted || key != _rightsChecked) return;
      setState(
        () => _unusableImages =
            names.length -
            assets
                .where((a) => a.usable && names.contains(a.objectName))
                .length,
      );
    } catch (_) {
      // The banner just stays as it was; publishing still checks.
    }
  }

  Future<void> _setFormat(MagazineFormat format) async {
    if (format == _draft.format) return;
    final dropped = format == MagazineFormat.story
        ? (_draft.blocks.length, '內文區塊')
        : (_draft.pages.length, '頁面');
    if (dropped.$1 > 0 &&
        !await confirm(
          context,
          title: '切換內容形式？',
          body: '切換後儲存，原本的 ${dropped.$1} 個${dropped.$2}會被清除。',
          confirmLabel: '切換',
        )) {
      return;
    }
    _changed(() => _draft.format = format);
  }

  void _addPage(PageLayout layout) => _changed(() {
    _draft.pages.add(PageDraft.create(layout));
    _previewIndex = _draft.pages.length;
  });

  void _reorderPages(int oldIndex, int newIndex) => _changed(() {
    final moved = _draft.pages.removeAt(oldIndex);
    _draft.pages.insert(newIndex, moved);
  });

  /// Shows [page] in the preview, or says why the App would skip it.
  void _previewPage(PageDraft page) {
    final slides = _draft.toPreview(_previewLocale).pages;
    final index = slides.indexWhere((slide) => slide.id == page.key);
    if (index < 0) {
      showMessage(context, '這一頁內容還不完整，App 會略過它');
      return;
    }
    setState(() => _previewIndex = index + 1);
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

  /// Validates locally first, then saves; the response replaces the draft
  /// (and signs every image it references).
  Future<bool> _saveDraft() async {
    _draft.slug = _slug.text;
    final problems = _draft.validate();
    if (problems.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('還不能儲存'),
          content: Text(problems.map((p) => '・$p').join('\n')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('好'),
            ),
          ],
        ),
      );
      return false;
    }
    final saved = await CmsScope.read(context).saveStory(_draft);
    if (!mounted) return false;
    _apply(saved);
    return true;
  }

  Future<void> _save() => _run(() async {
    if (await _saveDraft() && mounted) showMessage(context, '已儲存');
  });

  Future<void> _togglePublished() => _run(() async {
    final publish = _draft.status != PublishStatus.published;
    if (_dirty && !await _saveDraft()) return;
    if (!mounted) return;
    final updated = await CmsScope.read(
      context,
    ).setStoryPublished(_draft.id!, publish);
    if (!mounted) return;
    _apply(updated);
    final issue = _issues.where((i) => i.id == updated.issueId).firstOrNull;
    showMessage(
      context,
      !publish
          ? '已取消發佈'
          : issue?.status == PublishStatus.published
          ? '已發佈，App 現在看得到這篇文章'
          : '已發佈。這一期還沒發佈，發佈這一期後 App 才看得到。',
    );
  });

  Future<void> _delete() => _run(() async {
    final ok = await confirm(
      context,
      title: '刪除這篇文章？',
      body: '刪除後無法復原。',
      confirmLabel: '刪除',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await CmsScope.read(context).deleteStory(_draft.id!);
    if (mounted) Navigator.pop(context);
  });

  /// Replaces this new, unsaved story with one pasted as JSON.
  Future<void> _import() async {
    if (_dirty &&
        !await confirm(
          context,
          title: '用匯入的內容取代？',
          body: '目前填的內容會被匯入的草稿取代。',
          confirmLabel: '取代',
        )) {
      return;
    }
    if (!mounted) return;
    final draft = await showImportDraftDialog(context, issueId: _draft.issueId);
    if (draft == null || !mounted) return;
    _apply(draft);
    setState(() {
      _dirty = true;
      _previewIndex = 0;
    });
    await _loadMissingItems();
  }

  Future<void> _leave() async {
    if (_dirty && !await confirmDiscard(context)) return;
    if (mounted) Navigator.pop(context);
  }

  // ---- blocks ----

  void _addBlock(BlockDraft block) => _changed(() => _draft.blocks.add(block));

  Future<void> _addItemBlock() async {
    final item = await pickItem(context);
    if (item == null || !mounted) return;
    _changed(() {
      _draft.items[item.id] = item;
      _draft.blocks.add(ItemDraft(itemId: item.id));
    });
  }

  Future<void> _pickItemFor(ItemDraft block) async {
    final item = await pickItem(context);
    if (item == null || !mounted) return;
    _changed(() {
      _draft.items[item.id] = item;
      block.itemId = item.id;
    });
  }

  Future<void> _addToGroup(ItemGroupDraft block) async {
    final item = await pickItem(context);
    if (item == null || !mounted) return;
    if (block.itemIds.contains(item.id)) {
      showMessage(context, '這個單品已經在這一組裡');
      return;
    }
    _changed(() {
      _draft.items[item.id] = item;
      block.itemIds.add(item.id);
    });
  }

  void _reorderBlocks(int oldIndex, int newIndex) => _changed(() {
    final moved = _draft.blocks.removeAt(oldIndex);
    _draft.blocks.insert(newIndex, moved);
  });

  @override
  Widget build(BuildContext context) {
    final isNew = _draft.id == null;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _leave),
          title: Text(isNew ? '新增文章' : '編輯文章'),
          actions: [
            if (isNew)
              TextButton.icon(
                onPressed: _busy ? null : _import,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('匯入草稿'),
              ),
            if (!isNew) ...[
              Center(child: StatusChip(_draft.status)),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _busy ? null : _togglePublished,
                child: Text(
                  _draft.status == PublishStatus.published ? '取消發佈' : '發佈',
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
            : LayoutBuilder(
                builder: (context, constraints) {
                  final editor = _buildEditor();
                  if (constraints.maxWidth < _previewBreakpoint) return editor;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: editor),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: StoryPreview.phoneWidth + 48,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _draft.isStory
                              ? StorySlidesPreview(
                                  story: _draft.toPreview(_previewLocale),
                                  index: _previewIndex,
                                  onIndexChanged: (i) =>
                                      setState(() => _previewIndex = i),
                                  locale: _previewLocale,
                                  onLocaleChanged: (l) =>
                                      setState(() => _previewLocale = l),
                                )
                              : StoryPreview(
                                  story: _draft.toPreview(_previewLocale),
                                  locale: _previewLocale,
                                  onLocaleChanged: (l) =>
                                      setState(() => _previewLocale = l),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _buildEditor() {
    final issueIds = _issues.map((i) => i.id).toSet();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        key: ValueKey(_formVersion),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_unusableImages > 0) ...[
            _RightsBanner(count: _unusableImages),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              const Text('內容形式'),
              const SizedBox(width: 12),
              SegmentedButton<MagazineFormat>(
                segments: const [
                  ButtonSegment(
                    value: MagazineFormat.article,
                    label: Text('文章（往下捲）'),
                  ),
                  ButtonSegment(
                    value: MagazineFormat.story,
                    label: Text('Story（左右翻頁）'),
                  ),
                ],
                selected: {_draft.format},
                onSelectionChanged: (s) => _setFormat(s.single),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: issueIds.contains(_draft.issueId)
                      ? _draft.issueId
                      : null,
                  decoration: const InputDecoration(
                    labelText: '所屬期數',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final issue in _issues)
                      DropdownMenuItem(
                        value: issue.id,
                        child: Text(issue.displayTitle),
                      ),
                  ],
                  onChanged: (id) {
                    if (id != null) _changed(() => _draft.issueId = id);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _slug,
                  decoration: const InputDecoration(
                    labelText: '網址代稱（slug）',
                    helperText: '小寫英文、數字和 -，例：spring-edit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => _changed(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('顯示對象'),
              const SizedBox(width: 12),
              SegmentedButton<MagazineAudience>(
                segments: const [
                  ButtonSegment(value: MagazineAudience.all, label: Text('全部')),
                  ButtonSegment(value: MagazineAudience.men, label: Text('男生')),
                  ButtonSegment(
                    value: MagazineAudience.women,
                    label: Text('女生'),
                  ),
                ],
                selected: {_draft.audience},
                onSelectionChanged: (s) =>
                    _changed(() => _draft.audience = s.single),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_draft.isStory) ...[
            BilingualField(
              label: '分類小標（kicker，例：STYLE GUIDE）',
              value: _draft.kicker,
              onChanged: _changed,
              maxLength: 30,
            ),
            const SizedBox(height: 16),
          ],
          BilingualField(
            label: '標題',
            value: _draft.title,
            onChanged: _changed,
            maxLength: 200,
          ),
          const SizedBox(height: 16),
          BilingualField(
            label: '副標',
            value: _draft.subtitle,
            onChanged: _changed,
            maxLength: 500,
          ),
          const SizedBox(height: 16),
          if (_draft.coverBrief case final brief?
              when _draft.coverObjectName == null) ...[
            ImageBrief(brief),
            const SizedBox(height: 8),
          ],
          ImageUploadField(
            label: _draft.isStory
                ? '封面（Story 第一頁，全螢幕 9:16，文字疊在下方）'
                : '封面（App 上是 4:5 直式）',
            url: _draft.imageUrls[_draft.coverObjectName],
            objectName: _draft.coverObjectName,
            onRightsChanged: () => _refreshRights(force: true),
            onUploaded: (img) => _changed(() {
              _draft.coverObjectName = img.objectName;
              _draft.imageUrls[img.objectName] = img.readUrl;
            }),
            onRemoved: () => _changed(() => _draft.coverObjectName = null),
          ),
          if (_draft.isStory && _draft.coverObjectName != null) ...[
            const SizedBox(height: 8),
            FocalPointField(
              x: _draft.coverFocalX,
              y: _draft.coverFocalY,
              zoom: _draft.coverZoom,
              whole: _draft.coverWhole,
              onChanged: (x, y, zoom, whole) => _changed(() {
                _draft.coverFocalX = x;
                _draft.coverFocalY = y;
                _draft.coverZoom = zoom;
                _draft.coverWhole = whole;
                _previewIndex = 0;
              }),
            ),
          ],
          const SizedBox(height: 24),
          _CardImageSection(
            draft: _draft,
            onChanged: _changed,
            onRightsChanged: () => _refreshRights(force: true),
          ),
          const SizedBox(height: 32),
          _CreditsSection(draft: _draft, onChanged: _changed),
          const SizedBox(height: 32),
          if (_draft.isStory)
            ..._buildPagesSection()
          else
            ..._buildBlocksSection(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  List<Widget> _buildBlocksSection() => [
    Text('內文區塊', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 4),
    Text(
      '拖拉左側把手調整順序。只填一種語言時，另一種語言的讀者會看到這個語言。',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    const SizedBox(height: 12),
    ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: _reorderBlocks,
      children: [
        for (final (i, block) in _draft.blocks.indexed)
          _buildBlockCard(i, block),
      ],
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _addBlock(HeadingDraft()),
          icon: const Icon(Icons.title),
          label: const Text('小標題'),
        ),
        OutlinedButton.icon(
          onPressed: () => _addBlock(ParagraphDraft()),
          icon: const Icon(Icons.notes),
          label: const Text('段落'),
        ),
        OutlinedButton.icon(
          onPressed: () => _addBlock(ImageDraft()),
          icon: const Icon(Icons.image_outlined),
          label: const Text('圖片'),
        ),
        OutlinedButton.icon(
          onPressed: _addItemBlock,
          icon: const Icon(Icons.checkroom_outlined),
          label: const Text('單品'),
        ),
        OutlinedButton.icon(
          onPressed: () => _addBlock(ItemGroupDraft()),
          icon: const Icon(Icons.grid_view),
          label: const Text('單品組'),
        ),
      ],
    ),
  ];

  List<Widget> _buildPagesSection() => [
    Text('頁面', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 4),
    Text(
      '封面是第 1 頁，下面的頁面從第 2 頁開始；最多 ${PageLimits.maxPages} 頁，'
      '發佈前至少要 ${PageLimits.minPublishedPages} 頁。拖拉左側把手調整順序；'
      '同一種版型可以重複使用。',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
    const SizedBox(height: 12),
    ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorderItem: _reorderPages,
      children: [
        for (final (i, page) in _draft.pages.indexed) _buildPageCard(i, page),
      ],
    ),
    const SizedBox(height: 12),
    Text('加入頁面', style: Theme.of(context).textTheme.titleSmall),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final layout in PageLayout.values)
          Tooltip(
            message: layout.hint,
            child: OutlinedButton(
              onPressed: _draft.pages.length >= PageLimits.maxPages
                  ? null
                  : () => _addPage(layout),
              child: Text(layout.label),
            ),
          ),
      ],
    ),
  ];

  Widget _buildPageCard(int index, PageDraft page) {
    return Card(
      key: ValueKey(page.key),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '第 ${index + 2} 頁 · ${page.layout.label}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          page.layout.hint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: '在預覽中顯示這一頁',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: () => _previewPage(page),
                      ),
                      IconButton(
                        tooltip: '移除這一頁',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            _changed(() => _draft.pages.removeAt(index)),
                      ),
                    ],
                  ),
                  StoryPageFields(
                    page: page,
                    draft: _draft,
                    onChanged: _changed,
                    onRightsChanged: () => _refreshRights(force: true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockCard(int index, BlockDraft block) {
    return Card(
      key: ValueKey(block.key),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.drag_indicator),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        block.typeLabel,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: '移除這個區塊',
                        icon: const Icon(Icons.close),
                        onPressed: () =>
                            _changed(() => _draft.blocks.removeAt(index)),
                      ),
                    ],
                  ),
                  _buildBlockFields(block),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockFields(BlockDraft block) => switch (block) {
    HeadingDraft(:final text) => BilingualField(
      label: '小標題',
      value: text,
      onChanged: _changed,
      maxLength: 200,
    ),
    ParagraphDraft(:final text) => BilingualField(
      label: '段落',
      value: text,
      onChanged: _changed,
      multiline: true,
      maxLength: 5000,
    ),
    ImageDraft() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ImageUploadField(
          label: '圖片',
          url: _draft.imageUrls[block.objectName],
          objectName: block.objectName,
          onRightsChanged: () => _refreshRights(force: true),
          onUploaded: (img) => _changed(() {
            block.objectName = img.objectName;
            _draft.imageUrls[img.objectName] = img.readUrl;
          }),
        ),
        const SizedBox(height: 12),
        BilingualField(
          label: '圖說（選填）',
          value: block.caption,
          onChanged: _changed,
          maxLength: 500,
        ),
      ],
    ),
    ItemDraft(:final itemId) => ItemRow(
      item: itemId == null ? null : _draft.items[itemId],
      missingId: itemId != null && !_draft.items.containsKey(itemId)
          ? itemId
          : null,
      trailing: OutlinedButton(
        onPressed: () => _pickItemFor(block),
        child: Text(itemId == null ? '選擇單品' : '更換'),
      ),
    ),
    ItemGroupDraft(:final title, :final itemIds) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BilingualField(
          label: '組標題（選填）',
          value: title,
          onChanged: _changed,
          maxLength: 200,
        ),
        const SizedBox(height: 8),
        for (final id in itemIds)
          ItemRow(
            item: _draft.items[id],
            missingId: _draft.items.containsKey(id) ? null : id,
            trailing: IconButton(
              tooltip: '從這一組移除',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _changed(() => itemIds.remove(id)),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: itemIds.length >= 20 ? null : () => _addToGroup(block),
            icon: const Icon(Icons.add),
            label: const Text('加入單品'),
          ),
        ),
      ],
    ),
  };
}

class _RightsBanner extends StatelessWidget {
  final int count;
  const _RightsBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.policy_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '有 $count 張讀者會看到的圖片還沒確認使用權，發佈前要完成。'
                '在每張圖片下方的「使用權」登記；單品的商品圖請到該單品的編輯頁登記。',
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Author, sources and the commercial relationship. Sponsored content must
/// name its sponsor; the App labels it.
class _CreditsSection extends StatefulWidget {
  final StoryDraft draft;
  final void Function([VoidCallback? change]) onChanged;

  const _CreditsSection({required this.draft, required this.onChanged});

  @override
  State<_CreditsSection> createState() => _CreditsSectionState();
}

class _CreditsSectionState extends State<_CreditsSection> {
  StoryDraft get _draft => widget.draft;

  InputDecoration _field(String label, {String? error}) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(),
    isDense: true,
    errorText: error,
  );

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    final sponsored = _draft.sponsorship != Sponsorship.none;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('出處與合作', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          '來源只是標示內容參考了哪裡，不代表取得圖片使用權（圖片另外登記）。',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: _draft.authorName,
          maxLength: 60,
          decoration: _field('作者／編輯（選填）'),
          onChanged: (v) => onChanged(() => _draft.authorName = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            const Text('商業合作'),
            SegmentedButton<Sponsorship>(
              segments: [
                for (final s in Sponsorship.values)
                  ButtonSegment(value: s, label: Text(s.label)),
              ],
              selected: {_draft.sponsorship},
              onSelectionChanged: (s) =>
                  onChanged(() => _draft.sponsorship = s.single),
            ),
          ],
        ),
        if (sponsored) ...[
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _draft.sponsorName,
            maxLength: 60,
            decoration: _field(
              '合作品牌（必填，App 會標示在封面與首頁卡片）',
              error: _draft.sponsorName.trim().isEmpty ? '有商業合作時必填' : null,
            ),
            onChanged: (v) => onChanged(() => _draft.sponsorName = v),
          ),
        ],
        const SizedBox(height: 12),
        Text('參考來源', style: Theme.of(context).textTheme.titleSmall),
        for (final (i, source) in _draft.sources.indexed)
          Padding(
            key: ValueKey(source.key),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<SourceKind>(
                    initialValue: source.kind,
                    decoration: _field('類型'),
                    items: [
                      for (final k in SourceKind.values)
                        DropdownMenuItem(value: k, child: Text(k.label)),
                    ],
                    onChanged: (k) =>
                        onChanged(() => source.kind = k ?? SourceKind.other),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: source.title,
                    maxLength: 120,
                    decoration: _field('標題（選填）'),
                    onChanged: (v) => onChanged(() => source.title = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: source.url,
                    maxLength: 500,
                    decoration: _field(
                      '網址',
                      error: source.url.isEmpty || source.isValid
                          ? null
                          : '要以 http:// 或 https:// 開頭',
                    ),
                    onChanged: (v) => onChanged(() => source.url = v),
                  ),
                ),
                IconButton(
                  tooltip: '移除來源',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onChanged(() => _draft.sources.removeAt(i)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _draft.sources.length >= 10
                ? null
                : () => onChanged(() => _draft.sources.add(SourceDraft())),
            icon: const Icon(Icons.add_link),
            label: const Text('加入來源（最多 10 筆）'),
          ),
        ),
      ],
    );
  }
}

/// Explore's landscape card: its own image (optional; the cover otherwise),
/// with a preview of the card's crop.
class _CardImageSection extends StatelessWidget {
  /// The card's shape on Explore's home.
  static const double _aspectRatio = 920 / 636;

  final StoryDraft draft;
  final void Function([VoidCallback? change]) onChanged;
  final VoidCallback onRightsChanged;

  const _CardImageSection({
    required this.draft,
    required this.onChanged,
    required this.onRightsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final card = draft.toPreview(ContentLocale.zhTw).summary;
    final shown = card.card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft.cardBrief case final brief?
            when draft.cardObjectName == null) ...[
          ImageBrief(brief),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            ImageUploadField(
              label: '首頁卡片圖（選填，橫式約 3:2；沒上傳就用封面）',
              url: draft.imageUrls[draft.cardObjectName],
              objectName: draft.cardObjectName,
              onRightsChanged: onRightsChanged,
              onUploaded: (img) => onChanged(() {
                draft.cardObjectName = img.objectName;
                draft.imageUrls[img.objectName] = img.readUrl;
              }),
              onRemoved: () => onChanged(() => draft.cardObjectName = null),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shown == null ? '首頁卡片預覽（目前用封面）' : '首頁卡片預覽',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: 280,
                  child: AspectRatio(
                    aspectRatio: _aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: shown != null
                          ? MagazineNetworkPhoto(photo: shown)
                          : MagazineNetworkPhoto(
                              photo: card.cover,
                              alignment: const Alignment(0.45, 0),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (draft.cardObjectName != null) ...[
          const SizedBox(height: 8),
          FocalPointField(
            x: draft.cardFocalX,
            y: draft.cardFocalY,
            zoom: draft.cardZoom,
            whole: draft.cardWhole,
            onChanged: (x, y, zoom, whole) => onChanged(() {
              draft.cardFocalX = x;
              draft.cardFocalY = y;
              draft.cardZoom = zoom;
              draft.cardWhole = whole;
            }),
          ),
        ],
      ],
    );
  }
}
