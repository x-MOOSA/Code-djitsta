import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryProvider extends ChangeNotifier {
  // Main list (paged)
  final List<AssetEntity> _allAssets = [];
  List<AssetEntity> filteredAssets = [];

  // Album
  AssetPathEntity? _album;

  // Paging
  int _page = 0;
  final int _pageSize = 200;
  bool isLoading = false;
  bool hasMore = true;

  // Search index (id -> normalized searchable text)
  final Map<String, String> _searchTextById = {};

  // Search
  Timer? _debounce;
  String _lastQuery = "";

  // Public getters
  List<AssetEntity> get allAssets => List.unmodifiable(_allAssets);

  Future<void> init() async {
    await _requestPermissionAndLoad();
  }

  Future<void> _requestPermissionAndLoad() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (!ps.isAuth) {
      // permission denied
      _allAssets.clear();
      filteredAssets = [];
      notifyListeners();
      return;
    }

    // Get albums (only images)
    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      onlyAll: true,
    );

    if (paths.isEmpty) {
      _allAssets.clear();
      filteredAssets = [];
      notifyListeners();
      return;
    }

    _album = paths.first;
    await refresh();
  }

  Future<void> refresh() async {
    _page = 0;
    hasMore = true;
    _allAssets.clear();
    _searchTextById.clear();
    _lastQuery = "";
    filteredAssets = [];
    notifyListeners();

    await loadMore(); // load first page
  }

  Future<void> loadMore() async {
    if (isLoading || !hasMore || _album == null) return;

    isLoading = true;
    notifyListeners();

    final items = await _album!.getAssetListPaged(page: _page, size: _pageSize);

    if (items.isEmpty) {
      hasMore = false;
    } else {
      _allAssets.addAll(items);
      _page++;
      // Build index for new items (async)
      unawaited(_buildSearchIndexFor(items));
    }

    // Apply current search (or show all)
    _applySearch(_lastQuery);

    isLoading = false;
    notifyListeners();
  }

  Future<void> _buildSearchIndexFor(List<AssetEntity> items) async {
    for (final a in items) {
      final title = (await a.titleAsync) ?? "";
      // you can add OCR text later like: "$title ${ocrTextById[a.id] ?? ""}"
      _searchTextById[a.id] = _normalize(title);
    }
    // re-run search after index updates (if user already typed)
    _applySearch(_lastQuery);
    notifyListeners();
  }

  // Debounced call from UI
  void search(String query) {
    _lastQuery = query;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      _applySearch(_lastQuery);
      notifyListeners();
    });
  }

  void clearSearch() {
    _debounce?.cancel();
    _lastQuery = "";
    _applySearch("");
    notifyListeners();
  }

  void _applySearch(String query) {
    final q = _normalize(query);

    if (q.isEmpty) {
      filteredAssets = List.of(_allAssets);
      return;
    }

    final cheapMode = q.length <= 2;

    final scored = <({AssetEntity asset, int score})>[];

    for (final a in _allAssets) {
      final haystack = _searchTextById[a.id] ?? "";

      int score = 0;

      // Fast boosts
      if (haystack.contains(q)) score += 60;

      final qTokens = q.split(' ').where((t) => t.isNotEmpty).toList();
      if (qTokens.isNotEmpty) {
        int hits = 0;
        for (final t in qTokens) {
          if (haystack.contains(t)) hits++;
        }
        score += hits * 20;
      }

      if (!cheapMode) {
        // Fuzzy rankers
        score += weightedRatio(q, haystack);
        score += partialRatio(q, haystack);
      }

      if (score >= (cheapMode ? 40 : 80)) {
        scored.add((asset: a, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    filteredAssets = scored.map((e) => e.asset).toList();
  }

  String _normalize(String s) {
    final lower = s.toLowerCase();
    return lower
        .replaceAll(RegExp(r'[^a-z0-9\s]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

// tiny helper so analyzer doesn’t complain
void unawaited(Future<void> f) {}