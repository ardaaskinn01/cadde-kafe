import 'package:flutter/material.dart';

class WaiterActivityView extends StatefulWidget {
  const WaiterActivityView({Key? key}) : super(key: key);

  @override
  State<WaiterActivityView> createState() => _WaiterActivityViewState();
}

class _WaiterActivityViewState extends State<WaiterActivityView> {
  // Örnek Garson Listesi (İleride Supabase'den çekilecek)
  List<Map<String, dynamic>> _waiters = [
    {'id': '1', 'name': 'Ahmet', 'orders': 15, 'sales': 1250.0},
    {'id': '2', 'name': 'Mehmet', 'orders': 12, 'sales': 980.0},
    {'id': '3', 'name': 'Ayşe', 'orders': 18, 'sales': 1540.0},
  ];

  void _deleteWaiter(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Personeli Sil'),
        content: Text('$name isimli personeli sistemden silmek istediğinize emin misiniz?\n\nUyarı: Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Supabase üzerinden personeli (ve auth hesabını) silme işlemi yapılacak.
              setState(() {
                _waiters.removeWhere((w) => w['id'] == id);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$name başarıyla silindi.')),
              );
            },
            child: const Text('Evet, Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Garson Aktivite Takibi'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Garsonların Sipariş Performansı',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Siparişi giren personel üzerinden takip edilebilir ve sistemden silinebilir.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _waiters.isEmpty
                  ? const Center(child: Text('Kayıtlı garson bulunmuyor.'))
                  : ListView.builder(
                      itemCount: _waiters.length,
                      itemBuilder: (context, index) {
                        final waiter = _waiters[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(waiter['name']),
                            subtitle: Text('Bugün Toplam: ${waiter['orders']} Sipariş'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₺ ${waiter['sales']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteWaiter(waiter['id'], waiter['name']),
                                  tooltip: 'Personeli Sil',
                                ),
                              ],
                            ),
                            children: [
                              ListTile(
                                title: const Text('Son Siparişler'),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    Text('• Masa 4 - ₺ 120.00 (14:15)'),
                                    Text('• Masa 2 - ₺ 85.00 (13:50)'),
                                    Text('• Masa 7 - ₺ 210.00 (13:20)'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
