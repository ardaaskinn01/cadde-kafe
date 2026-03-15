import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get supabaseUrl => dotenv.env['supabaseUrl'] ?? '';
  static String get supabaseAnonKey => dotenv.env['supabaseAnonKey'] ?? '';
}
