import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_dimens.dart';
import '../../../app/theme/app_durations.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/magazine_provider.dart';
import '../../../core/services/auth_handler.dart';
import '../../../core/utils/external_links.dart';
import '../../../data/magazine.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../app/theme/editorial_typography.dart';
import '../../widgets/common/images/app_spinner.dart';
import '../../widgets/common/overlays/empty_state_placeholder.dart';
import '../../widgets/common/overlays/error_state_widget.dart';
import '../../widgets/magazine/magazine_credits.dart';
import '../../widgets/magazine/magazine_slide_view.dart';

/// A `story`-format magazine story, full screen: its cover, then its slides,
/// paged sideways. Pushed as a full-screen dialog ([route]), so iOS has no
/// edge swipe-back competing with paging; it closes with its ✕ or back.
class EditorialStoryPage extends ConsumerWidget {
  final int storyId;

  /// The story's card from Explore; its cover shows while the story loads.
  final MagazineStorySummary? summary;

  const EditorialStoryPage({super.key, required this.storyId, this.summary});

  static Route<void> route({
    required int storyId,
    MagazineStorySummary? summary,
  }) => MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => EditorialStoryPage(storyId: storyId, summary: summary),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = magazineStoryProvider((
      apiLocale: LocaleNotifier.apiLocaleFor(Localizations.localeOf(context)),
      storyId: storyId,
    ));
    ref.listen(provider, (_, next) {
      if (isSettledAuthExpiry(next)) AuthExpiredHandler.handle(context);
    });
    return ref
        .watch(provider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => _ReaderFrame(
            onPhoto: true,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (summary case final summary?)
                  MagazineCoverSlideView(
                    summary: summary,
                    padding: _ReaderChrome.slidePadding(context),
                  ),
                const Center(child: AppSpinner()),
              ],
            ),
          ),
          error: (error, _) => _ReaderFrame(
            onPhoto: false,
            child: ErrorStateWidget(
              error: error,
              onRetry: () => ref.invalidate(provider),
            ),
          ),
          data: (story) => EditorialStoryReader(
            story: story,
            onShopItem: (item) => _openProduct(context, item),
            onOpenSource: (url) => openMagazineSource(context, url),
          ),
        );
  }

  void _openProduct(BuildContext context, MagazineItem item) {
    final url = item.product?.productUrl;
    if (url != null) openProductPage(context, url);
  }
}

/// A loaded story's slides with the progress bar and ✕ over them. Paging is
/// manual: swipe, or tap the left / right third of a slide (not on a slide
/// of shoppable cards, whose cards and prompt take the taps).
class EditorialStoryReader extends StatefulWidget {
  final MagazineStory story;

  /// Shown on items with an available product; null hides the action.
  final void Function(MagazineItem item)? onShopItem;

  /// Match Your Wardrobe with the look it's offered on; null hides the
  /// button until it's wired to a real flow.
  final void Function(MagazinePhoto look)? onMatchWardrobe;

  /// Opens a source from the credits sheet; null lists them without links.
  final void Function(String url)? onOpenSource;

  const EditorialStoryReader({
    super.key,
    required this.story,
    this.onShopItem,
    this.onMatchWardrobe,
    this.onOpenSource,
  });

  @override
  State<EditorialStoryReader> createState() => _EditorialStoryReaderState();
}

class _EditorialStoryReaderState extends State<EditorialStoryReader> {
  final PageController _controller = PageController();
  int _index = 0;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  /// The cover plus every slide.
  int get _count => widget.story.pages.length + 1;

  MagazineSlide? _slideAt(int index) =>
      index == 0 ? null : widget.story.pages[index - 1];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _preload(1);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.story.pages.isEmpty) {
      return _ReaderFrame(
        onPhoto: false,
        child: EmptyStatePlaceholder(
          message: _l10n.editorialStoryUnavailable,
          fillAvailableSpace: true,
        ),
      );
    }
    final slidePadding = _ReaderChrome.slidePadding(context);
    return _ReaderFrame(
      onPhoto: _isDarkSlide(_slideAt(_index)),
      controller: _controller,
      count: _count,
      child: PageView.builder(
        controller: _controller,
        itemCount: _count,
        onPageChanged: _handlePageChanged,
        itemBuilder: (context, index) {
          final slide = _slideAt(index);
          return Semantics(
            container: true,
            label: _l10n.editorialPageLabel(index + 1, _count),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: _hasCards(slide) ? null : _handleTap,
              child: RepaintBoundary(
                child: slide == null
                    ? MagazineCoverSlideView(
                        summary: widget.story.summary,
                        padding: slidePadding,
                        pageNumber: 1,
                      )
                    : MagazineSlideView(
                        slide: slide,
                        padding: slidePadding,
                        pageNumber: index + 1,
                        storyCover: widget.story.summary.cover,
                        onShopItem: widget.onShopItem,
                        onMatchWardrobe: widget.onMatchWardrobe,
                        footer: index == _count - 1 && widget.story.hasCredits
                            ? MagazineCreditsSection(
                                story: widget.story,
                                onOpenSource: widget.onOpenSource,
                              )
                            : null,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handlePageChanged(int index) {
    setState(() => _index = index);
    _preload(index + 1);
  }

  void _handleTap(TapUpDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final x = details.localPosition.dx;
    if (x < width / 3) {
      _goTo(_index - 1);
    } else if (x > width * 2 / 3) {
      _goTo(_index + 1);
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= _count) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: AppDurations.standard,
        curve: Curves.easeOut,
      );
    }
  }

  /// Warms the image cache for the slide after the visible one, so paging
  /// forward doesn't wait on the network. Only one ahead: the one behind is
  /// usually still cached, and further ahead would load photos that may never
  /// be seen.
  void _preload(int index) {
    if (index >= _count) return;
    final photos = switch (_slideAt(index)) {
      null => [widget.story.summary.cover],
      MagazineImmersiveSlide(:final photo) => [photo],
      MagazineFeatureSlide(:final photo) => [photo],
      MagazineDetailSlide(:final main, :final details) => [
        main?.photo,
        for (final detail in details) detail.photo,
      ],
      MagazineGallerySlide(:final images) => [
        for (final image in images) image.photo,
      ],
      MagazineListSlide(:final entries) => [
        for (final entry in entries) entry.photo,
      ],
      MagazineBreakdownSlide(:final look, :final pieces) => [
        look,
        for (final piece in pieces) piece.item.photo,
      ],
      MagazineTypographySlide() => const <MagazinePhoto?>[],
      MagazineSelectionSlide(:final items, :final wardrobePrompt) => [
        for (final item in items) item.photo,
        if (wardrobePrompt) widget.story.summary.cover,
      ],
    };
    for (final photo in photos.nonNulls) {
      final ImageProvider provider = photo.isAsset
          ? AssetImage(photo.url)
          : CachedNetworkImageProvider(photo.url, cacheKey: photo.cacheKey);
      // A failed preload is harmless: the slide shows its own error state.
      precacheImage(provider, context, onError: (_, _) {});
    }
  }

  static bool _hasCards(MagazineSlide? slide) =>
      slide is MagazineSelectionSlide;

  /// Full-screen photo slides and dark text pages get light chrome (over a
  /// scrim on a photo); the rest, on the page colour, get dark chrome.
  static bool _isDarkSlide(MagazineSlide? slide) => switch (slide) {
    null || MagazineImmersiveSlide() => true,
    MagazineTypographySlide(:final tone) => tone == MagazineSlideTone.dark,
    _ => false,
  };
}

/// The reader's screen: [child] edge to edge, under the status bar and the
/// system navigation bar (both kept transparent), with the progress bar
/// (when given) and the ✕ on top. A story's credits close its last page.
/// Over a photo ([onPhoto]) the controls and system icons are white, over a
/// short scrim at the top.
class _ReaderFrame extends StatelessWidget {
  static const SystemUiOverlayStyle _lightIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );
  static const SystemUiOverlayStyle _darkIcons = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  final bool onPhoto;

  /// The reader's pager and slide count; null on the loading / error /
  /// unavailable screens, which show only the ✕.
  final PageController? controller;
  final int count;
  final Widget child;

  const _ReaderFrame({
    required this.onPhoto,
    this.controller,
    this.count = 0,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: onPhoto ? _lightIcons : _darkIcons,
      child: Scaffold(
        backgroundColor: onPhoto
            ? AppColors.trueBlack
            : AppColors.pageBackground,
        body: Stack(
          fit: StackFit.expand,
          children: [
            child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(child: _ChromeScrim(visible: onPhoto)),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _ReaderChrome(
                onPhoto: onPhoto,
                progress: switch (controller) {
                  final controller? => _ReaderProgress(
                    controller: controller,
                    count: count,
                    onPhoto: onPhoto,
                  ),
                  null => null,
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReaderChrome extends StatelessWidget {
  static const double _inset = 12;

  /// The chrome's height below the status bar.
  static const double _height = 8 + AppDimens.minTouchTarget + 8;

  final bool onPhoto;
  final Widget? progress;

  const _ReaderChrome({required this.onPhoto, this.progress});

  /// What a slide keeps its copy clear of: the chrome on top, the system
  /// insets around.
  static EdgeInsets slidePadding(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return insets.copyWith(top: insets.top + _height);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(_inset, top + 8, _inset / 2, 8),
      child: Row(
        children: [
          Expanded(child: progress ?? const SizedBox.shrink()),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close),
            color: onPhoto ? AppColors.textOnPrimary : AppColors.textPrimary,
            tooltip: AppLocalizations.of(context).close,
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}

/// Behind the chrome on a photo: a dark wash from the top of the screen
/// that fades out a little below the controls, so the rest of the photo
/// keeps its brightness. Fades in and out with the page rather than
/// switching.
class _ChromeScrim extends StatelessWidget {
  /// How far past the chrome the wash fades out.
  static const double _fade = 40;

  final bool visible;

  const _ChromeScrim({required this.visible});

  @override
  Widget build(BuildContext context) {
    final height =
        MediaQuery.paddingOf(context).top + _ReaderChrome._height + _fade;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: AppDurations.standard,
      child: SizedBox(
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.scrimMedium,
                AppColors.scrimMedium.withValues(alpha: 0.2),
                AppColors.scrimMedium.withValues(alpha: 0),
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
      ),
    );
  }
}

/// One segment per slide, filling as the reader pages through them; past
/// [_maxSegments] slides, one continuous bar with "3 / 14" beside it.
/// Listens to the controller itself, so a drag repaints only the bar.
class _ReaderProgress extends StatelessWidget {
  static const double _barHeight = 3;
  static const double _gap = 4;
  static const int _maxSegments = 10;

  final PageController controller;
  final int count;
  final bool onPhoto;

  const _ReaderProgress({
    required this.controller,
    required this.count,
    required this.onPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final track = onPhoto ? AppColors.onPhotoMuted : AppColors.borderSubtle;
    final fill = onPhoto ? AppColors.textOnPrimary : AppColors.textPrimary;
    Widget bar(double filled) => ClipRRect(
      borderRadius: BorderRadius.circular(AppDimens.pillRadius),
      child: SizedBox(
        height: _barHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: track),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: filled.clamp(0.0, 1.0),
              child: ColoredBox(color: fill),
            ),
          ],
        ),
      ),
    );
    return ExcludeSemantics(
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final page =
              controller.hasClients && controller.position.haveDimensions
              ? controller.page ?? 0
              : 0.0;
          if (count > _maxSegments) {
            return Row(
              children: [
                Expanded(child: bar((page + 1) / count)),
                const SizedBox(width: 8),
                Text(
                  '${page.round() + 1} / $count',
                  style: EditorialTypography.progressCounter.style.copyWith(
                    color: fill,
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(child: bar(page - i + 1)),
              ],
            ],
          );
        },
      ),
    );
  }
}
