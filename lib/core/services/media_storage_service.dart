import 'dart:io';
import 'package:flutter/foundation.dart';
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
  outlets('outlets');

  final String dirName;
  const MediaCategory(this.dirName);
}

/// Service governing offline-safe media persistence for the GDFL mobile app.
///
/// Android Best Practice:
/// Standard [ImagePicker] returns images stored in the volatile cache directory
/// (`/data/user/0/<package>/cache/`), which the Android OS can wipe at any time
/// during low-memory conditions or background GC.
///
/// This service copies captured images immediately into the persistent application
/// document directory (`app_flutter/gdfl_media/<category>/`), guaranteeing that photos
/// remain accessible across hours or days of offline buffering until synced with Odoo.
class MediaStorageService {
  MediaStorageService._();

  static const String _rootFolder = 'gdfl_media';

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

  /// Copies an image captured by [ImagePicker] from the volatile cache to a
  /// persistent directory categorized by [category].
  ///
  /// Returns the persistent [File], or `null` if [pickedFile] is null.
  static Future<File?> persistPickedFile(
    XFile? pickedFile, {
    required MediaCategory category,
    String? customPrefix,
  }) async {
    if (pickedFile == null) return null;

    try {
      final categoryDir = await getCategoryDirectory(category);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(pickedFile.path).isNotEmpty
          ? p.extension(pickedFile.path)
          : '.jpg';
      final prefix = customPrefix ?? category.dirName;
      final fileName = '${prefix}_$timestamp$ext';
      final targetPath = p.join(categoryDir.path, fileName);

      // Copy from temporary cache to persistent storage
      final tempFile = File(pickedFile.path);
      if (!await tempFile.exists() || await tempFile.length() < 256) {
        debugPrint('[MediaStorageService] Warning: Source file does not exist or is empty (< 256 bytes).');
        return null;
      }
      final persistentFile = await tempFile.copy(targetPath);

      // Best effort to remove temporary cache file to free up cache space
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('[MediaStorageService] Non-critical: could not delete temp file: $e');
      }

      debugPrint('[MediaStorageService] Persisted image to: $targetPath');
      return persistentFile;
    } catch (e) {
      debugPrint('[MediaStorageService] Error persisting picked image: $e');
      // Fallback: return file at original path if copy fails
      return File(pickedFile.path);
    }
  }

  /// Copies a generic [File] (e.g. from FilePicker) to a persistent categorized directory.
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

      final persistentFile = await sourceFile.copy(targetPath);
      debugPrint('[MediaStorageService] Persisted file to: $targetPath');
      return persistentFile;
    } catch (e) {
      debugPrint('[MediaStorageService] Error persisting file: $e');
      return sourceFile;
    }
  }

  /// Writes in-memory [bytes] directly to a persistent categorized directory.
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
      final ext = p.extension(originalFileName).isNotEmpty
          ? p.extension(originalFileName)
          : '.dat';
      final prefix = customPrefix ?? category.dirName;
      final fileName = '${prefix}_$timestamp$ext';
      final targetPath = p.join(categoryDir.path, fileName);

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
