import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import 'app_spinner.dart';

/// A [CachedNetworkImage] that self-heals once when [imageUrl] fails to load
/// (e.g. an expired signed URL) by asking [onRefreshUrl] for a fresh one and
/// retrying with it. Retries at most once per URL so a genuinely broken
/// image doesn't hammer the backend on every rebuild.
class RefreshableNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  /// Decode target size in physical pixels — keeps the in-memory bitmap
  /// close to what's actually shown instead of the source photo's full
  /// resolution, so Flutter's (size-capped) image cache can hold many more
  /// thumbnails before evicting anything. Leave null for full-resolution
  /// decoding (e.g. a hero/full-screen image).
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Leave null to use the default placeholder — a centered [AppSpinner]
  /// — Uwearis's one loading indicator for every image in the app. Only
  /// override this for a genuinely different treatment, not just a
  /// different spinner.
  final Widget Function(BuildContext context)? placeholderBuilder;

  /// How long the loaded image cross-fades in over its placeholder.
  /// [CachedNetworkImage]'s own default (500ms) unless overridden.
  final Duration fadeInDuration;
  final IconData errorIcon;
  final double errorIconSize;
  final String? errorLabel;

  /// Called at most once per [imageUrl] when the image fails to load.
  /// Return a fresh URL to retry with, or null/empty to give up. If null,
  /// the image just shows the error state with no retry attempt.
  final Future<String?> Function()? onRefreshUrl;

  /// Overrides what [CachedNetworkImage] keys its disk/memory cache entry
  /// by. Leave null to key by [imageUrl] itself (the default) — pass a
  /// stable id instead when the same underlying image is re-fetched under
  /// a *different* URL each time (e.g. a freshly re-signed cloud storage
  /// link), so re-signing doesn't show up as a cache miss and trigger a
  /// redundant download of bytes already on disk.
  final String? cacheKey;

  const RefreshableNetworkImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholderBuilder,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.errorIcon = Icons.broken_image_outlined,
    this.errorIconSize = 36,
    this.errorLabel,
    this.onRefreshUrl,
    this.cacheKey,
  });

  @override
  State<RefreshableNetworkImage> createState() =>
      _RefreshableNetworkImageState();
}

class _RefreshableNetworkImageState extends State<RefreshableNetworkImage> {
  late String _url;
  bool _refreshing = false;
  bool _refreshedThisUrl = false;

  @override
  void initState() {
    super.initState();
    _url = widget.imageUrl;
  }

  @override
  void didUpdateWidget(covariant RefreshableNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.imageUrl != oldWidget.imageUrl) {
      _url = widget.imageUrl;
      _refreshedThisUrl = false;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _refreshedThisUrl || widget.onRefreshUrl == null) {
      return;
    }
    _refreshing = true;
    _refreshedThisUrl = true;
    try {
      final fresh = await widget.onRefreshUrl!();
      if (mounted && fresh != null && fresh.isNotEmpty && fresh != _url) {
        setState(() => _url = fresh);
      }
    } catch (_) {
      // Leave the existing (broken) URL — the error state below covers it.
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: _url,
      cacheKey: widget.cacheKey,
      width: widget.width,
      height: widget.height,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      fit: widget.fit,
      alignment: widget.alignment,
      fadeInDuration: widget.fadeInDuration,
      placeholder: (_, _) => widget.placeholderBuilder != null
          ? widget.placeholderBuilder!(context)
          : const Center(child: AppSpinner(size: 28)),
      errorWidget: (_, _, _) {
        if (widget.onRefreshUrl != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.errorIcon,
                size: widget.errorIconSize,
                color: AppColors.icon,
              ),
              if (widget.errorLabel != null) ...[
                const SizedBox(height: 6),
                Text(
                  widget.errorLabel!,
                  style: AppTextStyle.regular12.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
