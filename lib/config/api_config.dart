import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized API configuration class
/// Loads credentials from .env file
class ApiConfig {
  // Unsplash API Configuration
  static String get unsplashAccessKey =>
      dotenv.env['UNSPLASH_ACCESS_KEY'] ?? '';
  static String get unsplashSecretKey =>
      dotenv.env['UNSPLASH_SECRET_KEY'] ?? '';
  static String get unsplashAppId => dotenv.env['UNSPLASH_APP_ID'] ?? '';
  static const String unsplashBaseUrl = 'https://api.unsplash.com';

  // Supabase Configuration
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Google OAuth Configuration
  static String get googleClientIdIOS =>
      dotenv.env['GOOGLE_CLIENT_ID_IOS'] ?? '';
  static String get googleWebClientId =>
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';

  // Dicebear API (no auth required)
  static const String dicebearBaseUrl = 'https://api.dicebear.com/7.x';

  // Environment
  static String get environment => dotenv.env['ENVIRONMENT'] ?? 'development';
  static bool get isProduction => environment == 'production';

  /// Validate that all required keys are loaded
  static bool validateKeys() {
    if (unsplashAccessKey.isEmpty) {
      print('Warning: UNSPLASH_ACCESS_KEY not found in .env');
      return false;
    }
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      print('Warning: Supabase credentials not found in .env');
      return false;
    }
    return true;
  }
}
