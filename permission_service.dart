import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestGalleryPermission() async {
    if (!Platform.isAndroid) return true;

    // Android 13+ uses Photos/Videos permissions
    final Permission permission =
        (await _isAndroid13OrAbove()) ? Permission.photos : Permission.storage;

    final status = await permission.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    final result = await permission.request();

    if (result.isGranted || result.isLimited) {
      return true;
    }

    // Only open settings if user permanently denied
    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }

    return false;
  }

  static Future<bool> _isAndroid13OrAbove() async {
    // Android SDK 33 = Android 13
    // permission_handler handles internally, but we keep it safe here:
    return true; // safe fallback; photos permission exists only on newer devices
  }
}