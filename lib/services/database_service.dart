import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/conversion_job.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database?> get database async {
    if (_db != null) return _db;
    try {
      if (!Platform.isAndroid && !Platform.isIOS) {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      _db = await _initDatabase();
      return _db;
    } catch (e) {
      // In headless unit test environment or uninitialized platform factory
      return null;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'v2a_converter.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Jobs table
        await db.execute('''
          CREATE TABLE jobs (
            id TEXT PRIMARY KEY,
            sourcePath TEXT,
            sourceFileName TEXT,
            sourceSizeBytes INTEGER,
            sourceDurationMs INTEGER,
            selectedAudioTrackIndex INTEGER,
            selectedAudioCodec TEXT,
            format TEXT,
            mode TEXT,
            preset TEXT,
            bitrateKbps INTEGER,
            sampleRateHz INTEGER,
            channelMode TEXT,
            vbrEnabled INTEGER,
            vbrQuality INTEGER,
            volumeGainDb REAL,
            normalizeLoudness INTEGER,
            trimStartMs INTEGER,
            trimEndMs INTEGER,
            fadeInSec REAL,
            fadeOutSec REAL,
            trimSilence INTEGER,
            metaTitle TEXT,
            metaArtist TEXT,
            metaAlbum TEXT,
            metaYear TEXT,
            metaGenre TEXT,
            metaArtwork TEXT,
            requestedFileName TEXT,
            outputDirectory TEXT,
            finalOutputPath TEXT,
            status TEXT,
            progress REAL,
            speedRatio REAL,
            currentTimeMs INTEGER,
            elapsedSeconds INTEGER,
            estimatedRemainingSeconds INTEGER,
            outputSizeBytes INTEGER,
            errorMessage TEXT,
            createdAt TEXT,
            completedAt TEXT
          )
        ''');

        // Playlists table
        await db.execute('''
          CREATE TABLE playlist_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            playlistName TEXT,
            filePath TEXT,
            title TEXT,
            artist TEXT,
            durationMs INTEGER,
            addedAt TEXT
          )
        ''');
      },
    );
  }

  /// Inserts a new conversion job
  Future<void> insertJob(ConversionJob job) async {
    final db = await database;
    if (db == null) return;
    await db.insert('jobs', job.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Updates an existing conversion job
  Future<void> updateJob(ConversionJob job) async {
    final db = await database;
    if (db == null) return;
    await db.update('jobs', job.toMap(), where: 'id = ?', whereArgs: [job.id]);
  }

  /// Deletes a job by id
  Future<void> deleteJob(String id) async {
    final db = await database;
    if (db == null) return;
    await db.delete('jobs', where: 'id = ?', whereArgs: [id]);
  }

  /// Retrieves all jobs ordered by creation date
  Future<List<ConversionJob>> getAllJobs() async {
    final db = await database;
    if (db == null) return [];
    final results = await db.query('jobs', orderBy: 'createdAt DESC');
    return results.map((m) => ConversionJob.fromMap(m)).toList();
  }

  /// Retrieves completed conversion history
  Future<List<ConversionJob>> getHistory() async {
    final db = await database;
    if (db == null) return [];
    final results = await db.query(
      'jobs',
      where: 'status = ?',
      whereArgs: [JobStatus.completed.name],
      orderBy: 'completedAt DESC',
    );
    return results.map((m) => ConversionJob.fromMap(m)).toList();
  }

  /// Deletes completed history records without deleting physical files
  Future<void> clearCompletedHistory() async {
    final db = await database;
    if (db == null) return;
    await db.delete('jobs', where: 'status = ?', whereArgs: [JobStatus.completed.name]);
  }

  /// Recovers interrupted jobs upon app startup (Section 10 requirement)
  Future<void> recoverInterruptedJobs() async {
    final db = await database;
    if (db == null) return;
    await db.update(
      'jobs',
      {
        'status': JobStatus.interrupted.name,
        'errorMessage': 'Conversion was interrupted by system or app restart',
      },
      where: 'status IN (?, ?, ?)',
      whereArgs: [JobStatus.running.name, JobStatus.preparing.name, JobStatus.finalizing.name],
    );
  }
}

