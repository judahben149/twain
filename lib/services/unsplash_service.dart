import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:twain/config/api_config.dart';
import 'package:twain/models/unsplash_wallpaper.dart';

/// Service for interacting with Unsplash API
/// Handles fetching wallpapers with mobile-optimized parameters
class UnsplashService {
  static const String _baseUrl = 'https://api.unsplash.com';
  static const int _perPage = 20; // Load 20 images per page for infinite scroll

  /// Unsplash Editorial collection ID for curated photos
  static const String _editorialCollectionId = '317099'; // Unsplash Editorial

  /// Build common headers for Unsplash API requests
  Map<String, String> _buildHeaders() {
    return {
      'Authorization': 'Client-ID ${ApiConfig.unsplashAccessKey}',
      'Accept-Version': 'v1',
    };
  }

  /// Build common query parameters for mobile wallpapers
  Map<String, String> _buildBaseParams() {
    return {
      'orientation': 'portrait', // Mobile-friendly aspect ratio
      'content_filter': 'high', // High-quality images only
    };
  }

  /// Fetch random wallpapers (Random filter)
  /// Returns a list of random high-quality portrait photos
  Future<List<UnsplashWallpaper>> fetchRandomWallpapers({
    int count = 20,
  }) async {
    try {
      final params = {
        ..._buildBaseParams(),
        'count': count.toString(),
      };

      final uri = Uri.parse('$_baseUrl/photos/random')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: _buildHeaders());

      if (response.statusCode == 429) {
        throw Exception(
            'Rate limit exceeded. Please try again in a few minutes.');
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch wallpapers: ${response.statusCode} - ${response.body}');
      }

      // Random endpoint returns array directly
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList
          .map((json) => UnsplashWallpaper.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching random wallpapers: $e');
      rethrow;
    }
  }

  /// Fetch editorial/curated wallpapers (Editorial filter)
  /// Returns photos from Unsplash Editorial collection
  Future<List<UnsplashWallpaper>> fetchEditorialWallpapers({
    int page = 1,
    int perPage = _perPage,
  }) async {
    try {
      final params = {
        ..._buildBaseParams(),
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      final uri = Uri.parse(
              '$_baseUrl/collections/$_editorialCollectionId/photos')
          .replace(queryParameters: params);

      final response = await http.get(uri, headers: _buildHeaders());

      if (response.statusCode == 429) {
        throw Exception(
            'Rate limit exceeded. Please try again in a few minutes.');
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to fetch wallpapers: ${response.statusCode} - ${response.body}');
      }

      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList
          .map((json) => UnsplashWallpaper.fromJson(json))
          .toList();
    } catch (e) {
      print('Error fetching editorial wallpapers: $e');
      rethrow;
    }
  }

  /// Fetch popular wallpapers (Popular filter)
  /// Uses search API with order_by=popular
  Future<List<UnsplashWallpaper>> fetchPopularWallpapers({
    int page = 1,
    int perPage = _perPage,
  }) async {
    return _searchWallpapers(
      query: 'wallpaper',
      orderBy: 'popular',
      page: page,
      perPage: perPage,
    );
  }

  /// Search wallpapers by category (Categories filter)
  /// Examples: nature, abstract, minimal, architecture, animals, etc.
  Future<List<UnsplashWallpaper>> searchByCategory({
    required String category,
    int page = 1,
    int perPage = _perPage,
  }) async {
    return _searchWallpapers(
      query: category,
      orderBy: 'relevant',
      page: page,
      perPage: perPage,
    );
  }

  /// Internal search method
  /// Handles Unsplash search API with various parameters
  Future<List<UnsplashWallpaper>> _searchWallpapers({
    required String query,
    required String orderBy, // 'relevant' or 'popular'
    int page = 1,
    int perPage = _perPage,
  }) async {
    try {
      final params = {
        ..._buildBaseParams(),
        'query': query,
        'page': page.toString(),
        'per_page': perPage.toString(),
        'order_by': orderBy,
      };

      final uri =
          Uri.parse('$_baseUrl/search/photos').replace(queryParameters: params);

      final response = await http.get(uri, headers: _buildHeaders());

      if (response.statusCode == 429) {
        throw Exception(
            'Rate limit exceeded. Please try again in a few minutes.');
      }

      if (response.statusCode != 200) {
        throw Exception(
            'Failed to search wallpapers: ${response.statusCode} - ${response.body}');
      }

      // Search endpoint returns object with 'results' array
      final Map<String, dynamic> jsonResponse = json.decode(response.body);
      final List<dynamic> results = jsonResponse['results'] as List<dynamic>;

      return results.map((json) => UnsplashWallpaper.fromJson(json)).toList();
    } catch (e) {
      print('Error searching wallpapers: $e');
      rethrow;
    }
  }

  /// Trigger download tracking for Unsplash attribution
  /// REQUIRED by Unsplash API guidelines when user downloads/applies wallpaper
  /// Does not actually download the image - just triggers Unsplash's download counter
  Future<void> triggerDownload(String? downloadLocation) async {
    if (downloadLocation == null || downloadLocation.isEmpty) {
      print('Warning: No download location provided for attribution');
      return;
    }

    try {
      final uri = Uri.parse(downloadLocation);
      final response = await http.get(uri, headers: _buildHeaders());

      if (response.statusCode != 200) {
        print('Warning: Failed to trigger download tracking: ${response.statusCode}');
        // Don't throw error - attribution tracking failure shouldn't block user
      } else {
        print('Successfully triggered Unsplash download tracking');
      }
    } catch (e) {
      print('Warning: Error triggering download tracking: $e');
      // Don't throw error - attribution tracking failure shouldn't block user
    }
  }

  /// Check if rate limit is exceeded by examining response headers
  /// Unsplash free tier: 50 requests/hour
  bool _isRateLimited(http.Response response) {
    final remainingHeader = response.headers['x-ratelimit-remaining'];
    if (remainingHeader != null) {
      final remaining = int.tryParse(remainingHeader) ?? 0;
      return remaining <= 0;
    }
    return false;
  }
}
