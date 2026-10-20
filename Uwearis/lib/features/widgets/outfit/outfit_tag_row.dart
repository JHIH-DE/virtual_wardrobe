import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../common/buttons/circle_icon_button.dart';
import '../common/cards/category_tag.dart';
import 'outfit_title.dart';

/// An outfit's season tags then its style tags on a single line, collapsing
/// whatever doesn't fit into a trailing "+N" — shared by Outfit Details and
/// Today's Outfit. The caller decides what an untagged outfit shows.
class OutfitTagRow extends StatelessWidget {
  final List<String> seasons;
  final List<String> style;

  const OutfitTagRow({super.key, required this.seasons, required this.style});

  @override
  Widget build(BuildContext context) {
    return _CollapsingTagsRow(
      tags: [...seasons, ...style].map(outfitTagLabel).toList(),
    );
  }
}

/// The tag line under an outfit's name on Outfit Details and Today's
/// Outfit: the edit-tags button beside [OutfitTagRow], or "My Collection"
/// for an untagged outfit. A null [onEdit] disables the button (e.g. while
/// a save is in flight).
class OutfitTagsHeader extends StatelessWidget {
  final List<String> seasons;
  final List<String> style;
  final VoidCallback? onEdit;

  const OutfitTagsHeader({
    super.key,
    required this.seasons,
    required this.style,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.sell_outlined, onPressed: onEdit),
          const SizedBox(width: 2),
          Expanded(
            child: seasons.isEmpty && style.isEmpty
                ? Text(
                    AppLocalizations.of(context).myCollection,
                    style: AppTextStyle.regular14.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  )
                : OutfitTagRow(seasons: seasons, style: style),
          ),
        ],
      ),
    );
  }
}

/// Lays [tags] out on a single line, collapsing whatever doesn't fit into a
/// trailing "+N" tag instead of wrapping to a second line.
class _CollapsingTagsRow extends StatelessWidget {
  final List<String> tags;

  const _CollapsingTagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    const tagSpacing = 8.0;
    // CategoryTag's horizontal padding (10 * 2) + its 1px border on each side.
    const tagHPadding = 22.0;
    // Measured width can trail the rendered one by a sub-pixel; reserve a
    // little so a near-miss collapses into "+N" instead of overflowing.
    const tagSlack = 3.0;
    // What CategoryTag's Text actually resolves to.
    final tagTextStyle = DefaultTextStyle.of(
      context,
    ).style.merge(AppTextStyle.bold12);
    final textScaler = MediaQuery.textScalerOf(context);

    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: tagTextStyle),
        maxLines: 1,
        textDirection: ui.TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      return painter.width;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final tagWidths = tags
            .map((t) => textWidth(t) + tagHPadding + tagSlack)
            .toList();

        var visibleCount = tags.length;
        var usedWidth = 0.0;
        for (var i = 0; i < tags.length; i++) {
          final width = tagWidths[i] + (i > 0 ? tagSpacing : 0);
          if (usedWidth + width > maxWidth) {
            visibleCount = i;
            break;
          }
          usedWidth += width;
        }

        // A non-scrolling viewport clips any remaining estimate error
        // instead of throwing a RenderFlex overflow.
        Widget oneLine(List<Widget> children) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Row(mainAxisSize: MainAxisSize.min, children: children),
        );

        if (visibleCount == tags.length) {
          return oneLine([
            for (var i = 0; i < tags.length; i++) ...[
              if (i > 0) const SizedBox(width: tagSpacing),
              CategoryTag(label: tags[i], borderColor: AppColors.surface),
            ],
          ]);
        }

        // Shrink further if needed so the trailing "+N" tag also fits.
        var count = visibleCount;
        while (count > 0) {
          final overflowLabel = '+${tags.length - count}';
          var used =
              tagSpacing + textWidth(overflowLabel) + tagHPadding + tagSlack;
          for (var i = 0; i < count; i++) {
            used += tagWidths[i] + (i > 0 ? tagSpacing : 0);
          }
          if (used <= maxWidth) break;
          count--;
        }
        count = count.clamp(1, tags.length);

        return oneLine([
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: tagSpacing),
            CategoryTag(label: tags[i], borderColor: AppColors.surface),
          ],
          const SizedBox(width: tagSpacing),
          CategoryTag(
            label: '+${tags.length - count}',
            borderColor: AppColors.surface,
          ),
        ]);
      },
    );
  }
}
