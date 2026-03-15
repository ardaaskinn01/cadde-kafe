import 'package:flutter/material.dart';

class TodaysStatusView extends StatelessWidget {
  const TodaysStatusView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bugünün Durumu (Gece 3 Sıfırlamalı)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Toplam Ciro Kartı
            Card(
              elevation: 4,
              color: Colors.green.shade100,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Bugünün Cirosu:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '₺ 0.00',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Sipariş Geçmişi Başlığı
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bugünün Sipariş Geçmişi:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),
            
            // Sipariş Listesi (Geçici Olarak Boş Liste/Dummy Data)
            Expanded(
              child: ListView.builder(
                itemCount: 5, // Örnek sayı
                itemBuilder: (context, index) {
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.receipt)),
                      title: Text('Sipariş #${index + 1} - Masa ${(index % 5) + 1}'),
                      subtitle: const Text('Tamamlandı - Saat: 14:30'),
                      trailing: Text(
                        '₺ ${(index + 1) * 150}.00',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
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
