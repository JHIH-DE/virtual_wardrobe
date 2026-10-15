import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/services/auth_handler.dart';
import '../../../../core/services/auth_storage.dart';
import '../../../../core/utils/debug_log.dart';
import 'app_spinner.dart';

/// A [CachedNetworkImage] that, on a load failure (e.g. an expired signed
/// URL), asks [onRefreshUrl] for a fresh URL — at most once per URL.
class RefreshableNetworkImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;

  /// Decode size in physical pixels, so the size-capped image cache holds
  /// more thumbnails. Null decodes at full resolution.
  final int? memCacheWidth;
  final int? memCacheHeight;

  /// Defaults to a centered [AppSpinner], the app's one image loading
  /// indicator — don't override just for a different spinner.
  final Widget Function(BuildContext context)? placeholderBuilder;

  final Duration fadeInDuration;
  final IconData errorIcon;
  final double errorIconSize;
  final String? errorLabel;

  /// Returns a fresh URL to retry with, or null/empty to give up.
  final Future<String?> Function()? onRefreshUrl;

  /// Lets a caller holding its own copy of the URL stay in sync. `oldUrl`
  /// allows a compare-and-set, so a late refresh can't clobber a newer URL
  /// (see `ProfileNotifier.setBodyRefUrlIfCurrent`).
  final void Function(String oldUrl, String newUrl)? onUrlRefreshed;

  /// Called at most once per [imageUrl], only after the refresh attempt (if
  /// any) has failed too — for a caller's own failure UI.
  final VoidCallback? onLoadError;

  /// A stable cache key, so a re-signed URL for the same image isn't a
  /// cache miss. Null keys by the URL.
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
    this.onUrlRefreshed,
    this.onLoadError,
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
  bool _errorReportedThisUrl = false;

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
      _errorReportedThisUrl = false;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || _refreshedThisUrl || widget.onRefreshUrl == null) {
      return;
    }
    _refreshing = true;
    _refreshedThisUrl = true;
    var replaced = false;
    try {
      final fresh = await widget.onRefreshUrl!();
      if (mounted && fresh != null && fresh.isNotEmpty && fresh != _url) {
        final oldUrl = _url;
        setState(() => _url = fresh);
        widget.onUrlRefreshed?.call(oldUrl, fresh);
        replaced = true;
      }
    } on AuthExpiredException {
      // No stored token = the session was already ended (logout, or another
      // handler cleared it); a briefly-mounted old screen mustn't raise
      // "Session Expired".
      if (await AuthStorage.getRefreshToken() == null) return;
      if (mounted) await AuthExpiredHandler.handle(context);
      return;
    } catch (e) {
      debugLog('RefreshableNetworkImage: onRefreshUrl failed: $e');
    } finally {
      _refreshing = false;
    }
    // No new URL means no rebuild, so errorWidget won't get to report it.
    if (!replaced && mounted) _reportLoadError();
  }

  void _reportLoadError() {
    if (_errorReportedThisUrl) return;
    _errorReportedThisUrl = true;
    widget.onLoadError?.call();
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      // Without the URL in the key, a refreshed image with the same
      // cacheKey can replay the cached error instead of fetching.
      key: ValueKey('${widget.cacheKey}::$_url'),
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
        if (widget.onRefreshUrl != null && !_refreshedThisUrl) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
        } else {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _reportLoadError(),
          );
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
