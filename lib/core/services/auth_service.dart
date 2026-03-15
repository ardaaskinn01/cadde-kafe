import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _supabase = SupabaseService.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  bool get isSessionActive => _supabase.auth.currentSession != null;

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      return response;
    } catch (e) {
      return null;
    }
  }

  // Sadece kullanıcı adı ile giriş, arkaplanda @example.com eklenir
  Future<AuthResponse> signIn({
    required String username,
    required String password,
  }) async {
    final email = '${username.trim().toLowerCase()}@example.com';
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Yeni personel kaydetme fonksiyonu (Admin yetkisiyle, oturumu bozmadan)
  Future<void> addPersonnel({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) async {
    final sanitizedUsername = username.trim().toLowerCase().replaceAll(' ', '.');
    final email = '$sanitizedUsername@example.com';
    
    // OTURUMUN KAYMAMASI İÇİN: Geçici bir Supabase istemcisi oluşturuyoruz.
    // persistSession: false yaparak PKCE / Storage hatalarını engelliyoruz.
    final tempSupabase = SupabaseClient(
      AppConstants.supabaseUrl, 
      AppConstants.supabaseAnonKey,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit, // PKCE yerine implicit kullan (Storage gerektirmez)
      ),
    );
    
    // 1. Auth tablosunda geçici istemci ile kullanıcı oluştur
    final response = await tempSupabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // 2. Profiles tablosuna kaydet (Main client kullanarak yönetici olarak insert atıyor)
      await _supabase.from('profiles').upsert({
        'id': response.user!.id,
        'full_name': fullName,
        'role': role,
      });
      
      // Geçici istemciyi temizle
      await tempSupabase.dispose();
    }
  }
}
