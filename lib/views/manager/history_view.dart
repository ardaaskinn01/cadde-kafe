import 'package:flutter/material.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({Key? key}) : super(key: key);

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Örnek Seçimler
  DateTime _selectedDate = DateTime.now();
  String _selectedWeek = "Bu Hafta";
  String _selectedMonth = "Ocak 2026";
  String _selectedYear = "2026";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  void _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      // TODO: Firebase/Supabase'den seçilen tarihe göre verileri yükle
    }
  }

  Widget _buildDailyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Seçili Gün: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}"),
              ElevatedButton(
                onPressed: () => _pickDate(context),
                child: const Text('Gün Seç'),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('Günlük İstatistikler / Ciro / Satış Listesi'),
          ),
        )
      ],
    );
  }

  Widget _buildWeeklyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Seçili: $_selectedWeek"),
              ElevatedButton(
                onPressed: () {
                  // TODO: Hafta seçici dialog veya dropdown
                },
                child: const Text('Hafta Seç'),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('Haftalık İstatistikler ve Toplam Ciro'),
          ),
        )
      ],
    );
  }

  Widget _buildMonthlyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Seçili Ay: $_selectedMonth"),
              ElevatedButton(
                onPressed: () {
                  // TODO: Ay seçici dialog eklenecek
                },
                child: const Text('Ay Seç'),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('Aylık Toplam Ciro Grafiği'),
          ),
        )
      ],
    );
  }

  Widget _buildYearlyTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Seçili Yıl: $_selectedYear"),
              ElevatedButton(
                onPressed: () {
                  // TODO: Yıl seçicisi eklenecek
                },
                child: const Text('Yıl Seç'),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('Yıllık Karşılaştırmalı Ciro Dağılımı'),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geçmiş İstatistikler'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Günlük"),
            Tab(text: "Haftalık"),
            Tab(text: "Aylık"),
            Tab(text: "Yıllık"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDailyTab(),
          _buildWeeklyTab(),
          _buildMonthlyTab(),
          _buildYearlyTab(),
        ],
      ),
    );
  }
}
