import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import 'package:intl/intl.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({Key? key}) : super(key: key);

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = SupabaseService.instance.client;
  
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();
  
  // İstatistik Verileri
  double _totalRevenue = 0.0;
  int _orderCount = 0;
  List<Map<String, dynamic>> _transactions = [];

  // Sabitler
  final List<String> _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  final List<int> _years = [2025, 2026]; // Gelecekte buraya yeni yıllar eklenebilir

  @override
  void initState() {
    super.initState();
    // Haftalık kaldırıldığı için 3 sekmeye düşürüyoruz
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _fetchData();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) {
      _fetchData();
    }
  }

  DateTime _getBusinessDate(DateTime date) {
    if (date.hour < 3) {
      return date.subtract(const Duration(days: 1));
    }
    return date;
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      DateTime start;
      DateTime end;

      switch (_tabController.index) {
        case 0: // Günlük
          start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 3, 0, 0);
          end = start.add(const Duration(days: 1));
          break;
        case 1: // Aylık
          start = DateTime(_selectedDate.year, _selectedDate.month, 1, 3, 0, 0);
          end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1, 3, 0, 0);
          break;
        case 2: // Yıllık
          start = DateTime(_selectedDate.year, 1, 1, 3, 0, 0);
          end = DateTime(_selectedDate.year + 1, 1, 1, 3, 0, 0);
          break;
        default:
          start = DateTime.now();
          end = DateTime.now();
      }

      final response = await _supabase
          .from('orders')
          .select('*, tables(name), profiles(full_name), order_items(*, products(name))')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .inFilter('status', ['odendi'])
          .order('created_at', ascending: false);

      final expensesResponse = await _supabase
          .from('expenses')
          .select('*')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String())
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> fetchedOrders = List<Map<String, dynamic>>.from(response);
      final List<Map<String, dynamic>> fetchedExpenses = List<Map<String, dynamic>>.from(expensesResponse);
      
      double revenue = 0;
      double totalExpense = 0;
      List<Map<String, dynamic>> mergedList = [];

      for (var o in fetchedOrders) {
        revenue += (o['total_amount'] ?? 0.0);
        o['type'] = 'order';
        mergedList.add(o);
      }
      
      for (var e in fetchedExpenses) {
        totalExpense += (e['amount'] ?? 0.0);
        e['type'] = 'expense';
        mergedList.add(e);
      }
      
      mergedList.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA); // Yeniden eskiye
      });

      if (mounted) {
        setState(() {
          _transactions = mergedList;
          _totalRevenue = revenue - totalExpense;
          _orderCount = fetchedOrders.length;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.brown),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchData();
    }
  }

  void _showMonthYearPicker() {
    int tempMonth = _selectedDate.month;
    int tempYear = _selectedDate.year;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Ay ve Yıl Seçin'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: tempMonth,
                  decoration: const InputDecoration(labelText: 'Ay'),
                  items: List.generate(12, (index) => DropdownMenuItem(
                    value: index + 1,
                    child: Text(_months[index]),
                  )),
                  onChanged: (val) => setDialogState(() => tempMonth = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: tempYear,
                  decoration: const InputDecoration(labelText: 'Yıl'),
                  items: _years.map((y) => DropdownMenuItem(
                    value: y,
                    child: Text(y.toString()),
                  )).toList(),
                  onChanged: (val) => setDialogState(() => tempYear = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(tempYear, tempMonth, 1);
                  });
                  Navigator.pop(context);
                  _fetchData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                child: const Text('Seç'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showYearPicker() {
    int tempYear = _selectedDate.year;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Yıl Seçin'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: DropdownButtonFormField<int>(
              value: tempYear,
              decoration: const InputDecoration(labelText: 'Yıl'),
              items: _years.map((y) => DropdownMenuItem(
                value: y,
                child: Text(y.toString()),
              )).toList(),
              onChanged: (val) => setDialogState(() => tempYear = val!),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime(tempYear, 1, 1);
                  });
                  Navigator.pop(context);
                  _fetchData();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white),
                child: const Text('Seç'),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        title: const Text('İSTATİSTİKLER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.brown,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.brown,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: "GÜN"),
            Tab(text: "AY"),
            Tab(text: "YIL"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter & Summary Header
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getPeriodLabel(),
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFormattedDate(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () {
                        if (_tabController.index == 0) {
                          _pickDate();
                        } else if (_tabController.index == 1) {
                          _showMonthYearPicker();
                        } else {
                          _showYearPicker();
                        }
                      },
                      icon: const Icon(Icons.settings_suggest_rounded, color: Colors.brown, size: 28),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildQuickStat('Toplam Ciro', '₺${_totalRevenue.toStringAsFixed(2)}', Colors.green),
                    const SizedBox(width: 12),
                    _buildQuickStat('İşlem Sayısı', '$_orderCount', Colors.blue),
                  ],
                ),
              ],
            ),
          ),
          
          // List Section
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.brown))
              : _transactions.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final item = _transactions[index];
                      return _buildTransactionCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> item) {
    if (item['type'] == 'expense') {
      return _buildExpenseCard(item);
    }
    return _buildOrderCard(item);
  }

  Widget _buildExpenseCard(Map<String, dynamic> expense) {
    final time = DateTime.parse(expense['created_at']).toLocal();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.money_off, color: Colors.red.shade700, size: 20),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gider: ${expense['description']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(
                  DateFormat('dd/MM/yyyy HH:mm').format(time),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '-₺${(expense['amount'] ?? 0.0).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final time = DateTime.parse(order['created_at']).toLocal();
    final tableName = order['tables'] != null ? order['tables']['name'] : 'Masa';
    
    return InkWell(
      onTap: () => _showOrderDetails(context, order),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.receipt_rounded, color: Colors.brown, size: 20),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tableName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(time),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              '+₺${(order['total_amount'] ?? 0.0).toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.brown),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Map<String, dynamic> order) {
    final items = order['order_items'] as List? ?? [];
    final time = DateTime.parse(order['created_at']).toLocal();
    final tableName = order['tables'] != null ? order['tables']['name'] : 'Masa';
    final waiterName = order['profiles'] != null ? order['profiles']['full_name'] : 'Bilinmiyor';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$tableName DETAYI', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                        Text('Garson: $waiterName | Tarih: ${DateFormat('dd/MM/yyyy HH:mm').format(time)}', 
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
            ),
            const Divider(height: 40),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final prodName = item['products'] != null ? item['products']['name'] : 'Tanımsız Ürün';
                  final qty = item['quantity'] ?? 1;
                  final price = (item['unit_price'] ?? 0.0).toDouble();

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.brown.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Text('${qty}x', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Text(prodName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₺${(price * qty).toStringAsFixed(2)}', 
                              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.brown)),
                            Text('₺$price / adet', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOPLAM TUTAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    Text('₺${(order['total_amount'] ?? 0.0).toStringAsFixed(2)}', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Colors.green)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Bu dönemde kayıt bulunamadı.', style: TextStyle(color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  String _getPeriodLabel() {
    switch (_tabController.index) {
      case 0: return 'GÜNLÜK RAPOR';
      case 1: return 'AYLIK RAPOR';
      case 2: return 'YILLIK RAPOR';
      default: return 'RAPOR';
    }
  }

  String _getFormattedDate() {
    switch (_tabController.index) {
      case 0: return DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate);
      case 1: return DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
      case 2: return _selectedDate.year.toString();
      default: return '';
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }
}
