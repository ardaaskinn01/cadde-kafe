import 'package:flutter/material.dart';
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
          _buildStatHeader('Açık Adisyon', _allTables.where((t) => t['status'] == 'occupied').length.toString(), Colors.orange),
        ],
      ),
    );
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

  Widget _buildTableGrid(String section) {
    final tables = _allTables.where((t) => (t['name'] as String).startsWith(section)).toList();
    
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
        final isOccupied = table['status'] == 'occupied';
        final isSelected = _selectedTableId == table['id'];
        
        final orders = table['orders'] as List;
        final activeOrder = orders.isNotEmpty ? orders.firstWhere((o) => (o['status'] == 'bekliyor' || o['status'] == null), orElse: () => null) : null;

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
    final activeTables = _allTables.where((t) => t['status'] == 'occupied').toList();
    if (activeTables.isEmpty) return const Center(child: Text('Açık adisyon bulunamadı.'));
    return _buildTableGrid(''); // Empty section filters nothing but we use our filtered list
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
                  ? const Center(child: Text('Bu masa şu an boş.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(25),
                      itemCount: _orderItems.length,
                      itemBuilder: (context, index) {
                        final item = _orderItems[index];
                        final prodName = item['products'] != null ? item['products']['name'] : 'Ürün';
                        return _buildOrderItem(prodName, item['quantity'], item['unit_price']);
                      },
                    ),
              ),
              _buildPaymentFooter(),
            ],
          ),
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
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildOrderItem(String name, int qty, dynamic price) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.brown.shade100, borderRadius: BorderRadius.circular(10)),
            child: Text('${qty}x', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold))),
          Text('₺${(price * qty).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPaymentFooter() {
    if (_activeOrder == null) return const SizedBox();
    return Container(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('GENEL TOPLAM', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.grey)),
              Text(
                '₺${_activeOrder!['total_amount']}',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 70,
            child: ElevatedButton(
              onPressed: _processPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 10,
                shadowColor: Colors.brown.withOpacity(0.5),
              ),
              child: const Text('ÖDEMEYİ AL VE MASAYI KAPAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
