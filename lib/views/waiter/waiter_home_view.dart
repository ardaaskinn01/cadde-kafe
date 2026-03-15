import 'package:flutter/material.dart';
import 'open_table_tab.dart';
import 'active_tables_tab.dart';

class WaiterHomeView extends StatelessWidget {
  const WaiterHomeView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Garson Paneli'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Masa Aç'),
              Tab(text: 'Açık Masalar'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            // 1. Sekme: Masa Aç
            OpenTableTab(),
            // 2. Sekme: Açık Masalar
            ActiveTablesTab(),
          ],
        ),
      ),
    );
  }
}
