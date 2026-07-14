import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class GarmentImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  const GarmentImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = 0,
  });

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();

    Widget image;
    if (u.isEmpty) {
      image = Container(
        color: AppColors.dividerSubtle,
        child: const Icon(
          Icons.image_not_supported,
          color: AppColors.textSecondary,
        ),
      );
    } else if (u.startsWith('http')) {
      image = CachedNetworkImage(
        imageUrl: u,
        width: width,
        height: height,
        fit: fit,
        errorWidget: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image, color: AppColors.textSecondary),
        ),
      );
    } else if (u.startsWith('file://')) {
      image = Image.file(
        File.fromUri(Uri.parse(u)),
        width: width,
        height: height,
        fit: fit,
      );
    } else {
      image = Image.file(File(u), width: width, height: height, fit: fit);
    }

    if (borderRadius > 0) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: image,
      );
    }
    return image;
  }
}
