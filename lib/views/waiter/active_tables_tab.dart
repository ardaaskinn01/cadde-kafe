import 'package:flutter/material.dart';
import 'table_detail_view.dart';
import '../../core/services/supabase_service.dart';

class ActiveTablesTab extends StatefulWidget {
  const ActiveTablesTab({Key? key}) : super(key: key);

  @override
  State<ActiveTablesTab> createState() => _ActiveTablesTabState();
}

class _ActiveTablesTabState extends State<ActiveTablesTab> {
  final _supabase = SupabaseService.instance.client;
  List<Map<String, dynamic>> _activeTables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchActiveTables();
  }

  Future<void> _fetchActiveTables() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('tables')
          .select('*, orders(id, total_amount, status, order_items(quantity, products(name)))')
          .eq('status', 'occupied')
          .eq('orders.status', 'bekliyor');
      
      final List<Map<String, dynamic>> tables = List<Map<String, dynamic>>.from(response);
      
      // Doğal sıralama
      tables.sort((a, b) {
        String nameA = a['name'] ?? '';
        String nameB = b['name'] ?? '';
        if (nameA[0] == nameB[0]) {
          int valA = int.tryParse(nameA.substring(1)) ?? 0;
          int valB = int.tryParse(nameB.substring(1)) ?? 0;
          return valA.compareTo(valB);
        }
        return nameA.compareTo(nameB);
      });

      setState(() {
        _activeTables = tables;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Aktif masa çekme hatası: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showChangeTableDialog(Map<String, dynamic> table) async {
    final String currentTableName = table['name'];
    final String tableId = table['id'];
    final activeOrders = table['orders'] as List;
    if (activeOrders.isEmpty) return;
    final String orderId = activeOrders.first['id'];

    String newTableName = '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('$currentTableName - Masa Değiştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Bu masadaki siparişi başka bir boş masaya aktar.'),
            const SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Yeni Masa No (Örn: B12)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => newTableName = val.toUpperCase().trim(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Aktar / Değiştir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && newTableName.isNotEmpty && newTableName != currentTableName) {
      try {
        // 1. Yeni masayı bul
        final targetRes = await _supabase
            .from('tables')
            .select()
            .eq('name', newTableName)
            .maybeSingle();
        
        if (targetRes == null) {
          throw 'Hedef masa bulunamadı.';
        }
        if (targetRes['status'] == 'occupied') {
          throw 'Hedef masa dolu!';
        }

        final targetId = targetRes['id'];

        // 2. Siparişi yeni masaya aktar
        await _supabase.from('orders').update({'table_id': targetId}).eq('id', orderId);
        
        // 3. Masaların durumlarını güncelle
        await _supabase.from('tables').update({'status': 'available'}).eq('id', tableId);
        await _supabase.from('tables').update({'status': 'occupied'}).eq('id', targetId);

        _fetchActiveTables();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Masa $currentTableName -> $newTableName taşındı')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.brown));
    }

    if (_activeTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.no_meals_outlined, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Açık masa bulunmamaktadır.', style: TextStyle(fontSize: 18, color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchActiveTables,
      color: Colors.brown,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _activeTables.length,
        itemBuilder: (context, index) {
          final table = _activeTables[index];
          final String tableName = table['name'];
          final orders = table['orders'] as List;
          final dynamic totalAmount = orders.isNotEmpty ? orders.first['total_amount'] : 0;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.table_restaurant, color: Colors.orange),
                  ),
                  title: Text(
                    'Masa $tableName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '₺${totalAmount.toString()}',
                            style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.swap_horiz_rounded, color: Colors.blue),
                        onPressed: () => _showChangeTableDialog(table),
                        tooltip: 'Masayı Taşı',
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TableDetailView(tableName: tableName),
                      ),
                    );
                    _fetchActiveTables();
                  },
                ),
                if (orders.isNotEmpty && (orders.first['order_items'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SİPARİŞ İÇERİĞİ',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.brown, letterSpacing: 1),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (orders.first['order_items'] as List).map((item) {
                              final productName = item['products'] != null ? item['products']['name'] : 'Ürün';
                              final quantity = item['quantity'];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  '$quantity x $productName',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
