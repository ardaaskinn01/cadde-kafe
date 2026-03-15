import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/services/auth_service.dart';
import 'core/services/supabase_service.dart';
import 'views/auth/login_view.dart';
import 'views/manager/manager_home_view.dart';
import 'views/waiter/waiter_home_view.dart';
import 'views/cashier/cashier_home_view.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  late final StreamSubscription<AuthState> _authSubscription;
  Widget _targetView = const Scaffold(body: Center(child: CircularProgressIndicator()));
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _handleAuthState(SupabaseService.instance.client.auth.currentSession != null);
    
    _authSubscription = SupabaseService.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.signedOut || event == AuthChangeEvent.tokenRefreshed) {
        _handleAuthState(data.session != null);
      }
    });
  }

  Future<void> _handleAuthState(bool isAuthenticated) async {
    if (!isAuthenticated) {
      if (mounted) {
        setState(() {
          _targetView = const LoginView();
          _errorMessage = null;
        });
      }
      return;
    }

    // Giriş yapılmışsa profil çekmeyi dene
    try {
      final profile = await _authService.getCurrentProfile();
      
      if (!mounted) return;

      if (profile != null) {
        final role = profile['role'].toString(); // toString() ekledik (Enum vs String uyuşmazlığı için)
        setState(() {
          if (role == 'yonetici') {
            _targetView = const ManagerHomeView();
          } else if (role == 'garson') {
            _targetView = const WaiterHomeView();
          } else if (role == 'kasa') {
            _targetView = const CashierHomeView();
          } else {
            _targetView = LoginView(errorMessage: 'Bilinmeyen rol: $role. Lütfen yöneticiye danışın.');
          }
        });
      } else {
        // Oturum var ama profiles tablosunda karşılık yok
        setState(() {
          _targetView = const LoginView(errorMessage: 'Kullanıcı oturumu açıldı ancak profil kaydı bulunamadı. Lütfen Supabase "profiles" tablosunu kontrol edin.');
        });
        // Oturumu kapatıp login ekranında kalmasını sağlayalım ki hatayı görsün
        await _authService.signOut();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _targetView = LoginView(errorMessage: 'Profil yüklenirken hata oluştu: ${e.toString()}');
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _targetView;
  }
}
