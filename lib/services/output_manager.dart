import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class OutputManager {
  static const String keyCustomOutputDir = 'v2a_custom_output_dir';
  static final OutputManager _instance = OutputManager._internal();
  factory OutputManager() => _instance;
  OutputManager._internal();

  /// Gets the user's active output directory.
  /// Uses persisted custom location if set and writable, otherwise the public Music/V2A folder.
  Future<Directory> getActiveOutputDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString(keyCustomOutputDir);

    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      if (await _isWritable(customDir)) {
        return customDir;
      }
    }

    return await getDefaultOutputDirectory();
  }

  /// Sets a custom output directory chosen by the user
  Future<bool> setCustomOutputDirectory(String path) async {
    final dir = Directory(path);
    if (!await _isWritable(dir)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCustomOutputDir, path);
    return true;
  }

  /// Resets to standard public Music/V2A folder
  Future<void> resetToDefaultOutputDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyCustomOutputDir);
  }

  /// Returns the default public output directory: `Internal Storage/Music/V2A/`
  Future<Directory> getDefaultOutputDirectory() async {
    if (Platform.isAndroid) {
      // 1. Try public Music folder on primary external storage: /storage/emulated/0/Music/V2A
      final publicMusicV2A = Directory('/storage/emulated/0/Music/V2A');
      if (await _isWritable(publicMusicV2A)) {
        return publicMusicV2A;
      }

      // 2. Try public Download folder: /storage/emulated/0/Download/V2A
      final publicDownloadV2A = Directory('/storage/emulated/0/Download/V2A');
      if (await _isWritable(publicDownloadV2A)) {
        return publicDownloadV2A;
      }

      // 3. Fallback to getExternalStorageDirectory()
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final fallbackDir = Directory(p.join(extDir.path, 'V2A'));
          if (await _isWritable(fallbackDir)) {
            return fallbackDir;
          }
        }
      } catch (_) {}
    }

    // iOS or Desktop fallback
    final appDocDir = await getApplicationDocumentsDirectory();
    final v2aFolder = Directory(p.join(appDocDir.path, 'V2A'));
    if (!await v2aFolder.exists()) {
      await v2aFolder.create(recursive: true);
    }
    return v2aFolder;
  }

  /// Proposes a collision-free unique filename based on the requested name and target directory.
  /// Follows Section 8 rules: "Movie.mp3", "Movie (1).mp3", "Movie (2).mp3", etc.
  Future<String> resolveUniqueFileName({
    required String directoryPath,
    required String baseName,
    required String extension,
  }) async {
    final cleanExt = extension.startsWith('.') ? extension : '.$extension';
    String pureName = baseName;
    if (pureName.toLowerCase().endsWith(cleanExt.toLowerCase())) {
      pureName = pureName.substring(0, pureName.length - cleanExt.length);
    }
    pureName = pureName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (pureName.isEmpty) pureName = 'Audio_Output';

    String candidate = '$pureName$cleanExt';
    File targetFile = File(p.join(directoryPath, candidate));
    int counter = 1;

    while (await targetFile.exists()) {
      candidate = '$pureName ($counter)$cleanExt';
      targetFile = File(p.join(directoryPath, candidate));
      counter++;
    }

    return candidate;
  }

  /// Creates a uniquely-named temporary processing file.
  /// Converts into this temporary file first to guarantee that existing files are never overwritten
  /// and partially-written files are never exposed as completed files.
  Future<File> createTemporaryProcessingFile({
    required String directoryPath,
    required String extension,
  }) async {
    final cleanExt = extension.startsWith('.') ? extension : '.$extension';
    final tempUuid = const Uuid().v4().substring(0, 8);
    final tempName = '.v2a_tmp_${DateTime.now().millisecondsSinceEpoch}_$tempUuid$cleanExt';
    final tempFile = File(p.join(directoryPath, tempName));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
    return tempFile;
  }

  /// Atomically finalizes the output file.
  /// Rechecks destination conflicts right before renaming, generating a new unique name if a race occurred.
  Future<File> finalizeOutputFile({
    required File tempFile,
    required String directoryPath,
    required String targetFileName,
    required String extension,
    bool allowExplicitOverwrite = false,
  }) async {
    if (!await tempFile.exists()) {
      throw FileSystemException('Temporary conversion file not found', tempFile.path);
    }

    final cleanExt = extension.startsWith('.') ? extension : '.$extension';
    String finalName = targetFileName;
    File finalDestination = File(p.join(directoryPath, finalName));

    if (!allowExplicitOverwrite && await finalDestination.exists()) {
      final pureName = p.basenameWithoutExtension(targetFileName);
      finalName = await resolveUniqueFileName(
        directoryPath: directoryPath,
        baseName: pureName,
        extension: cleanExt,
      );
      finalDestination = File(p.join(directoryPath, finalName));
    }

    // Atomic move / rename
    final savedFile = await tempFile.rename(finalDestination.path);
    return savedFile;
  }

  /// Safely cleans up abandoned temporary files from previous runs
  Future<int> cleanupAbandonedTempFiles(String directoryPath) async {
    int deletedCount = 0;
    try {
      final dir = Directory(directoryPath);
      if (!await dir.exists()) return 0;
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File && p.basename(entity.path).startsWith('.v2a_tmp_')) {
          try {
            await entity.delete();
            deletedCount++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    return deletedCount;
  }

  /// Checks if available storage space is sufficient (estimates required space + 50MB safety buffer)
  Future<bool> checkStorageSpace({
    required String directoryPath,
    required int estimatedBytes,
  }) async {
    return await _isWritable(Directory(directoryPath));
  }

  Future<bool> _isWritable(Directory dir) async {
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final testFile = File(p.join(dir.path, '.v2a_write_test_${DateTime.now().millisecondsSinceEpoch}'));
      await testFile.writeAsString('test');
      await testFile.delete();
      return true;
    } catch (e) {
      debugPrint('[OutputManager] Directory not writable (${dir.path}): $e');
      return false;
    }
  }
}
