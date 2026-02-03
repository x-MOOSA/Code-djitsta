import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/ai_service.dart';
import '../services/db_service.dart';

class GalleryProvider extends ChangeNotifier {
  // ---- DATA ----
  final List<AssetEntity> _allAssets = [];
  List<AssetEntity> _displayAssets = [];
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;

  // Pagination
  static const int _pageSize = 120;
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isFetchingMore = false;

  // AI + DB
  final AiService _aiService = AiService();
  final DbService _db = DbService.instance;

  // In-memory cache (assetId -> keywords)
  final Map<String, String> _aiMemory = {};

  // ---- STATE ----
  bool _isLoading = true;
  bool _isIndexing = false;
  String _lastQuery = '';

  // Cancel / throttle indexing
  bool _stopIndexing = false;

  // ---- GETTERS ----
  List<AssetEntity> get assets => _displayAssets;
  List<AssetPathEntity> get albums => _albums;
  AssetPathEntity? get currentAlbum => _currentAlbum;

  bool get isLoading => _isLoading;
  bool get isIndexing => _isIndexing;
  bool get hasMore => _hasMore;
  bool get isFetchingMore => _isFetchingMore;

  // ---- INIT ----
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      PhotoManager.openSetting();
      _isLoading = false;
      notifyListeners();
      return;
    }

    await _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    _albums = await PhotoManager.getAssetPathList(type: RequestType.image);

    if (_albums.isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _currentAlbum = _albums.first;
    await _loadFirstPage(_currentAlbum!);
  }

  // ---- ALBUM SWITCH ----
  Future<void> changeAlbum(AssetPathEntity album) async {
    _stopIndexing = true; // stop previous indexing
    _currentAlbum = album;

    _isLoading = true;
    notifyListeners();

    await _loadFirstPage(album);
  }

  // ---- PAGINATION ----
  Future<void> _loadFirstPage(AssetPathEntity album) async {
    _allAssets.clear();
    _displayAssets = [];
    _aiMemory.clear();

    _currentPage = 0;
    _hasMore = true;
    _isFetchingMore = false;
    _stopIndexing = false;
    _lastQuery = '';

    await _fetchNextPageInternal(album);

    _isLoading = false;
    notifyListeners();

    // start background indexing
    _startBackgroundIndexing();
  }

  Future<void> fetchNextPage() async {
    if (_currentAlbum == null) return;
    if (!_hasMore || _isFetchingMore) return;

    await _fetchNextPageInternal(_currentAlbum!);
    notifyListeners();

    // Continue indexing new items
    _startBackgroundIndexing();
  }

  Future<void> _fetchNextPageInternal(AssetPathEntity album) async {
    _isFetchingMore = true;
    notifyListeners();

    final page = await album.getAssetListPaged(page: _currentPage, size: _pageSize);

    if (page.isEmpty) {
      _hasMore = false;
      _isFetchingMore = false;
      return;
    }

    _allAssets.addAll(page);

    // Load saved tags for this new page
    final ids = page.map((e) => e.id).toList();
    final saved = await _db.loadTagsForIds(ids);
    _aiMemory.addAll(saved);

    // Update display list based on current query
    if (_lastQuery.isEmpty) {
      _displayAssets = List.of(_allAssets);
    } else {
      await _applySearchFromDb(_lastQuery);
    }

    _currentPage++;
    _isFetchingMore = false;
  }

  // ---- INDEXING (smooth + stable) ----
  Future<void> _startBackgroundIndexing() async {
    if (_isIndexing) return;
    _isIndexing = true;
    notifyListeners();

    _stopIndexing = false;

    // Process only a limited number per run to keep UI smooth
    // and avoid heating device.
    const int perRunLimit = 80;
    int done = 0;

    for (final asset in _allAssets) {
      if (_stopIndexing) break;
      if (done >= perRunLimit) break;

      if (_aiMemory.containsKey(asset.id)) continue;

      File? file;
      try {
        file = await asset.file;
      } catch (_) {
        file = null;
      }
      if (file == null) continue;

      final keywords = await _aiService.analyzeImage(file);
      if (keywords.isNotEmpty) {
        _aiMemory[asset.id] = keywords;

        // Save persistently
        await _db.upsertTag(assetId: asset.id, keywords: keywords);

        // If user is actively searching, refresh results
        if (_lastQuery.isNotEmpty) {
          await _applySearchFromDb(_lastQuery);
        }
      } else {
        // Even if empty, store in memory so we don't reprocess constantly
        _aiMemory[asset.id] = '';
      }

      done++;

      // Yield to UI every few items
      if (done % 6 == 0) {
        await Future.delayed(const Duration(milliseconds: 1));
        notifyListeners();
      }
    }

    _isIndexing = false;
    notifyListeners();
  }

  // ---- SEARCH ----
  void search(String query) {
    _lastQuery = query.trim();

    if (_lastQuery.isEmpty) {
      _displayAssets = List.of(_allAssets);
      notifyListeners();
      return;
    }

    // Use DB FTS for best performance
    _applySearchFromDb(_lastQuery);
  }

  Future<void> _applySearchFromDb(String query) async {
    final ids = await _db.searchAssetIds(query, limit: 600);

    if (ids.isEmpty) {
      _displayAssets = [];
      notifyListeners();
      return;
    }

    final idSet = ids.toSet();

    // Keep ordering based on gallery order (fast + simple)
    _displayAssets = _allAssets.where((a) => idSet.contains(a.id)).toList();
    notifyListeners();
  }

  // ---- CLEANUP ----
  @override
  void dispose() {
    _stopIndexing = true;
    _aiService.dispose();
    _db.close();
    super.dispose();
  }
}