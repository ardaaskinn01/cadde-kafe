import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

class TableDetailView extends StatefulWidget {
  final String tableName;
  const TableDetailView({Key? key, required this.tableName}) : super(key: key);

  @override
  State<TableDetailView> createState() => _TableDetailViewState();
}

class _TableDetailViewState extends State<TableDetailView> with SingleTickerProviderStateMixin {
  final _supabase = SupabaseService.instance.client;
  late TabController _tabController;
  
  String? _selectedCategoryId;
  String _searchQuery = '';
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  Map<String, List<dynamic>> _cart = {}; // {productId: [qty, price, name]}
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchMenuData();
  }

  Future<void> _fetchMenuData() async {
    setState(() => _isLoading = true);
    try {
      final catResponse = await _supabase.from('categories').select().order('name');
      final prodResponse = await _supabase.from('products').select().eq('is_available', true).order('name');

      setState(() {
        _categories = [
          {'id': 'v_quick_add', 'name': 'HIZLI EKLE'}, // Sanal Kategori
          ...List<Map<String, dynamic>>.from(catResponse)
        ];
        _products = List<Map<String, dynamic>>.from(prodResponse);
        _selectedCategoryId = 'v_quick_add';
      });
    } catch (e) {
      debugPrint('Menü çekme hatası: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addToCart(String productId, String name, double price) {
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sıfır fiyatlı ürünü masaya ekleyemezsiniz. Lütfen fiyat belirlenmesi için kasaya başvurunuz.')),
      );
      return;
    }
    setState(() {
      if (_cart.containsKey(productId)) {
        _cart[productId]![0] += 1;
      } else {
        _cart[productId] = [1, price, name];
      }
    });
    // Haptic feedback veya küçük bir snackbar eklenebilir
  }

  void _removeFromCart(String productId) {
    setState(() {
      if (_cart.containsKey(productId)) {
        if (_cart[productId]![0] > 1) {
          _cart[productId]![0] -= 1;
        } else {
          _cart.remove(productId);
        }
      }
    });
  }

  double get _totalAmount {
    double total = 0;
    _cart.forEach((key, value) {
      total += (value[0] as int) * (value[1] as double);
    });
    return total;
  }

  Future<void> _submitOrder() async {
    if (_cart.isEmpty) return;
    
    setState(() => _isSaving = true);
    try {
      // 1. Masayı bul
      final tableRes = await _supabase.from('tables').select().eq('name', widget.tableName).single();
      final tableId = tableRes['id'];

      // 2. Aktif sipariş var mı bak (Sadece bekliyor değil; teslim_edildi de aktif sayılır)
      var orderRes = await _supabase
          .from('orders')
          .select()
          .eq('table_id', tableId)
          .inFilter('status', ['bekliyor', 'teslim_edildi'])
          .order('created_at', ascending: false)
          .limit(1);

      final List orderList = orderRes as List;
      String orderId;
      
      if (orderList.isEmpty) {
        // Hiç aktif sipariş yoksa yeni sipariş oluştur
        final newOrder = await _supabase.from('orders').insert({
          'table_id': tableId,
          'waiter_id': _supabase.auth.currentUser!.id,
          'total_amount': _totalAmount,
          'status': 'bekliyor'
        }).select().single();
        orderId = newOrder['id'];
        // Masayı dolu yap
        await _supabase.from('tables').update({'status': 'occupied'}).eq('id', tableId);
      } else {
        // Aktif sipariş bulundu, ona ekleme yapacağız
        final existingOrder = orderList.first;
        orderId = existingOrder['id'];
        
        // Mevcut sipariş tutarını güncelle ve durumu tekrar 'bekliyor' yap ki mutfak yeni ürünleri görsün
        await _supabase.from('orders').update({
          'total_amount': (existingOrder['total_amount'] as num) + _totalAmount,
          'status': 'bekliyor'
        }).eq('id', orderId);
      }
 
      // 3. Sipariş öğelerini ekle
      // Var olan ürünleri çektik ki mükerrer kayıt (çakışma) oluşmasın ve adetler düzgün artsın
      final existingItemsRes = await _supabase.from('order_items').select().eq('order_id', orderId);
      final List<Map<String, dynamic>> existingItems = List<Map<String, dynamic>>.from(existingItemsRes);
      
      List<Map<String, dynamic>> itemsToInsert = [];
      
      for (var entry in _cart.entries) {
        final prodId = entry.key;
        final details = entry.value;
        final qty = details[0] as int;
        final price = details[1];
        
        final existingMatch = existingItems.where((i) => i['product_id'] == prodId).toList();
        
        if (existingMatch.isNotEmpty) {
           // Ürün masada zaten var, adetini güncelle
           final itemToUpdate = existingMatch.first;
           final newQty = (itemToUpdate['quantity'] as int) + qty;
           await _supabase.from('order_items').update({'quantity': newQty}).eq('id', itemToUpdate['id']);
        } else {
           // Yeni eklenecek ürün
           itemsToInsert.add({
             'order_id': orderId,
             'product_id': prodId,
             'quantity': qty,
             'unit_price': price,
           });
        }
      }
 
      if (itemsToInsert.isNotEmpty) {
        await _supabase.from('order_items').insert(itemsToInsert);
      }

      // 4. Ürün satış sayılarını güncelle
      for (var prodId in _cart.keys) {
        final qty = _cart[prodId]![0];
        try {
          // Mevcut sayıyı çek ve arttır (Daha güvenli yol RPC'dir ancak hızlı çözüm budur)
          final prodRes = await _supabase.from('products').select('sales_count').eq('id', prodId).single();
          final currentCount = (prodRes['sales_count'] as int? ?? 0);
          await _supabase.from('products').update({
            'sales_count': currentCount + qty
          }).eq('id', prodId);
        } catch (e) {
          debugPrint('Satış sayısı güncellenemedi: $prodId');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sipariş başarıyla gönderildi!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Sipariş gönderme hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text('MASA ${widget.tableName}', 
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
            const Text('SİPARİŞ EKRANI', 
              style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
        bottom: _isDesktop(context) ? null : TabBar(
          controller: _tabController,
          labelColor: Colors.brown,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.brown,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'MENÜ'),
            Tab(text: 'SİPARİŞ'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.brown))
        : _isDesktop(context)
            ? Row(
                children: [
                  Expanded(flex: 2, child: _buildOrderMenu()),
                  Container(width: 1, color: Colors.grey.shade300),
                  Expanded(flex: 1, child: _buildCartView()),
                ],
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderMenu(),
                  _buildCartView(),
                ],
              ),
    );
  }

  bool _isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > 800;
  }

  Widget _buildOrderMenu() {
    List<Map<String, dynamic>> filteredProducts;
    if (_searchQuery.isNotEmpty) {
      filteredProducts = _products.where((p) => p['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_selectedCategoryId == 'v_quick_add') {
      // is_quick_add değeri true olanları filtrele
      filteredProducts = _products.where((p) => p['is_quick_add'] == true).toList();
    } else {
      filteredProducts = _products.where((p) => p['category_id'].toString() == _selectedCategoryId).toList();
    }

    return Column(
      children: [
        // Arama Çubuğu
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Ürün Ara...',
              prefixIcon: const Icon(Icons.search, color: Colors.brown),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.brown),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.trim();
              });
            },
          ),
        ),
        // Kategori Listesi
        if (_searchQuery.isEmpty)
          Container(
            height: 70,
            color: Colors.white,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategoryId == cat['id'].toString();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategoryId = cat['id'].toString()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.brown : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Center(
                      child: Text(
                        cat['name'].toString().toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black54,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Ürün Gridi
        Expanded(
          child: filteredProducts.isEmpty
            ? const Center(child: Text('Bu kategoride ürün bulunmuyor.'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _isDesktop(context) ? 4 : 2,
                  childAspectRatio: _isDesktop(context) ? 1.4 : 1.3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final p = filteredProducts[index];
                  final String prodId = p['id'].toString();
                  final int cartQty = _cart.containsKey(prodId) ? _cart[prodId]![0] : 0;

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _addToCart(prodId, p['name'], (p['price'] as num).toDouble()),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    p['name'], 
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₺${p['price']}', 
                                    style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (cartQty > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.brown.shade50,
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => _removeFromCart(prodId),
                                  child: const Icon(Icons.remove_circle, color: Colors.brown, size: 22),
                                ),
                                Text('$cartQty', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
                                GestureDetector(
                                  onTap: () => _addToCart(prodId, p['name'], (p['price'] as num).toDouble()),
                                  child: const Icon(Icons.add_circle, color: Colors.brown, size: 22),
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: ElevatedButton(
                              onPressed: () => _addToCart(prodId, p['name'], (p['price'] as num).toDouble()),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(32, 32),
                              ),
                              child: const Icon(Icons.add, size: 20),
                            ),
                          )
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildCartView() {
    return Column(
      children: [
        Expanded(
          child: _cart.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_basket_outlined, size: 100, color: Colors.grey.shade200),
                    const SizedBox(height: 16),
                    const Text('Sepetiniz boş.', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _cart.length,
                itemBuilder: (context, index) {
                  final id = _cart.keys.elementAt(index);
                  final item = _cart[id]!;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Text('${item[0]}x', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item[2], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('₺${item[1]} / adet', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('₺${(item[0] * item[1]).toStringAsFixed(2)}', 
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.brown)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => setState(() => _cart.remove(id)),
                          child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                        )
                      ],
                    ),
                  );
                },
              ),
        ),
        
        // Alt Panel (Özet ve Onay)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOPLAM TUTAR', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.grey)),
                    Text('₺${_totalAmount.toStringAsFixed(2)}', 
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.brown)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (_cart.isEmpty || _isSaving) ? null : _submitOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                      shadowColor: Colors.brown.withOpacity(0.5),
                    ),
                    child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SİPARİŞİ ONAYLA VE GÖNDER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        )
      ],
    );
  }
}
