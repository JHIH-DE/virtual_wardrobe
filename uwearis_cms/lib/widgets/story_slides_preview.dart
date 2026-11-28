import 'package:flutter/material.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis/features/widgets/magazine/magazine_slide_view.dart';

import '../models/story_draft.dart';

/// A `story` one page at a time, at phone size, rendered by the App's own
/// slide widgets in the chosen language. Index 0 is the cover.
class StorySlidesPreview extends StatelessWidget {
  static const Size phone = Size(390, 844);

  /// The reader's chrome (status bar + progress bar and ✕) and the home
  /// indicator, which slides keep their copy clear of.
  static const EdgeInsets _chrome = EdgeInsets.only(top: 47 + 64, bottom: 34);

  final MagazineStory story;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final ContentLocale locale;
  final ValueChanged<ContentLocale> onLocaleChanged;

  const StorySlidesPreview({
    super.key,
    required this.story,
    required this.index,
    required this.onIndexChanged,
    required this.locale,
    required this.onLocaleChanged,
  });

  int get _count => story.pages.length + 1;

  @override
  Widget build(BuildContext context) {
    final current = index.clamp(0, _count - 1);
    final flutterLocale = locale == ContentLocale.zhTw
        ? const Locale('zh', 'TW')
        : const Locale('en');
    final slide = current == 0
        ? MagazineCoverSlideView(
            summary: story.summary,
            padding: _chrome,
            pageNumber: 1,
          )
        : MagazineSlideView(
            slide: story.pages[current - 1],
            padding: _chrome,
            pageNumber: current + 1,
            storyCover: story.summary.cover,
            // No-op handlers so the preview shows the actions where the App
            // would.
            onShopItem: (_) {},
          );
    return Column(
      children: [
        SegmentedButton<ContentLocale>(
          segments: const [
            ButtonSegment(value: ContentLocale.zhTw, label: Text('中文預覽')),
            ButtonSegment(value: ContentLocale.en, label: Text('English')),
          ],
          selected: {locale},
          onSelectionChanged: (s) => onLocaleChanged(s.single),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: '上一頁',
              onPressed: current > 0 ? () => onIndexChanged(current - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(current == 0 ? '封面（1 / $_count）' : '${current + 1} / $_count'),
            IconButton(
              tooltip: '下一頁',
              onPressed: current < _count - 1
                  ? () => onIndexChanged(current + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FittedBox(
            child: Container(
              width: phone.width,
              height: phone.height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.pageBackground,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.black26, width: 6),
              ),
              child: Localizations.override(
                context: context,
                locale: flutterLocale,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: phone,
                    padding: EdgeInsets.zero,
                    textScaler: TextScaler.noScaling,
                  ),
                  child: Material(
                    color: AppColors.pageBackground,
                    child: KeyedSubtree(key: ValueKey(current), child: slide),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
