import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Categories for organizing media files into separate dedicated directories
/// within the application's persistent storage.
enum MediaCategory {
  visits('visits'),
  damages('damages'),
  expenses('expenses'),
  attendance('attendance'),
  outlets('outlets'),
  documents('documents');

  final String dirName;
  const MediaCategory(this.dirName);
}

/// Service governing offline-safe media persistence and compression for the GDFL mobile app.
///
/// Android Best Practice & OOM Protection:
/// 1. Standard [ImagePicker] returns images stored in the volatile cache directory
///    (`/data/user/0/<package>/cache/`), which the Android OS can wipe at any time.
/// 2. Modern 48MP/108MP phone cameras take 5 MB - 10 MB photos that cause immediate
///    heap exhaustion (OOM kill -> app crash back to home screen) when read into memory
///    and base64 encoded.
///
/// This service natively downscales (max 1024x1024 or 1280x1280 for documents) and
/// compresses images to quality 70, stripping heavy EXIF metadata off the UI thread.
/// The resulting persistent files in (`app_flutter/gdfl_media/<category>/`) are only
/// 150 KB - 250 KB (a 97% reduction), eliminating memory crashes and allowing instant sync.
class MediaStorageService {
  MediaStorageService._();

  static const String _rootFolder = 'gdfl_media';

  static bool _isImageExtension(String ext) {
    final lower = ext.toLowerCase();
    return lower == '.jpg' ||
        lower == '.jpeg' ||
        lower == '.png' ||
        lower == '.webp' ||
        lower == '.heic' ||
        lower == '.bmp';
  }

  /// Natively compresses and downscales an image file off the UI thread into [targetPath].
  /// Automatically strips heavy EXIF metadata and corrects orientation.
  static Future<File> _compressAndSaveImage({
    required File sourceFile,
    required String targetPath,
    required MediaCategory category,
  }) async {
    final ext = p.extension(sourceFile.path);
    if (!_isImageExtension(ext)) {
      return await sourceFile.copy(targetPath);
    }

    try {
      final sourceLength = await sourceFile.length();

      // Documents/challans get 1280 max dimension for sharp text; others get 1024
      final isDocument = category == MediaCategory.damages ||
          category == MediaCategory.expenses ||
          category == MediaCategory.documents;
      final maxDim = isDocument ? 1280 : 1024;
      final quality = isDocument ? 72 : 70;

      // Always save compressed images as .jpg
      final safeTargetPath = p.setExtension(targetPath, '.jpg');

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        sourceFile.absolute.path,
        safeTargetPath,
        minWidth: maxDim,
        minHeight: maxDim,
        quality: quality,
        keepExif: false,
        autoCorrectionAngle: true,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile != null) {
        final compressedFile = File(compressedXFile.path);
        final compressedLength = await compressedFile.length();
        if (compressedLength > 0) {
          final reduction = sourceLength > 0
              ? ((1 - (compressedLength / sourceLength)) * 100).toStringAsFixed(1)
              : '0';
          debugPrint(
            '[MediaStorageService] Image compressed ($category): '
            '${(sourceLength / 1024).toStringAsFixed(1)} KB -> '
            '${(compressedLength / 1024).toStringAsFixed(1)} KB ($reduction% reduction)',
          );
          return compressedFile;
        }
      }
    } catch (e) {
      debugPrint('[MediaStorageService] Warning: Native compression fallback ($e). Performing direct copy.');
    }

    // Safe fallback if compression fails or in headless test environments
    return await sourceFile.copy(targetPath);
  }

  /// Resolves the dedicated persistent directory for a given [category].
  /// Creates the directory structure if it does not already exist.
  static Future<Directory> getCategoryDirectory(MediaCategory category) async {
    final baseDir = await getApplicationDocumentsDirectory();
    final targetPath = p.join(baseDir.path, _rootFolder, category.dirName);
    final dir = Directory(targetPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Compresses and moves an image captured by [ImagePicker] from the volatile cache to a
  /// persistent directory categorized by [category].
  ///
  /// Returns the persistent, compressed [File], or `null` if [pickedFile] is null.
  static Future<File?> persistPickedFile(
    XFile? pickedFile, {
    required MediaCategory category,
    String? customPrefix,
  }) async {
    if (pickedFile == null) return null;

    try {
      final categoryDir = await getCategoryDirectory(category);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final prefix = customPrefix ?? category.dirName;
      final fileName = '${prefix}_$timestamp.jpg';
      final targetPath = p.join(categoryDir.path, fileName);

      // Verify source file exists and is not corrupt/empty
      final tempFile = File(pickedFile.path);
      if (!await tempFile.exists() || await tempFile.length() < 256) {
        debugPrint('[MediaStorageService] Warning: Source file does not exist or is empty (< 256 bytes).');
        return null;
      }

      // Natively compress and downscale directly into target persistent path
      final persistentFile = await _compressAndSaveImage(
        sourceFile: tempFile,
        targetPath: targetPath,
        category: category,
      );

      // Best effort to remove temporary cache file to free up cache space
      try {
        if (await tempFile.exists() && tempFile.path != persistentFile.path) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('[MediaStorageService] Non-critical: could not delete temp file: $e');
      }

      debugPrint('[MediaStorageService] Persisted and compressed image to: ${persistentFile.path}');
      return persistentFile;
    } catch (e) {
      debugPrint('[MediaStorageService] Error persisting picked image: $e');
      // Fallback: return file at original path if copy fails
      return File(pickedFile.path);
    }
  }

  /// Compresses and copies a generic [File] (e.g. from FilePicker) to a persistent categorized directory.
  static Future<File?> persistFile(
    File? sourceFile, {
    required MediaCategory category,
    String? customPrefix,
  }) async {
    if (sourceFile == null || !await sourceFile.exists()) return null;

    try {
      final categoryDir = await getCategoryDirectory(category);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(sourceFile.path).isNotEmpty
          ? p.extension(sourceFile.path)
          : '.dat';
      final prefix = customPrefix ?? category.dirName;
      final fileName = '${prefix}_$timestamp$ext';
      final targetPath = p.join(categoryDir.path, fileName);

      final persistentFile = await _compressAndSaveImage(
        sourceFile: sourceFile,
        targetPath: targetPath,
        category: category,
      );
      debugPrint('[MediaStorageService] Persisted file to: ${persistentFile.path}');
      return persistentFile;
    } catch (e) {
      debugPrint('[MediaStorageService] Error persisting file: $e');
      return sourceFile;
    }
  }

  /// Writes in-memory [bytes] directly to a persistent categorized directory with native compression.
  static Future<File?> persistBytes(
    Uint8List? bytes, {
    required MediaCategory category,
    required String originalFileName,
    String? customPrefix,
  }) async {
    if (bytes == null || bytes.isEmpty) return null;
    try {
      final categoryDir = await getCategoryDirectory(category);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(originalFileName);
      final prefix = customPrefix ?? category.dirName;
      final fileName = '${prefix}_$timestamp${ext.isNotEmpty ? ext : ".jpg"}';
      final targetPath = p.join(categoryDir.path, fileName);

      // If image and > 100 KB, compress natively with list
      if (_isImageExtension(ext) && bytes.length > 100 * 1024) {
        try {
          final isDocument = category == MediaCategory.damages ||
              category == MediaCategory.expenses ||
              category == MediaCategory.documents;
          final maxDim = isDocument ? 1280 : 1024;
          final quality = isDocument ? 72 : 70;

          final compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            minWidth: maxDim,
            minHeight: maxDim,
            quality: quality,
            keepExif: false,
            autoCorrectionAngle: true,
            format: CompressFormat.jpeg,
          );

          if (compressedBytes.isNotEmpty) {
            final safeTargetPath = p.setExtension(targetPath, '.jpg');
            final file = File(safeTargetPath);
            await file.writeAsBytes(compressedBytes);
            debugPrint(
              '[MediaStorageService] Bytes compressed: '
              '${(bytes.length / 1024).toStringAsFixed(1)} KB -> '
              '${(compressedBytes.length / 1024).toStringAsFixed(1)} KB',
            );
            return file;
          }
        } catch (e) {
          debugPrint('[MediaStorageService] Native compressWithList fallback: $e');
        }
      }

      final file = File(targetPath);
      await file.writeAsBytes(bytes);
      debugPrint('[MediaStorageService] Persisted bytes to: $targetPath');
      return file;
    } catch (e) {
      debugPrint('[MediaStorageService] Error persisting bytes: $e');
      return null;
    }
  }

  /// Safely deletes a persisted media file (e.g. after successful Odoo sync).
  static Future<bool> deleteMediaFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return false;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[MediaStorageService] Deleted media file: $filePath');
        return true;
      }
    } catch (e) {
      debugPrint('[MediaStorageService] Error deleting file $filePath: $e');
    }
    return false;
  }

  /// Prunes old media files older than [maxAge] to avoid bloating device storage.
  /// Typically invoked during weekly maintenance or shift end.
  static Future<int> pruneOldMedia({
    Duration maxAge = const Duration(days: 14),
  }) async {
    int deletedCount = 0;
    try {
      final baseDir = await getApplicationDocumentsDirectory();
      final rootDir = Directory(p.join(baseDir.path, _rootFolder));
      if (!await rootDir.exists()) return 0;

      final now = DateTime.now();
      final files = rootDir.listSync(recursive: true, followLinks: false);

      for (final entity in files) {
        if (entity is File) {
          final stat = await entity.stat();
          if (now.difference(stat.modified) > maxAge) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      debugPrint('[MediaStorageService] Pruned $deletedCount old media files.');
    } catch (e) {
      debugPrint('[MediaStorageService] Error during media pruning: $e');
    }
    return deletedCount;
  }
}
