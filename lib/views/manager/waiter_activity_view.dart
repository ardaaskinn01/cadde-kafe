import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

class WaiterActivityView extends StatefulWidget {
  const WaiterActivityView({Key? key}) : super(key: key);

  @override
  State<WaiterActivityView> createState() => _WaiterActivityViewState();
}

class _WaiterActivityViewState extends State<WaiterActivityView> {
  final _supabase = SupabaseService.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _waitersData = [];

  @override
  void initState() {
    super.initState();
    _fetchActivityData();
  }

  Future<void> _fetchActivityData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Tüm garsonları çek (role = 'garson')
      final waitersResponse = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'garson')
          .order('full_name');
      
      final List<Map<String, dynamic>> waiters = List<Map<String, dynamic>>.from(waitersResponse);

      // 2. Bugünkü siparişleri çek (İstatistikler için)
      final now = DateTime.now();
      DateTime businessStart = DateTime(now.year, now.month, now.day, 3, 0, 0);
      if (now.hour < 3) {
        businessStart = businessStart.subtract(const Duration(days: 1));
      }
      final todayStart = businessStart.toIso8601String();
      
      final ordersResponse = await _supabase
          .from('orders')
          .select('id, total_amount, waiter_id')
          .gte('created_at', todayStart);
      
      final List<Map<String, dynamic>> todayOrders = List<Map<String, dynamic>>.from(ordersResponse);

      // Verileri birleştir
      List<Map<String, dynamic>> processedData = [];
      for (var waiter in waiters) {
        final waiterOrders = todayOrders.where((o) => o['waiter_id'] == waiter['id']).toList();
        double totalSales = waiterOrders.fold(0.0, (sum, o) => sum + (o['total_amount'] ?? 0.0));
        
        processedData.add({
          'id': waiter['id'],
          'name': waiter['full_name'] ?? 'İsimsiz',
          'username': waiter['username'] ?? 'Tanımsız',
          'password': waiter['password'] ?? 'Tanımsız',
          'orderCount': waiterOrders.length,
          'totalSales': totalSales,
        });
      }

      setState(() {
        _waitersData = processedData;
      });
    } catch (e) {
      debugPrint('Aktivite verisi çekme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showWaiterOrdersDialog(String waiterId, String waiterName) async {
    showDialog(
      context: context,
      builder: (context) => _WaiterOrdersDetailDialog(
        waiterId: waiterId, 
        waiterName: waiterName,
        supabase: _supabase,
      ),
    );
  }

  Future<void> _deleteWaiter(String id, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Personeli Sil'),
        content: Text('$name isimli personeli sistemden silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await _supabase.from('profiles').delete().eq('id', id);
        // Not: auth.users tablosundan silmek için edge function gerekir, 
        // burada profil kaydını siliyoruz.
        _fetchActivityData();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name silindi.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        title: const Text('GARSONLAR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchActivityData),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.brown))
        : _waitersData.isEmpty 
          ? const Center(child: Text('Kayıtlı garson bulunamadı.'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _waitersData.length,
              itemBuilder: (context, index) {
                final waiter = _waitersData[index];
                return _buildWaiterCard(waiter);
              },
            ),
    );
  }

  Widget _buildWaiterCard(Map<String, dynamic> waiter) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: InkWell(
        onTap: () => _showWaiterOrdersDialog(waiter['id'], waiter['name']),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.brown.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    waiter['name'][0].toUpperCase(),
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.brown),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      waiter['name'],
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bugün: ${waiter['orderCount']} Sipariş',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Bugün: ₺${waiter['totalSales'].toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.key_rounded, color: Colors.blue, size: 20),
                        onPressed: () => _showCredentialsDialog(waiter),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Giriş Bilgileri',
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        onPressed: () => _deleteWaiter(waiter['id'], waiter['name']),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCredentialsDialog(Map<String, dynamic> waiter) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${waiter['name']} - Giriş Bilgileri'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kullanıcı Adı:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            Text(waiter['username'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Şifre:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
            Text(waiter['password'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }
}

class _WaiterOrdersDetailDialog extends StatelessWidget {
  final String waiterId;
  final String waiterName;
  final dynamic supabase;

  const _WaiterOrdersDetailDialog({
    required this.waiterId, 
    required this.waiterName, 
    required this.supabase
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.receipt_long, color: Colors.brown),
          const SizedBox(width: 10),
          Text('$waiterName - Günlük Rapor', style: const TextStyle(fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: FutureBuilder<dynamic>(
          future: supabase
              .from('orders')
              .select('id, table_id, total_amount, created_at, tables(name)')
              .eq('waiter_id', waiterId)
              .gte('created_at', (() {
                final now = DateTime.now();
                DateTime bStart = DateTime(now.year, now.month, now.day, 3, 0, 0);
                if (now.hour < 3) bStart = bStart.subtract(const Duration(days: 1));
                return bStart.toIso8601String();
              })())
              .order('created_at', ascending: false),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
              return const Center(child: Text('Bugün henüz sipariş alınmamış.'));
            }

            final List orders = snapshot.data as List;
            return ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final order = orders[index];
                final time = DateTime.parse(order['created_at']).toLocal();
                final tableName = order['tables'] != null ? order['tables']['name'] : 'Masa ${order['table_id']}';
                
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tableName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
                  trailing: Text('₺${order['total_amount']?.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }
}
