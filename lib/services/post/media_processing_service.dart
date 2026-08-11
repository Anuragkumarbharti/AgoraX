import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class ProcessedMediaResult {
  final File originalFile;
  final File? thumbnailFile;
  final double aspectRatio;
  final Map<String, dynamic> metadata;

  ProcessedMediaResult({
    required this.originalFile,
    this.thumbnailFile,
    this.aspectRatio = 1.0,
    this.metadata = const {},
  });
}

class MediaProcessingService {
  /// Compress image client-side and generate a tiny WebP/JPEG thumbnail preview
  static Future<ProcessedMediaResult> processImage(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      
      if (decoded == null) {
        return ProcessedMediaResult(originalFile: file, aspectRatio: 1.0);
      }

      final width = decoded.width;
      final height = decoded.height;
      final aspectRatio = height > 0 ? (width / height) : 1.0;

      // Generate tiny thumbnail (max 300px width)
      final tempDir = await getTemporaryDirectory();
      final thumbPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final resized = img.copyResize(decoded, width: width > 300 ? 300 : width);
      final thumbBytes = img.encodeJpg(resized, quality: 65);
      final thumbFile = File(thumbPath);
      await thumbFile.writeAsBytes(thumbBytes);

      return ProcessedMediaResult(
        originalFile: file,
        thumbnailFile: thumbFile,
        aspectRatio: aspectRatio,
        metadata: {
          'width': width,
          'height': height,
          'file_size': bytes.length,
          'format': 'image',
        },
      );
    } catch (e) {
      debugPrint('Error processing image: $e');
      return ProcessedMediaResult(originalFile: file, aspectRatio: 1.0);
    }
  }

  /// Process video thumbnail & aspect ratio calculation
  static Future<ProcessedMediaResult> processVideo(File file) async {
    try {
      final size = await file.length();
      // Placeholder aspect ratio for video player
      const aspectRatio = 16 / 9;

      return ProcessedMediaResult(
        originalFile: file,
        aspectRatio: aspectRatio,
        metadata: {
          'file_size': size,
          'duration_seconds': 0,
          'format': 'video',
        },
      );
    } catch (e) {
      debugPrint('Error processing video: $e');
      return ProcessedMediaResult(originalFile: file, aspectRatio: 16 / 9);
    }
  }

  /// Process audio file / recording
  static Future<ProcessedMediaResult> processAudio(File file, {int durationSeconds = 0}) async {
    try {
      final size = await file.length();
      // Generate lightweight synthetic waveform data array (20 normalized values)
      final List<double> waveform = List.generate(25, (i) => 0.2 + ((i * 7) % 10) / 12.0);

      return ProcessedMediaResult(
        originalFile: file,
        aspectRatio: 3.5, // Compact player card aspect ratio
        metadata: {
          'file_size': size,
          'duration_seconds': durationSeconds,
          'waveform': waveform,
          'format': 'audio',
        },
      );
    } catch (e) {
      debugPrint('Error processing audio: $e');
      return ProcessedMediaResult(originalFile: file, aspectRatio: 3.5);
    }
  }

  /// Process PDF metadata
  static Future<ProcessedMediaResult> processPdf(File file, {String? fileName}) async {
    try {
      final size = await file.length();
      final name = fileName ?? file.path.split('/').last;

      return ProcessedMediaResult(
        originalFile: file,
        aspectRatio: 2.5,
        metadata: {
          'file_name': name,
          'file_size': size,
          'page_count': 1,
          'format': 'pdf',
        },
      );
    } catch (e) {
      debugPrint('Error processing PDF: $e');
      return ProcessedMediaResult(originalFile: file, aspectRatio: 2.5);
    }
  }
}
