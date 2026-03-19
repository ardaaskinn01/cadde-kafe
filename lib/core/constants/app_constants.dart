import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  static String get supabaseUrl => dotenv.env['supabaseUrl'] ?? 'https://qyspmovwlbhooidiekzq.supabase.co';
  static String get supabaseAnonKey => dotenv.env['supabaseAnonKey'] ?? 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF5c3Btb3Z3bGJob29pZGlla3pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM1MjE4MTAsImV4cCI6MjA4OTA5NzgxMH0.HFNwsJF-Cr6MCV4igK1RRWue9PTLhLx0oJnykyAeBFY';
}
