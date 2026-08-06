import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../services/storage/asset_cache_manager.dart';

class OptimizedImage extends StatelessWidget {
  const OptimizedImage({
    Key? key,
    required this.imageUrl,
    this.quality = ImageQuality.medium,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  }) : super(key: key);

  final String imageUrl;
  final ImageQuality quality;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildErrorWidget();
    }

    Widget imageWidget;
    if (imageUrl.startsWith('assets/')) {
      imageWidget = Image.asset(
        imageUrl,
        fit: fit,
        width: width,
        height: height,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? _buildErrorWidget(),
      );
    } else {
      final optimizedUrl = AssetCacheManager.getOptimizedUrl(imageUrl, quality);
      imageWidget = CachedNetworkImage(
        imageUrl: optimizedUrl,
        cacheManager: CreaniaAssetCacheManager.instance,
        fit: fit,
        width: width,
        height: height,
        filterQuality: FilterQuality.medium,
        memCacheWidth: quality == ImageQuality.thumbnail ? 150 : (quality == ImageQuality.medium ? 600 : null),
        placeholder: (context, url) => placeholder ?? _buildShimmerPlaceholder(),
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
