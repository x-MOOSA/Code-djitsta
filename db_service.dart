import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DbService {
  static final DbService instance = DbService._();
  DbService._();

  Database? _db;

  Future<Database> get db async {
    final existing = _db;
    if (existing != null) return existing;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'ai_gallery.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Main table (stores keywords)
        await db.execute('''
          CREATE TABLE asset_tags(
            asset_id TEXT PRIMARY KEY,
            keywords TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          );
        ''');

        // FTS table (fast search)
        // Note: "keywords" is what we search.
        await db.execute('''
          CREATE VIRTUAL TABLE asset_tags_fts
          USING fts5(asset_id, keywords);
        ''');
      },
    );
  }

  /// Insert/update keywords for an asset (also updates FTS)
  Future<void> upsertTag({
    required String assetId,
    required String keywords,
  }) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Keep database small: avoid saving huge text
    final trimmed = _limitSize(keywords, maxChars: 5000);

    await database.transaction((txn) async {
      await txn.insert(
        'asset_tags',
        {
          'asset_id': assetId,
          'keywords': trimmed,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Update FTS:
      // Simplest stable approach: delete then insert for asset
      await txn.delete('asset_tags_fts', where: 'asset_id = ?', whereArgs: [assetId]);
      await txn.insert('asset_tags_fts', {
        'asset_id': assetId,
        'keywords': trimmed,
      });
    });
  }

  /// Load tags for many IDs at once (fast startup)
  Future<Map<String, String>> loadTagsForIds(List<String> assetIds) async {
    if (assetIds.isEmpty) return {};
    final database = await db;

    // SQLite has a limit for "IN (...)" length on some devices,
    // so we chunk it safely.
    const chunkSize = 400;
    final result = <String, String>{};

    for (int i = 0; i < assetIds.length; i += chunkSize) {
      final chunk = assetIds.sublist(i, (i + chunkSize).clamp(0, assetIds.length));
      final placeholders = List.filled(chunk.length, '?').join(',');

      final rows = await database.rawQuery(
        'SELECT asset_id, keywords FROM asset_tags WHERE asset_id IN ($placeholders)',
        chunk,
      );

      for (final row in rows) {
        final id = row['asset_id'] as String;
        final kw = row['keywords'] as String;
        result[id] = kw;
      }
    }

    return result;
  }

  /// Full-text search: returns asset IDs in best match order
  Future<List<String>> searchAssetIds(String query, {int limit = 200}) async {
    final database = await db;

    // FTS query: simple user input -> make it safer
    final safeQuery = _ftsSafe(query);
    if (safeQuery.isEmpty) return [];

    final rows = await database.rawQuery(
      'SELECT asset_id FROM asset_tags_fts WHERE asset_tags_fts MATCH ? LIMIT ?',
      [safeQuery, limit],
    );

    return rows.map((e) => e['asset_id'] as String).toList();
  }

  /// Clear DB (useful for debug)
  Future<void> clearAll() async {
    final database = await db;
    await database.delete('asset_tags');
    await database.delete('asset_tags_fts');
  }

  String _limitSize(String s, {required int maxChars}) {
    if (s.length <= maxChars) return s;
    return s.substring(0, maxChars);
  }

  /// Convert user query to a safer FTS expression
  /// Example: "wifi password" -> "wifi* password*"
  String _ftsSafe(String input) {
    final cleaned = input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleaned.isEmpty) return '';

    // Add prefix matching for each token
    final tokens = cleaned.split(' ').where((t) => t.length >= 2).toList();
    if (tokens.isEmpty) return '';

    // AND search:
    // token* token*
    return tokens.map((t) => '$t*').join(' ');
  }

  Future<void> close() async {
    final database = _db;
    if (database != null) {
      await database.close();
      _db = null;
    }
  }
}