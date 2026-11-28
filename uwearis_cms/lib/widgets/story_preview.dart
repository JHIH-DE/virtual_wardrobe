import 'package:flutter/material.dart';
import 'package:uwearis/app/theme/app_colors.dart';
import 'package:uwearis/data/magazine.dart';
import 'package:uwearis/features/widgets/magazine/magazine_story_view.dart';

import '../models/story_draft.dart';

/// The story at phone width, rendered by the App's own [MagazineStoryView]
/// in the chosen language.
class StoryPreview extends StatelessWidget {
  static const double phoneWidth = 390;

  final MagazineStory story;
  final ContentLocale locale;
  final ValueChanged<ContentLocale> onLocaleChanged;

  const StoryPreview({
    super.key,
    required this.story,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final flutterLocale = locale == ContentLocale.zhTw
        ? const Locale('zh', 'TW')
        : const Locale('en');
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
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: phoneWidth,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.pageBackground,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.black26, width: 6),
            ),
            child: Localizations.override(
              context: context,
              locale: flutterLocale,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  // A no-op handler so the preview shows the shop action
                  // exactly where the App would.
                  child: MagazineStoryView(story: story, onShopItem: (_) {}),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
