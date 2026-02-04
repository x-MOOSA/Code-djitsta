import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class AssetTile extends StatelessWidget {
  final AssetEntity asset;
  const AssetTile({super.key, required this.asset});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: AssetEntityImage(
          asset,
          isOriginal: false, // IMPORTANT: thumbnail only
          thumbnailSize: const ThumbnailSize.square(220),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}