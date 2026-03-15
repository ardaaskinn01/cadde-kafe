import 'package:flutter/material.dart';

class TableDetailView extends StatefulWidget {
  final String tableName;
  const TableDetailView({Key? key, required this.tableName}) : super(key: key);

  @override
  State<TableDetailView> createState() => _TableDetailViewState();
}

class _TableDetailViewState extends State<TableDetailView> {
  // Örnek Kategori
  String? _selectedCategory;

  // Sahte Veriler (İleride Supabase'den gelecek)
  final categories = ['Sıcak İçecekler', 'Soğuk İçecekler', 'Tatlılar', 'Atıştırmalıklar'];
  final products = {
    'Sıcak İçecekler': [
      {'name': 'Çay', 'price': 15.0},
      {'name': 'Filtre Kahve', 'price': 60.0},
      {'name': 'Latte', 'price': 80.0},
    ],
    'Soğuk İçecekler': [
      {'name': 'Limonata', 'price': 50.0},
      {'name': 'Su', 'price': 10.0},
      {'name': 'Buzlu Kahve', 'price': 90.0},
    ]
  };

  // Sepet: \{Ürün Adı: [Miktar, Fiyat, KaydedilmişMi]\}
  // KaydedilmişMi = true ise önceden verilmiş aktif sipariş, false ise yeni eklenen
  final Map<String, List<dynamic>> _cart = {
    // Örnek olarak önceden sipariş edilmiş bir ürün:
    'Çay': [2, 15.0, true]
  };

  void _addToCart(String productName, double price) {
    setState(() {
      if (_cart.containsKey(productName)) {
        _cart[productName]![0] += 1;
      } else {
        _cart[productName] = [1, price, false];
      }
    });
  }

  void _removeFromCart(String productName) {
    setState(() {
      if (_cart.containsKey(productName)) {
        if (_cart[productName]![0] > 1) {
          _cart[productName]![0] -= 1;
        } else {
          _cart.remove(productName);
        }
      }
    });
  }

  // 6. Madde: Komple silme fonksiyonu (Tek seferde satırı siler)
  void _deleteItemCompletely(String productName) {
    setState(() {
      _cart.remove(productName);
    });
  }

  double get _totalAmount {
    double total = 0;
    _cart.forEach((key, value) {
      total += (value[0] as int) * (value[1] as double);
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    // Garsonlar telefon kullanacağı için yatay (Row) değil, Sekmeli (Tab) yapı kullanıyoruz.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Masa ${widget.tableName}'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Sipariş Ekle', icon: Icon(Icons.restaurant_menu)),
              Tab(text: 'Adisyon', icon: Icon(Icons.receipt_long)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // SEKME 1: ÜRÜN EKLEME (Telefon uyumlu - tam ekran)
            Column(
              children: [
                // Kategoriler (Yatay Kaydırılabilir)
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : null;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                
                // Ürünler Grid
                Expanded(
                  child: _selectedCategory == null || !products.containsKey(_selectedCategory)
                      ? const Center(child: Text('Lütfen bir kategori seçin'))
                      : GridView.builder(
                          padding: const EdgeInsets.all(8),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, // Telefonda 2 kolon gayet iyi
                            childAspectRatio: 1.2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: products[_selectedCategory]!.length,
                          itemBuilder: (context, index) {
                            final product = products[_selectedCategory]![index];
                            final name = product['name'] as String;
                            final price = product['price'] as double;

                            return Card(
                              elevation: 2,
                              color: Colors.brown.shade50,
                              child: InkWell(
                                onTap: () => _addToCart(name, price),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    Text('₺${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 16)),
                                    const SizedBox(height: 8),
                                    const Icon(Icons.add_circle, color: Colors.brown, size: 28),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),

            // SEKME 2: ADİSYON VE SEPET
            Column(
              children: [
                Expanded(
                  child: _cart.isEmpty
                      ? const Center(child: Text('Ekranda Kayıtlı / Yeni Sipariş Yok'))
                      : ListView.builder(
                          itemCount: _cart.keys.length,
                          itemBuilder: (context, index) {
                            final productName = _cart.keys.elementAt(index);
                            final qty = _cart[productName]![0] as int;
                            final price = _cart[productName]![1] as double;
                            final isSaved = _cart[productName]![2] as bool; // 6. Madde: Önceden gönderilmiş mi?

                            return Card(
                              color: isSaved ? Colors.grey.shade100 : Colors.green.shade50,
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: ListTile(
                                leading: Icon(
                                  isSaved ? Icons.check_circle : Icons.fiber_new,
                                  color: isSaved ? Colors.grey : Colors.green,
                                ),
                                title: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('Birim Fiyat: ₺${price.toStringAsFixed(2)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Adet Düşür
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                                      onPressed: () => _removeFromCart(productName),
                                    ),
                                    Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    // Adet Artır
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                      onPressed: () => _addToCart(productName, price),
                                    ),
                                    // Komple Sil
                                    IconButton(
                                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                                      onPressed: () => _deleteItemCompletely(productName),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                // Toplam Fiyat ve Kaydet Butonu
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Genel Toplam:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('₺${_totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _cart.isEmpty
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Siparişler Kaydedildi ve Mutfağa İletildi')),
                                  );
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.brown),
                          icon: const Icon(Icons.send, color: Colors.white),
                          label: const Text('Tümünü Kaydet ve Gönder', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
