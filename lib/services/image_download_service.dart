import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

/// Service for downloading images to the device gallery
class ImageDownloadService {
  /// Downloads an image from URL and saves it to the device gallery
  /// Returns true on success, false on failure
  static Future<bool> downloadToGallery(String imageUrl) async {
    try {
      debugPrint('ImageDownloadService: Starting download from $imageUrl');

      // Download the image bytes
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200) {
        debugPrint('ImageDownloadService: HTTP error ${response.statusCode}');
        return false;
      }

      final Uint8List bytes = response.bodyBytes;
      debugPrint('ImageDownloadService: Downloaded ${bytes.length} bytes');

      // Save to temporary file first (Gal requires a file path)
      final tempDir = await getTemporaryDirectory();
      final fileName = 'twain_wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(bytes);

      // Save to gallery using Gal
      await Gal.putImage(tempFile.path, album: 'Twain');

      // Clean up temp file
      await tempFile.delete();

      debugPrint('ImageDownloadService: Successfully saved to gallery');
      return true;
    } catch (e) {
      debugPrint('ImageDownloadService: Error downloading image - $e');
      return false;
    }
  }
}
