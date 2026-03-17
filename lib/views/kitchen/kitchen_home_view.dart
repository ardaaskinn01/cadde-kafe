import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../auth_wrapper.dart';
import '../../core/services/supabase_service.dart';

class KitchenHomeView extends StatefulWidget {
  const KitchenHomeView({Key? key}) : super(key: key);

  @override
  State<KitchenHomeView> createState() => _KitchenHomeViewState();
}

class _KitchenHomeViewState extends State<KitchenHomeView> {
  final _supabase = SupabaseService.instance.client;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;
  List<Map<String, dynamic>> _pendingOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _setupRealtime();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Otomatik olarak her 10 saniyede bir sayfayı yeniler, ağ kopmalarına karşı tedbir.
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchOrders();
    });
  }

  void _setupRealtime() {
    // 'orders' tablosundaki durum güncellemelerini ve 'order_items' eklemelerini anlık dinler.
    _realtimeChannel = _supabase.channel('public:kitchen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) => _handleDataChange(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'order_items',
          callback: (payload) => _handleDataChange(),
        )
        .subscribe();
  }

  void _handleDataChange() {
    if (mounted) {
      _fetchOrders();
    }
  }

  Future<void> _fetchOrders() async {
    try {
      // Yalnızca durumu 'bekliyor' (yeni) veya 'hazirlaniyor' olan, 
      // aktif/dolu olan masalara ait siparişleri çeker.
      final response = await _supabase
          .from('orders')
          .select('*, tables(name, status), order_items(quantity, notes, products(name, category_id))')
          .inFilter('status', ['bekliyor', 'hazirlaniyor'])
          .order('created_at', ascending: false); // En yeni sipariş en başta görünür.
          
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);
      
      // Sipariş öğesi olmayan veya masası boş olan hatalı kayıtları filtreler.
      final validOrders = orders.where((order) {
        final table = order['tables'];
        final items = order['order_items'] as List?;
        if (table == null || table['status'] != 'occupied') return false;
        if (items == null || items.isEmpty) return false;
        return true;
      }).toList();

      if (mounted) {
        setState(() {
          _pendingOrders = validOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Mutfak sipariş çekme hatası: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
      
      // UI anında güncellensin diye listeyi çek. (Realtime de çalışıyor ama bu daha hızlı bir response hissi verir.)
      _fetchOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _logout() async {
    await AuthService().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.brown.shade800,
        title: const Text(
          'MUTFAK EKRANI',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchOrders();
            },
            tooltip: 'Yenile',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Çıkış Yap',
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : _pendingOrders.isEmpty
              ? _buildEmptyState()
              : _buildOrdersGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 100, color: Colors.green.shade200),
          const SizedBox(height: 20),
          const Text(
            'Mutfak Şefi, Bekleyen Sipariş Yok!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54),
          ),
          const SizedBox(height: 8),
          const Text('Harika iş çıkardınız. Yeni siparişler anında buraya düşecek.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOrdersGrid() {
    // Masaüstüne uygun duyarlı Grid tasarımı
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 2; // Normal tabletler için
    if (screenWidth > 1200) crossAxisCount = 4; // Çok geniş ekranlar
    else if (screenWidth > 900) crossAxisCount = 3; // Çoğu masaüstü ekran

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1, // Kartların en-boy oranı (daha kısa, 3'te 2 civarı)
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: _pendingOrders.length,
      itemBuilder: (context, index) {
        final order = _pendingOrders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String tableName = order['tables']['name'];
    final Color headerColor = Colors.brown.shade700;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Adisyon Başlığı (Masa)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              'MASA $tableName',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ),
            
          // Sipariş İçeriği (İtemler)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: (order['order_items'] as List).length,
              itemBuilder: (context, idx) {
                final item = order['order_items'][idx];
                final productName = item['products']['name'];
                final quantity = item['quantity'];
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6)),
                        child: Text('${quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Aksiyon Butonları (Sadece Hazır)
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                _updateOrderStatus(order['id'], 'teslim_edildi');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'HAZIR',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}