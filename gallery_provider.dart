import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/ai_service.dart';

class GalleryProvider extends ChangeNotifier {
  // Data Sources
  List<AssetEntity> _allAssets = []; // The master list of all photos
  List<AssetEntity> _displayAssets =
      []; // The list currently shown on screen (filtered)
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;

  // The AI Engine
  final AiService _aiService = AiService();
  // The Temporary Memory (AssetID -> Keywords)
  final Map<String, String> _aiMemory = {};

  // State Flags
  bool _isLoading = true;
  bool _isIndexing = false; // "True" when AI is analyzing in background

  // Getters
  List<AssetEntity> get assets => _displayAssets;
  List<AssetPathEntity> get albums => _albums;
  AssetPathEntity? get currentAlbum => _currentAlbum;
  bool get isLoading => _isLoading;
  bool get isIndexing => _isIndexing;

  /// 1. Initialize Permissions and Fetch Data
  Future<void> init() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      await _fetchAlbums();
    } else {
      PhotoManager.openSetting();
    }
  }

  /// 2. Fetch Albums (Folders)
  Future<void> _fetchAlbums() async {
    // Fetch albums (Camera, WhatsApp, Screenshots, etc.)
    _albums = await PhotoManager.getAssetPathList(type: RequestType.image);

    if (_albums.isNotEmpty) {
      _currentAlbum = _albums.first; // Usually "Recent"
      await _loadAssetsFromAlbum(_currentAlbum!);
    } else {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 3. Load Photos from a specific Album
  Future<void> changeAlbum(AssetPathEntity album) async {
    _isLoading = true;
    _currentAlbum = album;
    notifyListeners(); // Update UI to show loading spinner

    await _loadAssetsFromAlbum(album);
  }

  Future<void> _loadAssetsFromAlbum(AssetPathEntity album) async {
    // Fetch first 1000 images (Pagination should be implemented for production)
    _allAssets = await album.getAssetListRange(start: 0, end: 1000);
    _displayAssets = _allAssets; // Initially show everything

    _isLoading = false;
    notifyListeners();

    // Start AI analysis in background silently
    _startBackgroundIndexing();
  }

  /// 4. The AI Analysis Loop
  Future<void> _startBackgroundIndexing() async {
    if (_isIndexing) return; // Prevent double running
    _isIndexing = true;
    notifyListeners();

    // Analyze images one by one
    for (var asset in _allAssets) {
      // Skip if we already analyzed this one
      if (_aiMemory.containsKey(asset.id)) continue;

      File? file = await asset.file;
      if (file != null) {
        String keywords = await _aiService.analyzeImage(file);
        _aiMemory[asset.id] = keywords;

        // Debug: Print to console to prove it's working
        if (keywords.isNotEmpty) {
          print("AI Indexed [${asset.id}]: $keywords");
        }
      }
    }

    _isIndexing = false;
    notifyListeners();
  }

  /// 5. The Search Function
  void search(String query) {
    if (query.isEmpty) {
      _displayAssets = _allAssets;
    } else {
      final lowercaseQuery = query.toLowerCase();

      _displayAssets = _allAssets.where((asset) {
        final keywords = _aiMemory[asset.id] ?? "";
        // Match against AI keywords
        return keywords.contains(lowercaseQuery);
      }).toList();
    }
    notifyListeners();
  }
}