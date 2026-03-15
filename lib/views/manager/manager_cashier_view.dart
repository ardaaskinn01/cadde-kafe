import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import 'menu_management_view.dart';

class ManagerCashierView extends StatefulWidget {
  const ManagerCashierView({Key? key}) : super(key: key);

  @override
  State<ManagerCashierView> createState() => _ManagerCashierViewState();
}

class _ManagerCashierViewState extends State<ManagerCashierView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = SupabaseService.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allTables = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchTables();
  }

  Future<void> _fetchTables() async {
    setState(() => _isLoading = true);
    try {
      // Tüm masaları çek, varsa içindeki aktif siparişi de getir
      final response = await _supabase
          .from('tables')
          .select('*, orders(total_amount, status)')
          .order('name');
      
      // PostgREST join filtrelemesi yerine, kod tarafında aktif olmayan siparişleri temizleyelim
      final List<Map<String, dynamic>> tables = List<Map<String, dynamic>>.from(response);
      
      // Doğal Sıralama (Natural Sort) Uygula: A1, A2, A3... A10, A11 şeklinde sıralar
      tables.sort((a, b) {
        String nameA = a['name'] ?? '';
        String nameB = b['name'] ?? '';
        if (nameA.isEmpty || nameB.isEmpty) return 0;
        
        // İlk karakterler (A veya B) aynıysa sayıya göre, değilse harfe göre sırala
        if (nameA[0] == nameB[0]) {
          int valA = int.tryParse(nameA.substring(1)) ?? 0;
          int valB = int.tryParse(nameB.substring(1)) ?? 0;
          return valA.compareTo(valB);
        }
        return nameA.compareTo(nameB);
      });
      
      for (var table in tables) {
        if (table['orders'] != null) {
          // Sadece 'bekliyor' olan siparişleri tut, diğerlerini (tamamlanmışları) listeden çıkar
          table['orders'] = (table['orders'] as List).where((o) => o['status'] == 'bekliyor').toList();
        }
      }

      setState(() {
        _allTables = tables;
      });
    } catch (e) {
      debugPrint('Masa çekme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToTableDetail(Map<String, dynamic> table) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagerTableDetailView(table: table),
      ),
    );
    _fetchTables(); // Geri dönünce listeyi tazele
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        title: const Text(
          'MOBİL KASA',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.brown,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.brown,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'A BÖLÜMÜ'),
            Tab(text: 'B BÖLÜMÜ'),
            Tab(text: 'AÇIK MASALAR'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchTables,
          ),
        ],
      ),
      endDrawer: _buildControlDrawer(),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSectionGrid('A'),
                _buildSectionGrid('B'),
                _buildActiveTablesList(),
              ],
            ),
    );
  }

  Widget _buildSectionGrid(String section) {
    final sectionTables = _allTables.where((t) => (t['name'] as String).startsWith(section)).toList();
    
    if (sectionTables.isEmpty) {
      return const Center(child: Text('Bu bölümde henüz masa tanımlanmamış.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1,
      ),
      itemCount: sectionTables.length,
      itemBuilder: (context, index) {
        final table = sectionTables[index];
        final isOccupied = table['status'] == 'occupied';
        final activeOrder = (table['orders'] as List).isNotEmpty ? table['orders'][0] : null;
        final amount = activeOrder != null ? activeOrder['total_amount'] ?? 0.0 : 0.0;

        return InkWell(
          onTap: () => _goToTableDetail(table),
          child: Container(
            decoration: BoxDecoration(
              color: isOccupied ? Colors.orange.shade50 : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOccupied ? Colors.orange.shade200 : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  table['name'],
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isOccupied ? Colors.orange.shade900 : Colors.black87,
                  ),
                ),
                if (isOccupied) ...[
                  const SizedBox(height: 4),
                  Text(
                    '₺${amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.brown, fontSize: 13),
                  ),
                ] else
                   Text(
                    'BOŞ',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTablesList() {
    final activeTables = _allTables.where((t) => t['status'] == 'occupied').toList();

    if (activeTables.isEmpty) {
      return const Center(child: Text('Şu an açık masanız bulunmuyor.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeTables.length,
      itemBuilder: (context, index) {
        final table = activeTables[index];
        final activeOrder = (table['orders'] as List).isNotEmpty ? table['orders'][0] : null;
        final amount = activeOrder != null ? activeOrder['total_amount'] ?? 0.0 : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8)],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.shade100,
              child: const Icon(Icons.table_bar_rounded, color: Colors.orange),
            ),
            title: Text('Masa ${table['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Ödeme Bekliyor', style: TextStyle(fontSize: 12)),
            trailing: Text(
              '₺${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.green),
            ),
            onTap: () => _goToTableDetail(table),
          ),
        );
      },
    );
  }

  Widget _buildControlDrawer() {
    return Drawer(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 60, bottom: 30, left: 20, right: 20),
            color: Colors.brown,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('KASA ARAÇLARI', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                Text('Menü ve Ürün Kontrolü', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.restaurant_menu, 'Menü Yönetimi', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MenuManagementView()));
                }),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('HIZLI İŞLEMLER', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                _buildDrawerItem(Icons.add_box_rounded, 'Yeni Masa Ekle', () => Navigator.pop(context)),
                _buildDrawerItem(Icons.lock_clock_rounded, 'Gün Kapat', () => Navigator.pop(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.brown),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: onTap,
    );
  }
}

// ----- Masa Detayı (PROFESYONEL) -----
class ManagerTableDetailView extends StatefulWidget {
  final Map<String, dynamic> table;
  const ManagerTableDetailView({Key? key, required this.table}) : super(key: key);

  @override
  State<ManagerTableDetailView> createState() => _ManagerTableDetailViewState();
}

class _ManagerTableDetailViewState extends State<ManagerTableDetailView> {
  final _supabase = SupabaseService.instance.client;
  bool _isLoading = true;
  Map<String, dynamic>? _activeOrder;
  List<Map<String, dynamic>> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _fetchOrderDetail();
  }

  Future<void> _fetchOrderDetail() async {
    if (widget.table['status'] != 'occupied') {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Aktif siparişi ve ürünlerini çek
      final orderRes = await _supabase
          .from('orders')
          .select('*, order_items(*, products(name))')
          .eq('table_id', widget.table['id'])
          .eq('status', 'bekliyor')
          .maybeSingle();
      
      if (orderRes != null) {
        setState(() {
          _activeOrder = orderRes;
          _orderItems = List<Map<String, dynamic>>.from(orderRes['order_items']);
        });
      }
    } catch (e) {
      debugPrint('Sipariş detayı hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processPayment() async {
    if (_activeOrder == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ödeme Onayı'),
        content: Text('₺${_activeOrder!['total_amount']} tutarındaki ödeme alındı mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hayır')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Evet, Ödendi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        // 1. Siparişi tamamla
        await _supabase
            .from('orders')
            .update({'status': 'odendi'})
            .eq('id', _activeOrder!['id']);
        
        // 2. Masayı boşalt
        await _supabase
            .from('tables')
            .update({'status': 'available'})
            .eq('id', widget.table['id']);
        
        if (mounted) Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        title: Text('MASA ${widget.table['name']} ADİSYON', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : _activeOrder == null
              ? const Center(child: Text('Bu masa şu an boş.'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _orderItems.length,
                        itemBuilder: (context, index) {
                          final item = _orderItems[index];
                          final prodName = item['products'] != null ? item['products']['name'] : 'Ürün';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.brown.shade50, shape: BoxShape.circle),
                                  child: Text('${item['quantity']}x', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Text(prodName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                Text(
                                  '₺${((item['unit_price'] ?? 0) * (item['quantity'] ?? 1)).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    _buildPaymentSummary(),
                  ],
                ),
    );
  }

  Widget _buildPaymentSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GENEL TOPLAM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
              Text(
                '₺${_activeOrder!['total_amount']?.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text('ÖDEMEYİ AL VE MASAYI KAPAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
}
