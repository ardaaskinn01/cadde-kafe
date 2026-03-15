import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

class MenuManagementView extends StatefulWidget {
  const MenuManagementView({Key? key}) : super(key: key);

  @override
  State<MenuManagementView> createState() => _MenuManagementViewState();
}

class _MenuManagementViewState extends State<MenuManagementView> {
  final _supabase = SupabaseService.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final categoriesRes = await _supabase.from('categories').select().order('name');
      final productsRes = await _supabase.from('products').select().order('name');
      
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(categoriesRes);
          _products = List<Map<String, dynamic>>.from(productsRes);
        });
      }
    } catch (e) {
      debugPrint('Data fetch error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Veriler alınamadı: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Modern Dialog Helper
  void _showModernDialog({
    required String title,
    required Widget content,
    List<Widget>? actions,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
        content: content,
        actions: actions,
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // 9. Ürün Fiyat Değişimi
  void _showPriceChangeDialog() {
    Map<String, List<Map<String, dynamic>>> groupedProducts = {};
    for (var cat in _categories) {
      groupedProducts[cat['id']] = [];
    }
    for (var prod in _products) {
      if (groupedProducts.containsKey(prod['category_id'])) {
        groupedProducts[prod['category_id']]!.add(prod);
      }
    }

    Map<String, double> updatedPrices = {};

    _showModernDialog(
      title: 'Fiyat Güncelleme',
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 500,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Lütfen yeni fiyatları girip kaydedin.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final prodsInCat = groupedProducts[cat['id']] ?? [];
                  if (prodsInCat.isEmpty) return const SizedBox.shrink();
                  
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          cat['name'],
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...prodsInCat.map((prod) => Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Expanded(child: Text(prod['name'], style: const TextStyle(fontSize: 14))),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 100,
                              height: 45,
                              child: TextFormField(
                                initialValue: prod['price'].toString(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  prefixText: '₺',
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                                onChanged: (val) {
                                  if (val.isNotEmpty && double.tryParse(val) != null) {
                                    updatedPrices[prod['id']] = double.parse(val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        ElevatedButton(
          onPressed: () async {
            if (updatedPrices.isEmpty) {
              Navigator.pop(context);
              return;
            }
            try {
              for (var entry in updatedPrices.entries) {
                await _supabase.from('products').update({'price': entry.value}).eq('id', entry.key);
              }
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiyatlar başarıyla güncellendi.')));
                _fetchData();
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Güncelle'),
        ),
      ],
    );
  }

  // 10. Ürün Ekleme
  void _showAddProductDialog() {
    String? selectedCategoryId;
    String name = "";
    double? price;

    _showModernDialog(
      title: 'Yeni Ürün Ekle',
      content: StatefulBuilder(
        builder: (context, setDialogState) {
          return SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Kategori Seçin',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  value: selectedCategoryId,
                  items: _categories.map((c) => DropdownMenuItem<String>(value: c['id'], child: Text(c['name']))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCategoryId = val),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Ürün Adı',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => name = val,
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Birim Fiyat (₺)',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) => price = double.tryParse(val),
                ),
              ],
            ),
          );
        }
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: () async {
            if (selectedCategoryId == null || name.isEmpty || price == null) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen boş alan bırakmayın.')));
              return;
            }
            try {
              await _supabase.from('products').insert({
                'category_id': selectedCategoryId,
                'name': name,
                'price': price,
              });
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ürün başarıyla eklendi.')));
                _fetchData();
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }

  // 11. Ürün Silme
  void _showDeleteProductDialog() {
    _showModernDialog(
      title: 'Ürün Sil',
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 500,
        child: ListView.builder(
          itemCount: _products.length,
          itemBuilder: (context, index) {
            final prod = _products[index];
            return Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(prod['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('₺${prod['price']}', style: const TextStyle(color: Colors.brown)),
                trailing: Container(
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      bool confirm = await _showConfirmDialog(prod['name'], 'Bu ürünü silmek istediğinize emin misiniz?');
                      if (confirm && mounted) {
                        try {
                          await _supabase.from('products').delete().eq('id', prod['id']);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ürün silindi.')));
                          _fetchData();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent));
                        }
                      }
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }

  // 12. Kategori Ekleme
  void _showAddCategoryDialog() {
    String name = "";
    _showModernDialog(
      title: 'Yeni Kategori Ekle',
      content: TextField(
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Kategori Adı',
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (val) => name = val,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        ElevatedButton(
          onPressed: () async {
            if (name.trim().isEmpty) return;
            try {
              await _supabase.from('categories').insert({'name': name.trim()});
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori oluşturuldu.')));
                _fetchData();
              }
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent));
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Oluştur'),
        ),
      ],
    );
  }

  // 13. Kategori Silme
  void _showDeleteCategoryDialog() {
    _showModernDialog(
      title: 'Kategori Sil',
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 400,
        child: ListView.builder(
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return Card(
              elevation: 0,
              color: Colors.grey.shade50,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(cat['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                  onPressed: () async {
                    final prodsInCat = _products.where((p) => p['category_id'] == cat['id']).toList();
                    if (prodsInCat.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Bu kategoride ürünler var! Önce onları silmelisiniz.'), backgroundColor: Colors.orange),
                      );
                      return;
                    }

                    bool confirm = await _showConfirmDialog(cat['name'], 'Bu kategoriyi silmek istediğinize emin misiniz?');
                    if (confirm && mounted) {
                      try {
                        await _supabase.from('categories').delete().eq('id', cat['id']);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kategori silindi.')));
                        _fetchData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.redAccent));
                      }
                    }
                  },
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }

  // 14. Ürün Kilitle
  void _showToggleAvailabilityDialog() {
    _showModernDialog(
      title: 'Ürün Kilit Durumu',
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 500,
        child: Column(
          children: [
            const Text('Tükenen ürünlerin satışını buradan durdurun.', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final prod = _products[index];
                  bool isAvailable = prod['is_available'] ?? true;
                  return StatefulBuilder(
                    builder: (context, setStateItem) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: isAvailable ? Colors.white : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isAvailable ? Colors.grey.shade200 : Colors.red.shade100),
                        ),
                        child: ListTile(
                          title: Text(prod['name'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isAvailable ? null : TextDecoration.lineThrough)),
                          subtitle: Text(isAvailable ? 'Satışa Açık' : 'Kilitli / Tükendi', style: TextStyle(color: isAvailable ? Colors.green : Colors.red, fontSize: 12)),
                          trailing: Switch(
                            value: isAvailable,
                            activeColor: Colors.green,
                            onChanged: (val) async {
                              setStateItem(() => isAvailable = val);
                              try {
                                await _supabase.from('products').update({'is_available': val}).eq('id', prod['id']);
                                int pIndex = _products.indexWhere((p) => p['id'] == prod['id']);
                                if (pIndex != -1) _products[pIndex]['is_available'] = val;
                              } catch (e) {
                                setStateItem(() => isAvailable = !val);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu!')));
                              }
                            },
                          ),
                        ),
                      );
                    }
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
      ],
    );
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: const Text('MENÜ YÖNETİMİ', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Column(
                children: [
                  _buildMenuActionItem(
                    title: 'Fiyatları Güncelle',
                    subtitle: 'Tüm ürün fiyatlarını listeleyin',
                    icon: Icons.edit_note,
                    color: Colors.blue,
                    onTap: _showPriceChangeDialog,
                  ),
                  _buildMenuActionItem(
                    title: 'Yeni Ürün Ekle',
                    subtitle: 'Menüye yeni bir lezzet katın',
                    icon: Icons.add_circle_outline,
                    color: Colors.green,
                    onTap: _showAddProductDialog,
                  ),
                  _buildMenuActionItem(
                    title: 'Ürün Sil',
                    subtitle: 'Menüden ürün çıkarın',
                    icon: Icons.delete_outline,
                    color: Colors.red,
                    onTap: _showDeleteProductDialog,
                  ),
                  _buildMenuActionItem(
                    title: 'Kategori Ekle',
                    subtitle: 'Yeni bir ürün grubu oluşturun',
                    icon: Icons.grid_view_outlined,
                    color: Colors.orange,
                    onTap: _showAddCategoryDialog,
                  ),
                  _buildMenuActionItem(
                    title: 'Kategori Sil',
                    subtitle: 'Ürün gruplarını yönetin',
                    icon: Icons.folder_delete_outlined,
                    color: Colors.deepOrange,
                    onTap: _showDeleteCategoryDialog,
                  ),
                  _buildMenuActionItem(
                    title: 'Stok Kilitle',
                    subtitle: 'Tükenen ürünleri gizleyin',
                    icon: Icons.lock_outline,
                    color: Colors.deepPurple,
                    onTap: _showToggleAvailabilityDialog,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMenuActionItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}
