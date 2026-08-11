import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/storage/asset_cache_manager.dart';
export '../../services/storage/asset_cache_manager.dart' show ImageQuality, MediaSizePreset;

class OptimizedImage extends StatelessWidget {
  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.preset,
    this.quality = ImageQuality.medium,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.useShimmer = true,
  }) : super(key: key);

  final String imageUrl;
  final MediaSizePreset? preset;
  final ImageQuality quality;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool useShimmer;

  /// Helper method for widgets requiring an ImageProvider (DecorationImage, CircleAvatar, etc.)
  static ImageProvider getOptimizedImageProvider(
    String url, {
    MediaSizePreset? preset,
    ImageQuality quality = ImageQuality.medium,
    double? width,
    double? height,
    double devicePixelRatio = 1.0,
  }) {
    if (url.trim().isEmpty) {
      return const AssetImage('assets/images/default_avatar.png');
    }
    String cleanUrl = url.trim();
    if (cleanUrl.startsWith('file:///assets/')) {
      cleanUrl = cleanUrl.replaceFirst('file:///', '');
    } else if (cleanUrl.startsWith('file://assets/')) {
      cleanUrl = cleanUrl.replaceFirst('file://', '');
    }
    if (cleanUrl.startsWith('assets/')) {
      return AssetImage(cleanUrl);
    }
    if (cleanUrl.contains('assets/')) {
      cleanUrl = cleanUrl.substring(cleanUrl.indexOf('assets/'));
      return AssetImage(cleanUrl);
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      return const AssetImage('assets/images/default_avatar.png');
    }
    final optimizedUrl = AssetCacheManager.getOptimizedUrl(
      cleanUrl,
      quality,
      preset: preset,
      customWidth: (width != null && width.isFinite) ? width.round() : null,
      customHeight: (height != null && height.isFinite) ? height.round() : null,
      devicePixelRatio: devicePixelRatio,
    );
    return CachedNetworkImageProvider(
      optimizedUrl,
      cacheManager: CreaniaAssetCacheManager.instance,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.trim().isEmpty) {
      return _buildErrorWidget();
    }

    String cleanUrl = imageUrl.trim();
    if (cleanUrl.startsWith('file:///assets/')) {
      cleanUrl = cleanUrl.replaceFirst('file:///', '');
    } else if (cleanUrl.startsWith('file://assets/')) {
      cleanUrl = cleanUrl.replaceFirst('file://', '');
    }

    Widget imageWidget;
    if (cleanUrl.startsWith('assets/') || cleanUrl.contains('assets/')) {
      final assetPath = cleanUrl.contains('assets/')
          ? cleanUrl.substring(cleanUrl.indexOf('assets/'))
          : cleanUrl;
      imageWidget = Image.asset(
        assetPath,
        fit: fit,
        width: width,
        height: height,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? _buildErrorWidget(),
      );
    } else if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      imageWidget = errorWidget ?? _buildErrorWidget();
    } else {
      final dpr = MediaQuery.of(context).devicePixelRatio;
      final optimizedUrl = AssetCacheManager.getOptimizedUrl(
        imageUrl,
        quality,
        preset: preset,
        customWidth: (width != null && width!.isFinite) ? (width! * dpr * 1.25).round() : null,
        customHeight: (height != null && height!.isFinite) ? (height! * dpr * 1.25).round() : null,
        devicePixelRatio: dpr,
      );

      int? calculatedMemWidth;
      int? calculatedMemHeight;
      if (width != null && width!.isFinite && width! > 0 && width! < 2000) {
        calculatedMemWidth = (width! * dpr * 1.25).round();
      } else if (preset != null) {
        calculatedMemWidth = AssetCacheManager.getDimensionForPreset(preset!, devicePixelRatio: dpr);
      } else if (quality == ImageQuality.thumbnail) {
        calculatedMemWidth = 150;
      } else if (quality == ImageQuality.medium) {
        calculatedMemWidth = 600;
      }

      if (height != null && height!.isFinite && height! > 0 && height! < 2000) {
        calculatedMemHeight = (height! * dpr * 1.25).round();
      }

      imageWidget = CachedNetworkImage(
        imageUrl: optimizedUrl,
        cacheManager: CreaniaAssetCacheManager.instance,
        fit: fit,
        width: width,
        height: height,
        filterQuality: FilterQuality.medium,
        memCacheWidth: calculatedMemWidth,
        memCacheHeight: calculatedMemHeight,
        placeholder: (context, url) => placeholder ?? (useShimmer ? _buildShimmerPlaceholder() : const SizedBox()),
        errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
      );
    }

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildShimmerPlaceholder() {
    return SizedBox(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFF1D1F29),
        highlightColor: const Color(0xFF2C2F3E),
        child: Container(
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF16171F),
      child: const Icon(
        Icons.image_not_supported_rounded,
        color: Colors.white24,
        size: 20,
      ),
    );
  }
}
