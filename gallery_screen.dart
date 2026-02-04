import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/gallery_provider.dart';
import '../widgets/asset_tile.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _searchController = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      context.read<GalleryProvider>().search(_searchController.text);
    });

    _scroll.addListener(() {
      final p = context.read<GalleryProvider>();
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 900) {
        p.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GalleryProvider>();
    final assets = provider.filteredAssets;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Gallery'),
        actions: [
          IconButton(
            onPressed: () => provider.refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search (smart + ranked)...",
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          provider.clearSearch();
                          FocusScope.of(context).unfocus();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Expanded(
            child: assets.isEmpty && provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                    cacheExtent: 2000,
                    addRepaintBoundaries: true,
                    addAutomaticKeepAlives: false,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                    ),
                    itemCount: assets.length + (provider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= assets.length) {
                        // loader tile at bottom
                        return const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      return AssetTile(asset: assets[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}