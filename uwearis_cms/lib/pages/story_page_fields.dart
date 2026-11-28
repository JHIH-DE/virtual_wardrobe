import 'package:flutter/material.dart';
import 'package:uwearis/data/magazine.dart';

import '../models/story_draft.dart';
import '../models/story_pages.dart';
import '../widgets/bilingual_field.dart';
import '../widgets/focal_point_field.dart';
import '../widgets/image_upload_field.dart';
import '../widgets/item_row.dart';
import '../widgets/pickers.dart';

/// The fields of one story page, by layout. Edits [page] in place and calls
/// [onChanged]; items picked here are added to [draft]'s item cache so the
/// preview can show them.
class StoryPageFields extends StatelessWidget {
  final PageDraft page;
  final StoryDraft draft;
  final void Function([VoidCallback? change]) onChanged;
  final VoidCallback onRightsChanged;

  const StoryPageFields({
    super.key,
    required this.page,
    required this.draft,
    required this.onChanged,
    required this.onRightsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final page = this.page;
    final typography = page is TypographyPageDraft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BilingualField(
          label: '小標（選填，例：THE DETAILS）',
          value: page.label,
          onChanged: onChanged,
          maxLength: PageLimits.label,
        ),
        const SizedBox(height: 12),
        BilingualField(
          label: typography ? '主要文字' : '標題（選填）',
          value: page.heading,
          onChanged: onChanged,
          maxLength: typography ? PageLimits.quote : PageLimits.heading,
          multiline: typography,
        ),
        const SizedBox(height: 12),
        BilingualField(
          label: '內文（選填）',
          value: page.body,
          onChanged: onChanged,
          maxLength: PageLimits.body,
          multiline: true,
        ),
        const SizedBox(height: 16),
        ..._layoutFields(context, page),
      ],
    );
  }

  List<Widget> _layoutFields(BuildContext context, PageDraft page) =>
      switch (page) {
        ImmersivePageDraft() => [
          _PageImageEditor(
            label: '全螢幕照片（建議 9:16 直式）',
            image: page.image,
            draft: draft,
            onChanged: onChanged,
            onRightsChanged: onRightsChanged,
          ),
          _TextPosition(
            value: page.textPosition,
            onChanged: (p) => onChanged(() => page.textPosition = p),
          ),
        ],
        FeaturePageDraft() => [
          _PageImageEditor(
            label: '主圖',
            image: page.image,
            draft: draft,
            onChanged: onChanged,
            onRightsChanged: onRightsChanged,
          ),
          const SizedBox(height: 12),
          _Choice<MagazineImageRatio>(
            label: '圖片比例',
            value: page.imageRatio,
            options: const {
              MagazineImageRatio.portrait: '直式 2:3',
              MagazineImageRatio.square: '方形 1:1',
              MagazineImageRatio.landscape: '橫式 3:2',
            },
            onChanged: (r) => onChanged(() => page.imageRatio = r),
          ),
          _TextPosition(
            value: page.textPosition,
            onChanged: (p) => onChanged(() => page.textPosition = p),
          ),
          const SizedBox(height: 12),
          BilingualField(
            label: '標題下一行（選填，例：品牌的 TOKYO / EST. 2016）',
            value: page.info,
            onChanged: onChanged,
            maxLength: PageLimits.info,
          ),
          const SizedBox(height: 12),
          BilingualField(
            label: '圖說（選填）',
            value: page.caption,
            onChanged: onChanged,
            maxLength: PageLimits.imageCaption,
          ),
        ],
        DetailPageDraft() => [
          if (page.main case final main?) ...[
            _PageImageEditor(
              label: '主圖（建議 4:3）',
              image: main,
              draft: draft,
              onChanged: onChanged,
              onRightsChanged: onRightsChanged,
              onRemove: () => onChanged(() => page.main = null),
            ),
          ] else
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onChanged(() => page.main = PageImageDraft()),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('加入主圖（選填）'),
              ),
            ),
          const SizedBox(height: 12),
          ..._imageList(
            label: '細節圖',
            images: page.details,
            min: 0,
            max: PageLimits.maxDetails,
            withText: true,
          ),
          const SizedBox(height: 12),
          _SwatchList(swatches: page.swatches, onChanged: onChanged),
        ],
        GalleryPageDraft() => [
          _Choice<bool>(
            label: '圖片形狀',
            value: page.square,
            options: const {false: '人物 2:3', true: '商品／細節 1:1'},
            onChanged: (v) => onChanged(() => page.square = v),
          ),
          _Toggle(
            label: '標題前自動加編號（1. 2. 3.）',
            value: page.numbered,
            onChanged: (v) => onChanged(() => page.numbered = v),
          ),
          ..._imageList(
            label: '圖片',
            images: page.images,
            min: PageLimits.minGallery,
            max: PageLimits.maxGallery,
            withText: true,
          ),
        ],
        ListPageDraft() => [
          _Toggle(
            label: '每項加上編號（01、02、03）',
            value: page.numbered,
            onChanged: (v) => onChanged(() => page.numbered = v),
          ),
          ..._imageList(
            label: '項目',
            images: page.entries,
            min: PageLimits.minList,
            max: PageLimits.maxList,
            withText: true,
          ),
        ],
        BreakdownPageDraft() => [
          _PageImageEditor(
            label: '整套穿搭照片（建議 2:3 直式，人物完整）',
            image: page.image,
            draft: draft,
            onChanged: onChanged,
            onRightsChanged: onRightsChanged,
          ),
          const SizedBox(height: 12),
          Text(
            '單品（1–${PageLimits.maxPieces} 件；3 件以內排在照片右側，4 件以上排在下方）',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          for (final (i, piece) in page.pieces.indexed)
            Padding(
              key: ObjectKey(piece),
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ItemRow(
                    item: piece.itemId == null
                        ? null
                        : draft.items[piece.itemId],
                    missingId:
                        piece.itemId != null &&
                            !draft.items.containsKey(piece.itemId)
                        ? piece.itemId
                        : null,
                    trailing: Wrap(
                      children: [
                        TextButton(
                          onPressed: () => _pickItem(context, (id) {
                            piece.itemId = id;
                          }),
                          child: Text(piece.itemId == null ? '選擇單品' : '更換'),
                        ),
                        IconButton(
                          tooltip: '移除這件',
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () =>
                              onChanged(() => page.pieces.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                  BilingualField(
                    label: '類別（選填，例：Outer、Shoes）',
                    value: piece.label,
                    onChanged: onChanged,
                    maxLength: PageLimits.pieceLabel,
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: page.pieces.length >= PageLimits.maxPieces
                  ? null
                  : () => _pickItem(context, (id) {
                      page.pieces.add(PieceDraft(itemId: id));
                    }),
              icon: const Icon(Icons.add),
              label: const Text('加入單品'),
            ),
          ),
        ],
        TypographyPageDraft() => [
          _Choice<bool>(
            label: '底色',
            value: page.dark,
            options: const {false: '淺色', true: '深色'},
            onChanged: (v) => onChanged(() => page.dark = v),
          ),
          const SizedBox(height: 12),
          BilingualField(
            label: '說話的人（選填，App 顯示為「— 名字」）',
            value: page.attribution,
            onChanged: onChanged,
            maxLength: PageLimits.attribution,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 240,
            child: TextFormField(
              initialValue: page.number,
              maxLength: PageLimits.number,
              decoration: const InputDecoration(
                labelText: '章節數字（選填，例：03）',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => onChanged(() => page.number = v),
            ),
          ),
        ],
        SelectionPageDraft() => [
          _Toggle(
            label: '下方加上「用你的衣櫃穿出來」',
            value: page.wardrobePrompt,
            onChanged: (v) => onChanged(() => page.wardrobePrompt = v),
          ),
          for (final id in page.itemIds)
            ItemRow(
              item: draft.items[id],
              missingId: draft.items.containsKey(id) ? null : id,
              trailing: IconButton(
                tooltip: '移除',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => onChanged(() => page.itemIds.remove(id)),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: page.itemIds.length >= PageLimits.maxItems
                  ? null
                  : () => _pickItem(context, (id) {
                      if (!page.itemIds.contains(id)) page.itemIds.add(id);
                    }),
              icon: const Icon(Icons.add),
              label: Text('加入商品（最多 ${PageLimits.maxItems} 件）'),
            ),
          ),
        ],
      };

  Future<void> _pickItem(
    BuildContext context,
    void Function(int id) use,
  ) async {
    final item = await pickItem(context);
    if (item == null || !context.mounted) return;
    onChanged(() {
      draft.items[item.id] = item;
      use(item.id);
    });
  }

  List<Widget> _imageList({
    required String label,
    required List<PageImageDraft> images,
    required int min,
    required int max,
    required bool withText,
  }) => [
    for (final (i, image) in images.indexed) ...[
      _PageImageEditor(
        key: ObjectKey(image),
        label: '$label ${i + 1}',
        image: image,
        draft: draft,
        onChanged: onChanged,
        onRightsChanged: onRightsChanged,
        withText: withText,
        onRemove: images.length > min
            ? () => onChanged(() => images.removeAt(i))
            : null,
      ),
      const SizedBox(height: 12),
    ],
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: images.length >= max
            ? null
            : () => onChanged(() => images.add(PageImageDraft())),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: Text('加入$label（${min == 0 ? '最多 ' : '$min–'}$max 張）'),
      ),
    ),
  ];
}

/// One page photo: upload, its rights, where to crop, optional title and
/// caption.
class _PageImageEditor extends StatelessWidget {
  final String label;
  final PageImageDraft image;
  final StoryDraft draft;
  final void Function([VoidCallback? change]) onChanged;
  final VoidCallback onRightsChanged;
  final bool withText;
  final VoidCallback? onRemove;

  const _PageImageEditor({
    super.key,
    required this.label,
    required this.image,
    required this.draft,
    required this.onChanged,
    required this.onRightsChanged,
    this.withText = false,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (image.brief case final brief?
                when image.objectName == null) ...[
              ImageBrief(brief),
              const SizedBox(height: 8),
            ],
            ImageUploadField(
              label: label,
              url: draft.imageUrls[image.objectName],
              objectName: image.objectName,
              onRightsChanged: onRightsChanged,
              onUploaded: (img) => onChanged(() {
                image.objectName = img.objectName;
                draft.imageUrls[img.objectName] = img.readUrl;
              }),
              onRemoved: onRemove,
            ),
            if (image.objectName != null) ...[
              const SizedBox(height: 8),
              FocalPointField(
                x: image.focalX,
                y: image.focalY,
                zoom: image.zoom,
                whole: image.whole,
                onChanged: (x, y, zoom, whole) => onChanged(() {
                  image.focalX = x;
                  image.focalY = y;
                  image.zoom = zoom;
                  image.whole = whole;
                }),
              ),
            ],
            if (withText) ...[
              const SizedBox(height: 8),
              BilingualField(
                label: '標題（選填）',
                value: image.title,
                onChanged: onChanged,
                maxLength: PageLimits.imageTitle,
              ),
              const SizedBox(height: 8),
              BilingualField(
                label: '說明（選填）',
                value: image.caption,
                onChanged: onChanged,
                maxLength: PageLimits.imageCaption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwatchList extends StatelessWidget {
  final List<SwatchDraft> swatches;
  final void Function([VoidCallback? change]) onChanged;

  const _SwatchList({required this.swatches, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '色票（選填，最多 ${PageLimits.maxSwatches} 個）',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        for (final (i, swatch) in swatches.indexed)
          Padding(
            key: ObjectKey(swatch),
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: swatch.isValid
                        ? Color(
                            0xFF000000 |
                                int.parse(swatch.hex.substring(1), radix: 16),
                          )
                        : Colors.transparent,
                    border: Border.all(color: Colors.black26),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    initialValue: swatch.hex,
                    maxLength: 7,
                    decoration: InputDecoration(
                      labelText: '色碼',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                      errorText: swatch.isValid ? null : '#RRGGBB',
                    ),
                    onChanged: (v) => onChanged(() => swatch.hex = v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BilingualField(
                    label: '色名',
                    value: swatch.name,
                    onChanged: onChanged,
                    maxLength: PageLimits.imageTitle,
                  ),
                ),
                IconButton(
                  tooltip: '移除色票',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => onChanged(() => swatches.removeAt(i)),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: swatches.length >= PageLimits.maxSwatches
                ? null
                : () => onChanged(() => swatches.add(SwatchDraft())),
            icon: const Icon(Icons.palette_outlined),
            label: const Text('加入色票'),
          ),
        ),
      ],
    );
  }
}

class _TextPosition extends StatelessWidget {
  final MagazineSlideTextPosition value;
  final ValueChanged<MagazineSlideTextPosition> onChanged;

  const _TextPosition({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => _Choice<MagazineSlideTextPosition>(
    label: '文字位置',
    value: value,
    options: const {
      MagazineSlideTextPosition.top: '上方',
      MagazineSlideTextPosition.bottom: '下方',
    },
    onChanged: onChanged,
  );
}

class _Choice<T> extends StatelessWidget {
  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(label),
          SegmentedButton<T>(
            segments: [
              for (final MapEntry(:key, :value) in options.entries)
                ButtonSegment(value: key, label: Text(value)),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.single),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    value: value,
    onChanged: onChanged,
  );
}
