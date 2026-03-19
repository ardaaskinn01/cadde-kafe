import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/auth_service.dart';
import '../../auth_wrapper.dart';
import '../../core/services/supabase_service.dart';

class CashierHomeView extends StatefulWidget {
  const CashierHomeView({Key? key}) : super(key: key);

  @override
  State<CashierHomeView> createState() => _CashierHomeViewState();
}

class _CashierHomeViewState extends State<CashierHomeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = SupabaseService.instance.client;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;
  
  String? _selectedTableId;
  Map<String, dynamic>? _selectedTableData;
  List<Map<String, dynamic>> _allTables = [];
  Map<String, dynamic>? _activeOrder;
  List<Map<String, dynamic>> _orderItems = [];
  
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  
  bool _isLoading = true;
  bool _isMenuLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInitialData();
    _setupRealtime();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _fetchInitialData();
    });
  }

  void _setupRealtime() {
    _realtimeChannel = _supabase.channel('public:cashier')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tables',
          callback: (payload) => _handleDataChange(),
        )
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
      _fetchTables();
      if (_selectedTableData != null) {
        _fetchOrderDetail(_selectedTableData!);
      }
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchTables(),
      _fetchMenuData(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchMenuData() async {
    try {
      final catsRes = await _supabase.from('categories').select().order('name');
      final prodsRes = await _supabase.from('products').select().order('name');
      
      setState(() {
        _categories = List<Map<String, dynamic>>.from(catsRes);
        _products = List<Map<String, dynamic>>.from(prodsRes);
      });
    } catch (e) {
      debugPrint('Menü verisi çekme hatası: $e');
    }
  }

  Future<void> _fetchTables() async {
    try {
      final response = await _supabase
          .from('tables')
          .select('*, orders(id, total_amount, status)')
          .order('name');
      
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
        _allTables = tables;
      });
    } catch (e) {
      debugPrint('Masa çekme hatası: $e');
    }
  }

  Future<void> _fetchOrderDetail(Map<String, dynamic> table) async {
    setState(() {
      _selectedTableId = table['id'];
      _selectedTableData = table;
      _activeOrder = null;
      _orderItems = [];
    });

    try {
      final orderRes = await _supabase
          .from('orders')
          .select('*, order_items(*, products(name))')
          .eq('table_id', table['id'])
          .inFilter('status', ['bekliyor', 'teslim_edildi'])
          .order('created_at', ascending: false)
          .limit(1);
      
      final List orderList = orderRes as List;
      if (orderList.isNotEmpty) {
        final order = Map<String, dynamic>.from(orderList.first);
        setState(() {
          _activeOrder = order;
          if (_activeOrder!['paid_amount'] == null) {
            _activeOrder!['paid_amount'] = 0.0;
          }
          _orderItems = List<Map<String, dynamic>>.from(order['order_items']);
        });
      }
    } catch (e) {
      debugPrint('Sipariş detayı hatası: $e');
    }
  }

  Future<void> _updateItemQuantity(Map<String, dynamic> item, int newQty) async {
    if (newQty < 0) return;
    
    try {
      if (newQty <= 0) {
        // Ürünü aktif adisyondan tamamen çıkar
        final response = await _supabase.from('order_items').delete().eq('id', item['id']).select();
        debugPrint('Silme yanıtı: $response');
      } else {
        // Adeti güncelle
        await _supabase.from('order_items').update({'quantity': newQty}).eq('id', item['id']);
      }

      // Sipariş toplamını yeniden hesapla
      double newTotal = 0;
      final currentItems = await _supabase.from('order_items').select().eq('order_id', _activeOrder!['id']);
      for (var i in currentItems) {
        newTotal += (i['quantity'] as int) * (i['unit_price'] as num).toDouble();
      }

      await _supabase.from('orders').update({'total_amount': newTotal}).eq('id', _activeOrder!['id']);
      
      // Eğer tüm ürünler silindiyse masayı kapat/iptal et
      await _checkOrderCompletion();

      // Veriyi tazele
      if (_selectedTableData != null) {
        _fetchOrderDetail(_selectedTableData!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _partialPayment(Map<String, dynamic> item, int payQty) async {
    try {
      double paymentAmount = payQty * (item['unit_price'] as num).toDouble();
      double currentPaid = (_activeOrder!['paid_amount'] as num? ?? 0).toDouble();
      
      // Ödenen adeti güncelle (Silme yapmıyoruz!)
      int currentPaidQty = (item['paid_quantity'] as int? ?? 0);
      await _supabase.from('order_items').update({
        'paid_quantity': currentPaidQty + payQty
      }).eq('id', item['id']);

      // Siparişin toplam ödenen miktarını arttır
      await _supabase.from('orders').update({
        'paid_amount': currentPaid + paymentAmount
      }).eq('id', _activeOrder!['id']);

      // Masa durumunu kontrol et
      await _checkOrderCompletion();
      
      if (_selectedTableData != null) {
        _fetchOrderDetail(_selectedTableData!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _checkOrderCompletion() async {
    // Tüm ürünlerin (quantity == paid_quantity) olup olmadığını kontrol et
    final allItemsRes = await _supabase.from('order_items').select().eq('order_id', _activeOrder!['id']);
    final allItems = List<Map<String, dynamic>>.from(allItemsRes);
    
    bool isComplete = allItems.isNotEmpty && allItems.every((item) {
      int q = item['quantity'] ?? 0;
      int p = item['paid_quantity'] ?? 0;
      return q <= p;
    });

    if (isComplete) {
      double paid = (_activeOrder!['paid_amount'] as num? ?? 0).toDouble();
      String finalStatus = paid > 0 ? 'odendi' : 'iptal';

      await _supabase.from('orders').update({'status': finalStatus}).eq('id', _activeOrder!['id']);
      await _supabase.from('tables').update({'status': 'available'}).eq('id', _selectedTableId!);
      _fetchInitialData();
      setState(() {
        _selectedTableId = null;
        _selectedTableData = null;
        _activeOrder = null;
      });
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
        await _supabase.from('orders').update({'status': 'odendi'}).eq('id', _activeOrder!['id']);
        await _supabase.from('tables').update({'status': 'available'}).eq('id', _selectedTableId!);
        
        await _fetchInitialData();
        setState(() {
          _selectedTableId = null;
          _selectedTableData = null;
          _activeOrder = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      } finally {
        setState(() => _isLoading = false);
      }
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
      body: Row(
        children: [
          // Sidebar (Sol Menü)
          _buildSidebar(),
          
          // Orta Panel (Masa Listesi)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                _buildHeader(),
                _buildTabSection(),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.brown))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTableGrid('A'),
                          _buildTableGrid('B'),
                          _buildActiveTablesGrid(),
                        ],
                      ),
                ),
              ],
            ),
          ),

          // Sağ Panel (Adisyon Detayı)
          _buildRightPanel(),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 100,
      color: Colors.brown.shade900,
      child: Column(
        children: [
          const SizedBox(height: 40),
          const CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 30,
            child: Icon(Icons.point_of_sale, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildSidebarButton(Icons.edit_note, 'Fiyat Değiştir', _showEditPricesDialog),
                _buildSidebarButton(Icons.add_shopping_cart, 'Ürün Ekle', _showAddProductDialog),
                _buildSidebarButton(Icons.remove_shopping_cart, 'Ürün Sil', _showDeleteProductDialog),
                _buildSidebarButton(Icons.category, 'Kategori Ekle', _showAddCategoryDialog),
                _buildSidebarButton(Icons.delete_sweep, 'Kategori Sil', _showDeleteCategoryDialog),
                _buildSidebarButton(Icons.lock, 'Ürün Kilitle', _showLockProductDialog),
                _buildSidebarButton(Icons.add_to_photos, 'Masa Ekle', _showAddTableDialog),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 30),
            onPressed: _logout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSidebarButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            Icon(icon, color: Colors.white70, size: 28),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // --- Kasa Menü Yönetimi Dialogları ---
  
  void _showEditPricesDialog() {
    final Map<String, TextEditingController> controllers = {};
    for (var prod in _products) {
      controllers[prod['id'].toString()] = TextEditingController(text: prod['price'].toString());
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ürün Fiyatlarını Güncelle', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 900,
            height: 600,
            child: _categories.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : DefaultTabController(
                  length: _categories.length,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: Colors.brown,
                        indicatorColor: Colors.brown,
                        tabs: _categories.map((c) => Tab(text: c['name'].toString().toUpperCase())).toList(),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: TabBarView(
                          children: _categories.map((cat) {
                            final catProds = _products.where((p) => p['category_id'] == cat['id']).toList();
                            return GridView.builder(
                              padding: const EdgeInsets.all(10),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 2.5,
                                crossAxisSpacing: 15,
                                mainAxisSpacing: 15,
                              ),
                              itemCount: catProds.length,
                              itemBuilder: (context, index) {
                                final prod = catProds[index];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 70,
                                        child: TextField(
                                          controller: controllers[prod['id'].toString()],
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            prefixText: '₺',
                                            isDense: true,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                try {
                  for (var prodId in controllers.keys) {
                    final newPrice = double.tryParse(controllers[prodId]!.text) ?? 0.0;
                    final oldPrice = _products.firstWhere((p) => p['id'].toString() == prodId)['price'];
                    if (newPrice != oldPrice) {
                      await _supabase.from('products').update({'price': newPrice}).eq('id', prodId);
                    }
                  }
                  await _fetchMenuData();
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiyatlar başarıyla güncellendi.')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Değişiklikleri Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    String? selectedCatId;
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Yeni Ürün Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCatId,
                items: _categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']))).toList(),
                onChanged: (val) => setDialogState(() => selectedCatId = val),
                decoration: InputDecoration(labelText: 'Kategori', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              ),
              const SizedBox(height: 15),
              TextField(controller: nameController, decoration: InputDecoration(labelText: 'Ürün İsmi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 15),
              TextField(controller: priceController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Fiyat (₺)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
            ElevatedButton(
              onPressed: () async {
                if (selectedCatId == null || nameController.text.isEmpty || priceController.text.isEmpty) return;
                try {
                  await _supabase.from('products').insert({
                    'name': nameController.text.trim(),
                    'price': double.parse(priceController.text),
                    'category_id': selectedCatId,
                    'is_available': true,
                  });
                  await _fetchMenuData();
                  if (mounted) Navigator.pop(context);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Ekle', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteProductDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ürün Sil', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 900,
            height: 600,
            child: _categories.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : DefaultTabController(
                  length: _categories.length,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: Colors.red,
                        indicatorColor: Colors.red,
                        tabs: _categories.map((c) => Tab(text: c['name'].toString().toUpperCase())).toList(),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: TabBarView(
                          children: _categories.map((cat) {
                            final catProds = _products.where((p) => p['category_id'] == cat['id']).toList();
                            return GridView.builder(
                              padding: const EdgeInsets.all(10),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: catProds.length,
                              itemBuilder: (context, index) {
                                final prod = catProds[index];
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text(prod['name'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                                      IconButton(
                                        icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                                        onPressed: () async {
                                          final confirm = await _showConfirmDialog('Ürünü Sil', '${prod['name']} silinecek. Emin misiniz?');
                                          if (confirm) {
                                            await _supabase.from('products').delete().eq('id', prod['id']);
                                            await _fetchMenuData();
                                            setDialogState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Yeni Kategori Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(controller: nameController, decoration: InputDecoration(labelText: 'Kategori İsmi', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              try {
                await _supabase.from('categories').insert({'name': nameController.text.trim()});
                await _fetchMenuData();
                if (mounted) Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Ekle', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Kategori Sil', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            height: 400,
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return ListTile(
                  title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final confirm = await _showConfirmDialog('Kategoriyi Sil', '${cat['name']} kategorisi ve içindeki ürünler silinebilir. Emin misiniz?');
                      if (confirm) {
                        await _supabase.from('categories').delete().eq('id', cat['id']);
                        await _fetchMenuData();
                        setDialogState(() {});
                      }
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  void _showLockProductDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Ürün Kilitle / Stok Kontrol', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 900,
            height: 600,
            child: _categories.isEmpty 
              ? const Center(child: CircularProgressIndicator())
              : DefaultTabController(
                  length: _categories.length,
                  child: Column(
                    children: [
                      TabBar(
                        isScrollable: true,
                        labelColor: Colors.orange,
                        indicatorColor: Colors.orange,
                        tabs: _categories.map((c) => Tab(text: c['name'].toString().toUpperCase())).toList(),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: TabBarView(
                          children: _categories.map((cat) {
                            final catProds = _products.where((p) => p['category_id'] == cat['id']).toList();
                            return GridView.builder(
                              padding: const EdgeInsets.all(10),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: catProds.length,
                              itemBuilder: (context, index) {
                                final prod = catProds[index];
                                final bool isAvailable = prod['is_available'] ?? true;
                                return InkWell(
                                  onTap: () async {
                                    await _supabase.from('products').update({'is_available': !isAvailable}).eq('id', prod['id']);
                                    await _fetchMenuData();
                                    setDialogState(() {});
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isAvailable ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isAvailable ? Colors.green.shade200 : Colors.red.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(child: Text(prod['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isAvailable ? Colors.green.shade900 : Colors.red.shade900))),
                                        Icon(isAvailable ? Icons.check_circle : Icons.lock, color: isAvailable ? Colors.green : Colors.red),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat', style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hayır')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Evet', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  void _showAddTableDialog() {
    String selectedSection = 'A';
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Yeni Masa Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedSection,
                decoration: InputDecoration(
                  labelText: 'Bölüm',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: ['A', 'B'].map((s) => DropdownMenuItem(value: s, child: Text('$s Bölümü'))).toList(),
                onChanged: (val) => setDialogState(() => selectedSection = val!),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Masa Numarası',
                  hintText: 'Örn: 18, 25',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final no = numberController.text.trim();
                if (no.isEmpty) return;
                
                final tableName = '$selectedSection$no';
                try {
                  // Mevcut masayı kontrol et (opsiyonel ama iyi olur)
                  final existing = await _supabase.from('tables').select().eq('name', tableName).maybeSingle();
                  if (existing != null) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu masa zaten mevcut!')));
                    return;
                  }

                  await _supabase.from('tables').insert({
                    'name': tableName,
                    'status': 'available',
                    'is_active': true
                  });
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$tableName başarıyla eklendi.')));
                    _fetchInitialData();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Masayı Oluştur', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KASA YÖNETİMİ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text('Aktif Masalar ve Ödemeler', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const Spacer(),
          _buildStatHeader('Toplam Masa', _allTables.length.toString(), Colors.blue),
          const SizedBox(width: 30),
          _buildStatHeader('Açık Adisyon', _allTables.where((t) => _isTableOccupied(t)).length.toString(), Colors.orange),
          const SizedBox(width: 20),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.brown),
            onPressed: _fetchInitialData,
            tooltip: 'Yenile',
          ),
        ],
      ),
    );
  }

  bool _isTableOccupied(Map<String, dynamic> table) {
    final bool hasOccupiedStatus = table['status'] == 'occupied';
    final orders = table['orders'] as List? ?? [];
    final bool hasActiveOrder = orders.any((o) => o['status'] == 'bekliyor');
    return hasOccupiedStatus || hasActiveOrder;
  }

  Widget _buildStatHeader(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  Widget _buildTabSection() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.brown,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.brown,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 30),
        indicatorWeight: 4,
        tabs: const [
          Tab(text: 'A BÖLÜMÜ'),
          Tab(text: 'B BÖLÜMÜ'),
          Tab(text: 'AÇIK ADİSYONLAR'),
        ],
      ),
    );
  }

  Widget _buildTableGrid(String section, {List<Map<String, dynamic>>? tableList}) {
    final tables = tableList ?? _allTables.where((t) => (t['name'] as String).startsWith(section)).toList();
    
    return GridView.builder(
      padding: const EdgeInsets.all(25),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.1,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final orders = table['orders'] as List? ?? [];
        final activeOrder = orders.isNotEmpty 
            ? orders.firstWhere((o) => o['status'] == 'bekliyor', orElse: () => null) 
            : null;
        
        final isOccupied = _isTableOccupied(table);
        final isSelected = _selectedTableId == table['id'];

        return InkWell(
          onTap: () => _fetchOrderDetail(table),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isOccupied ? (isSelected ? Colors.orange : Colors.orange.shade50) : (isSelected ? Colors.brown : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? Colors.transparent : Colors.grey.shade200,
                width: 2,
              ),
              boxShadow: isSelected 
                ? [BoxShadow(color: (isOccupied ? Colors.orange : Colors.brown).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]
                : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  table['name'],
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : (isOccupied ? Colors.orange.shade900 : Colors.black87),
                  ),
                ),
                if (isOccupied && activeOrder != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '₺${activeOrder['total_amount']}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                    ),
                  )
                ] else if (!isOccupied)
                  Text(
                    'BOŞ',
                    style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey.shade400, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveTablesGrid() {
    final activeTables = _allTables.where((t) => _isTableOccupied(t)).toList();
    if (activeTables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green.shade100),
            const SizedBox(height: 16),
            const Text('Şu an açık adisyon bulunmuyor.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return _buildTableGrid('', tableList: activeTables);
  }

  Widget _buildRightPanel() {
    return Container(
      width: 450,
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 30, offset: Offset(-10, 0))],
      ),
      child: _selectedTableData == null
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, size: 60, color: Colors.grey),
                SizedBox(height: 20),
                Text('Lütfen bir masa seçin', style: TextStyle(color: Colors.grey, fontSize: 16)),
              ],
            ),
          )
        : Column(
            children: [
              _buildRightPanelHeader(),
              Expanded(
                child: _activeOrder == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.table_restaurant, size: 60, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('Bu masa şu an boş.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _showAddItemsToOrderDialog,
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            label: const Text('Masayı Aç / Sipariş Gir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildOrderLists(),
              ),
              _buildPaymentFooter(),
            ],
          ),
    );
  }

  Widget _buildOrderLists() {
    List<Widget> unpaidWidgets = [];
    List<Widget> paidWidgets = [];

    for (var item in _orderItems) {
      int totalQty = item['quantity'] ?? 0;
      int paidQty = item['paid_quantity'] ?? 0;
      int unpaidQty = totalQty - paidQty;
      final prodName = item['products'] != null ? item['products']['name'] : 'Tanımsız Ürün';

      if (unpaidQty > 0) {
        unpaidWidgets.add(_buildOrderItem(item, prodName, unpaidQty, false));
      }
      if (paidQty > 0) {
        paidWidgets.add(_buildOrderItem(item, prodName, paidQty, true));
      }
    }

    return Column(
      children: [
        // SİPARİŞLER (Ödenmemiş)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 15, bottom: 5, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('AÇIK SİPARİŞLER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey.shade600)),
                    InkWell(
                      onTap: _showAddItemsToOrderDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.brown, borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                          children: [
                            Icon(Icons.add, size: 14, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Eksik Gir', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: unpaidWidgets.isEmpty 
                  ? const Center(child: Text('Açık sipariş yok', style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      children: unpaidWidgets,
                    ),
              ),
            ],
          ),
        ),
        
        // ÖDENENLER
        Container(height: 1, color: Colors.grey.shade200),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 15, bottom: 5),
                  child: Text('ÖDENENLER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green.shade700)),
                ),
                Expanded(
                  child: paidWidgets.isEmpty
                    ? Center(child: Text('Ödenmiş sipariş yok', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)))
                    : ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        children: paidWidgets,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.brown.shade50,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.brown,
            child: Text(_selectedTableData!['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 20),
          const Text('Adisyon Detayı', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item, String name, int displayQty, bool isPaid) {
    double price = (item['unit_price'] as num).toDouble();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isPaid ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPaid ? Colors.green.shade100 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: isPaid ? Colors.green.shade100 : Colors.brown.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('${displayQty}x', style: TextStyle(color: isPaid ? Colors.green.shade800 : Colors.brown, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('₺${price.toStringAsFixed(2)} / adet', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₺${(price * displayQty).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w900, color: isPaid ? Colors.green.shade700 : Colors.black87, fontSize: 14)),
                  if (isPaid) 
                    const Text('ÖDENDİ', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // İptal Butonu (Mistake prevention)
                _smallActionBtn(Icons.delete_outline, Colors.red, () => _updateItemQuantity(item, (item['quantity'] as int) - 1)),
                const SizedBox(width: 12),
                // Ödeme Butonu
                SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    onPressed: () => _partialPayment(item, 1),
                    icon: const Icon(Icons.check_circle_outline, size: 14),
                    label: Text(displayQty == 1 ? 'ÖDE' : '1 ADET ÖDE', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _smallActionBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildPaymentFooter() {
    if (_activeOrder == null) return const SizedBox();
    double total = (_activeOrder!['total_amount'] as num).toDouble();
    double paid = (_activeOrder!['paid_amount'] as num? ?? 0).toDouble();
    double remaining = total - paid;
    if (remaining < 0) remaining = 0;

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          _footerRow('TOPLAM TUTAR', '₺${total.toStringAsFixed(2)}', Colors.grey, 14),
          const SizedBox(height: 8),
          _footerRow('ÖDENEN', '₺${paid.toStringAsFixed(2)}', Colors.blue, 14),
          const Divider(height: 30),
          _footerRow('KALAN TUTAR', '₺${remaining.toStringAsFixed(2)}', Colors.green, 24),
          if (remaining <= 0) ...[
            const SizedBox(height: 25),
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
                child: const Text('MASAYI KAPAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _footerRow(String label, String value, Color valueColor, double valueSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.grey)),
        Text(value, style: TextStyle(fontSize: valueSize, fontWeight: FontWeight.w900, color: valueColor)),
      ],
    );
  }

  Future<void> _showPartialTotalPaymentDialog(double remaining) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kalan Ödeme'),
        content: Text('Kalan ₺${remaining.toStringAsFixed(2)} tutarın tamamı ödendi mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Evet, Ödendi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Kalanın hepsini öde ve kapat
      await _supabase.from('orders').update({
        'paid_amount': (_activeOrder!['total_amount'] as num).toDouble(),
        'status': 'odendi'
      }).eq('id', _activeOrder!['id']);
      await _supabase.from('tables').update({'status': 'available'}).eq('id', _selectedTableId!);
      _fetchInitialData();
      setState(() {
        _selectedTableId = null;
        _selectedTableData = null;
        _activeOrder = null;
      });
    }
  }

  void _showAddItemsToOrderDialog() {
    if (_selectedTableData == null) return;
    
    Map<String, int> cart = {};
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          int totalItems = cart.values.fold(0, (sum, val) => sum + val);

          Widget buildProductCard(Map<String, dynamic> prod) {
            final String prodId = prod['id'].toString();
            final int qty = cart[prodId] ?? 0;
            
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: qty > 0 ? Colors.orange.shade50 : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: qty > 0 ? Colors.orange.shade200 : Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                   const SizedBox(height: 4),
                   Text('₺${prod['price']}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                   const SizedBox(height: 8),
                   Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () {
                            if (qty > 0) {
                              setDialogState(() {
                                cart[prodId] = qty - 1;
                                if (cart[prodId] == 0) cart.remove(prodId);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
                            child: const Icon(Icons.remove, size: 16, color: Colors.brown),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(qty.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            if ((prod['price'] as num) <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Sıfır fiyatlı ürünü masaya ekleyemezsiniz. Lütfen önce menüden fiyatını güncelleyin.')),
                              );
                              return;
                            }
                            setDialogState(() {
                              cart[prodId] = qty + 1;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.brown, shape: BoxShape.circle),
                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                   ),
                ],
              ),
            );
          }
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_activeOrder == null ? 'Yeni Adisyon Aç' : 'Eksik Ürün Ekle', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (totalItems > 0)
                   Text('$totalItems Ürün', style: const TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
               width: 900,
               height: 600,
               child: _categories.isEmpty 
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Ürün Ara...',
                              prefixIcon: const Icon(Icons.search, color: Colors.brown),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Colors.brown),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (val) {
                              setDialogState(() {
                                searchQuery = val.trim();
                              });
                            },
                          ),
                        ),
                        Expanded(
                          child: searchQuery.isNotEmpty
                            ? GridView.builder(
                                padding: const EdgeInsets.all(10),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 2.2,
                                  crossAxisSpacing: 15,
                                  mainAxisSpacing: 15,
                                ),
                                itemCount: _products.where((p) => p['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) && p['is_available'] != false).length,
                                itemBuilder: (context, index) {
                                  final searchProds = _products.where((p) => p['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) && p['is_available'] != false).toList();
                                  return buildProductCard(searchProds[index]);
                                }
                              )
                            : DefaultTabController(
                                length: _categories.length,
                                child: Column(
                                  children: [
                                    TabBar(
                                      isScrollable: true,
                                      labelColor: Colors.brown,
                                      indicatorColor: Colors.brown,
                                      tabs: _categories.map((c) => Tab(text: c['name'].toString().toUpperCase())).toList(),
                                    ),
                                    const SizedBox(height: 15),
                                    Expanded(
                                      child: TabBarView(
                                        children: _categories.map((cat) {
                                          final catProds = _products.where((p) => p['category_id'] == cat['id'] && p['is_available'] != false).toList();
                                          return GridView.builder(
                                            padding: const EdgeInsets.all(10),
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 3,
                                              childAspectRatio: 2.2,
                                              crossAxisSpacing: 15,
                                              mainAxisSpacing: 15,
                                            ),
                                            itemCount: catProds.length,
                                            itemBuilder: (context, index) {
                                              return buildProductCard(catProds[index]);
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ]
                                )
                              )
                        )
                      ]
                    )
            ),
            actions: [
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal', style: TextStyle(color: Colors.grey))),
               ElevatedButton(
                  onPressed: cart.isEmpty ? null : () {
                    Navigator.pop(context);
                    _addItemsToOrder(cart);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Ürünleri Ekle', style: TextStyle(color: Colors.white)),
               )
            ]
          );
        }
      )
    );
  }

  Future<void> _addItemsToOrder(Map<String, int> cart) async {
    if (_selectedTableData == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = _supabase.auth.currentUser;
      final waiterId = user?.id;
      
      String orderId;
      double currentOrderTotal = 0.0;
      
      if (_activeOrder == null) {
        // Yeni Sipariş Aç (Kasa kendisi masa açıyor)
        final newOrder = await _supabase.from('orders').insert({
          'table_id': _selectedTableData!['id'],
          'waiter_id': waiterId,
          'total_amount': 0.0,
          'status': 'bekliyor'
        }).select().single();
        orderId = newOrder['id'];
        
        await _supabase.from('tables').update({'status': 'occupied'}).eq('id', _selectedTableData!['id']);
      } else {
        // Mevcut siparişe ekle
        orderId = _activeOrder!['id'];
        currentOrderTotal = (_activeOrder!['total_amount'] as num).toDouble();
      }
        
      double additionalAmount = 0;
      
      for(var entry in cart.entries) {
         final prodId = entry.key;
         final qty = entry.value;
         
         final prod = _products.firstWhere((p) => p['id'].toString() == prodId);
         final double unitPrice = (prod['price'] as num).toDouble();
         
         final existingItemRes = await _supabase.from('order_items')
            .select()
            .eq('order_id', orderId)
            .eq('product_id', prodId)
            .maybeSingle();
            
         if (existingItemRes != null) {
            final int currentQty = existingItemRes['quantity'] ?? 0;
            await _supabase.from('order_items').update({'quantity': currentQty + qty}).eq('id', existingItemRes['id']);
         } else {
            await _supabase.from('order_items').insert({
               'order_id': orderId,
               'product_id': prodId,
               'quantity': qty,
               'unit_price': unitPrice,
            });
         }
         additionalAmount += (unitPrice * qty);
      }
      
      final double newTotal = currentOrderTotal + additionalAmount;
      
      await _supabase.from('orders').update({
        'total_amount': newTotal,
        'status': 'bekliyor',
        if (waiterId != null) 'waiter_id': waiterId
      }).eq('id', orderId);
      
      await _fetchInitialData();
      if (_selectedTableData != null) {
         _fetchOrderDetail(_selectedTableData!);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Eksik ürünler başarıyla eklendi.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
