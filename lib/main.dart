import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/services/supabase_service.dart';
import 'auth_wrapper.dart';
import 'views/customer/customer_menu_view.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // .env dosyasını yüklemeyi dene (Web ortamlarında dosya bulunamayabilir, try/catch önemli)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('.env dosyasi bulunamadi, sabit degerler kullanilacak.');
  }
  
  // Supabase bağlantısını başlat
  await SupabaseService.instance.initialize();
  
  // Türkçe tarih formatlarını yükle
  await initializeDateFormatting('tr_TR', null);
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cadde Kafe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
      // Web'de doğrudan müşteri menüsü, mobilde giriş ekranı
      home: kIsWeb ? const CustomerMenuView() : const AuthWrapper(),
    );
  }
}
