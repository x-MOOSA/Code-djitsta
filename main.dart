import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'providers/gallery_provider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => GalleryProvider())],
      child: const AiGalleryApp(),
    ),
  );
}

class AiGalleryApp extends StatelessWidget {
  const AiGalleryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AI Gallery',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1115), // Deep matte black
        primaryColor: const Color(0xFF6C63FF), // Neon Purple
        hintColor: Colors.white24,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const GalleryScreen(),
    );
  }
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize provider after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GalleryProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to provider changes
    final provider = context.watch<GalleryProvider>();

    return Scaffold(
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: const Color(0xFF0F1115).withOpacity(0.95),
            elevation: 0,
            expandedHeight: 130, // Height for Search + Filters
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      // SEARCH BAR
                      _buildSearchBar(context, provider),
                      const SizedBox(height: 12),
                      // ALBUM FILTERS
                      _buildAlbumSelector(provider),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        body: _buildGalleryGrid(provider),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildSearchBar(BuildContext context, GalleryProvider provider) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E222B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => provider.search(value),
        style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: "Search 'Receipt', 'Cat', 'Wifi'...",
          hintStyle: GoogleFonts.outfit(color: Colors.white38),
          prefixIcon: const Icon(
            Icons.auto_awesome,
            color: Color(0xFF6C63FF),
            size: 20,
          ),
          suffixIcon: provider.isIndexing
              ? Transform.scale(
                  scale: 0.4,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mic, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  Widget _buildAlbumSelector(GalleryProvider provider) {
    if (provider.albums.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: provider.albums.length,
        itemBuilder: (context, index) {
          final album = provider.albums[index];
          final isSelected = album == provider.currentAlbum;

          return GestureDetector(
            onTap: () => provider.changeAlbum(album),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF1E222B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Text(
                album.name,
                style: GoogleFonts.outfit(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGalleryGrid(GalleryProvider provider) {
    if (provider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6C63FF)),
      );
    }

    if (provider.assets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: Colors.white24,
            ),
            const SizedBox(height: 10),
            Text(
              "No images found",
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: provider.assets.length,
      itemBuilder: (_, index) {
        return _buildImageTile(provider.assets[index]);
      },
    );
  }

  Widget _buildImageTile(AssetEntity asset) {
    return Container(
      color: const Color(0xFF1E222B),
      child: AssetEntityImage(
        asset,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(300),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.broken_image, size: 16, color: Colors.grey),
        ),
      ),
    );
  }
}