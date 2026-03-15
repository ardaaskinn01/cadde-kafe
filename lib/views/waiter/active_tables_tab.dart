import 'package:flutter/material.dart';
import 'table_detail_view.dart';

class ActiveTablesTab extends StatelessWidget {
  const ActiveTablesTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Burada Supabase'den çekilen durumu "bekliyor" veya "hazırlanıyor" olan
    // aktif (içinde sipariş olan) masalar listelenecek.
    final fakeActiveTables = ['A3', 'B12', 'B22']; // Örnek

    return ListView.builder(
      itemCount: fakeActiveTables.length,
      itemBuilder: (context, index) {
        final tableName = fakeActiveTables[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.table_restaurant, color: Colors.white),
            ),
            title: Text('Masa $tableName', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Aktif Sipariş Var - Bekliyor'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TableDetailView(tableName: tableName),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
