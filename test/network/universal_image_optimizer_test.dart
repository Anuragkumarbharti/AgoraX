import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:creania/services/storage/universal_image_optimizer.dart';
import 'package:creania/services/storage/asset_cache_manager.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UniversalImageOptimizer Tests', () {
    test('Image category max dimensions', () {
      expect(UniversalImageOptimizer.getMaxDimension(ImageCategoryType.avatar), 512);
      expect(UniversalImageOptimizer.getMaxDimension(ImageCategoryType.giftImage), 512);
      expect(UniversalImageOptimizer.getMaxDimension(ImageCategoryType.chatImage), 1280);
      expect(UniversalImageOptimizer.getMaxDimension(ImageCategoryType.storyPost), 1440);
      expect(UniversalImageOptimizer.getMaxDimension(ImageCategoryType.profileCover), 1080);
      expect(UniversalImageOptimizer.getMaxDimension(ImageCategoryType.roomBackground), 1440);
      expect(UniversalImageOptimizer.getMaxDimension(ImageCategoryType.gallery), 2048);
    });

    test('Bucket name mapping', () {
      expect(UniversalImageOptimizer.getBucketName(ImageCategoryType.avatar), 'avatars');
      expect(UniversalImageOptimizer.getBucketName(ImageCategoryType.profileCover), 'banners');
      expect(UniversalImageOptimizer.getBucketName(ImageCategoryType.chatImage), 'chat-media');
      expect(UniversalImageOptimizer.getBucketName(ImageCategoryType.storyPost), 'posts');
    });

    test('SHA-256 hash generation for deduplication', () {
      final bytes1 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final bytes2 = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
      final bytes3 = Uint8List.fromList([8, 7, 6, 5, 4, 3, 2, 1]);

      final hash1 = UniversalImageOptimizer.calculateSha256(bytes1);
      final hash2 = UniversalImageOptimizer.calculateSha256(bytes2);
      final hash3 = UniversalImageOptimizer.calculateSha256(bytes3);

      expect(hash1, equals(hash2));
      expect(hash1, isNot(equals(hash3)));
      expect(hash1.length, equals(64));
    });

    test('Image byte header validation', () {
      final testImg = img.Image(width: 10, height: 10);
      final pngBytes = Uint8List.fromList(img.encodePng(testImg));
      expect(UniversalImageOptimizer.isValidImageBytes(pngBytes), isTrue);

      final invalidBytes = Uint8List.fromList(List.filled(40, 0));
      expect(UniversalImageOptimizer.isValidImageBytes(invalidBytes), isFalse);
    });

    test('AssetCacheManager returns clean valid public URL', () {
      const rawUrl = 'https://abc.supabase.co/storage/v1/object/public/avatars/user1/avatar.png?v=123456';
      final optimizedThumb = AssetCacheManager.getOptimizedUrl(rawUrl, ImageQuality.thumbnail);
      final optimizedMedium = AssetCacheManager.getOptimizedUrl(rawUrl, ImageQuality.medium);

      expect(optimizedThumb, equals(rawUrl));
      expect(optimizedMedium, equals(rawUrl));
    });
  });
}
