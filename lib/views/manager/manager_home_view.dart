import 'package:flutter/material.dart';
import 'todays_status_view.dart';
import 'add_personnel_view.dart';
import 'history_view.dart';
import 'waiter_activity_view.dart';

class ManagerHomeView extends StatelessWidget {
  const ManagerHomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici Paneli'),
        centerTitle: true,
      ),
      // Drawer yok, her şey ana ekranda
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 2. Anlık durumu izleyebilmeli (Kasa ile aynı veya benzer görünüm)
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: const [
                    Text(
                      'Anlık Durum (Kasa Görünümü)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 10),
                    Text('Aktif Siparişler: 5'),
                    Text('Bekleyen Siparişler: 2'),
                    // Buraya ileride kasa ekranının içeriği widget olarak eklenebilir.
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // 3. Bugünkü durum (Sipariş geçmişi, ciro)
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TodaysStatusView()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              child: const Text(
                'Bugünün Durumu (Ciro ve Geçmiş)',
                style: TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 20),
            
            // 5. Seçimli (Günlük, Haftalık vb.) Geçmiş Sayfası
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryView()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.blueGrey.shade100,
              ),
              child: const Text('Geniş Kapsamlı Geçmiş / İstatistikler', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),

            // 7. Garson Aktivite Takibi
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WaiterActivityView()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.purple.shade50,
              ),
              child: const Text('Garsonlar / Aktivite Takibi', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),

            // 6. Personel Ekleme
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddPersonnelView()),
                );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: Colors.orange.shade100,
              ),
              child: const Text('Personel Ekle', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),

            // Ürün ve Menü Yönetimi
            ElevatedButton(
              onPressed: () {
                // TODO: Menü düzenleme ekranına git
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
              ),
              child: const Text('Ürün ve Menü Yönetimi', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
