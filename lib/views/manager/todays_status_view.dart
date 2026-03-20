import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';
import 'package:intl/intl.dart';

class TodaysStatusView extends StatefulWidget {
  const TodaysStatusView({Key? key}) : super(key: key);

  @override
  State<TodaysStatusView> createState() => _TodaysStatusViewState();
}

class _TodaysStatusViewState extends State<TodaysStatusView> {
  final _supabase = SupabaseService.instance.client;
  bool _isLoading = true;
  double _totalRevenue = 0.0;
  int _totalOrders = 0;
  List<Map<String, dynamic>> _todayTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchTodaysData();
  }

  Future<void> _fetchTodaysData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      DateTime businessStart = DateTime(now.year, now.month, now.day, 3, 0, 0);
      if (now.hour < 3) {
        businessStart = businessStart.subtract(const Duration(days: 1));
      }
      final todayStart = businessStart.toIso8601String();
      
      // Siparişleri çek (ilişkili tablo verileriyle birlikte)
      final response = await _supabase
          .from('orders')
          .select('*, tables(name), profiles(full_name), order_items(*, products(name))')
          .gte('created_at', todayStart)
          .inFilter('status', ['odendi'])
          .order('created_at', ascending: false);
          
      final expensesResponse = await _supabase
          .from('expenses')
          .select('*')
          .gte('created_at', todayStart)
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);
      final List<Map<String, dynamic>> expenses = List<Map<String, dynamic>>.from(expensesResponse);

      double revenue = 0.0;
      double totalExpense = 0.0;
      
      List<Map<String, dynamic>> transactions = [];

      for (var order in orders) {
        revenue += (order['total_amount'] ?? 0.0);
        order['type'] = 'order';
        transactions.add(order);
      }
      
      for (var expense in expenses) {
        totalExpense += (expense['amount'] ?? 0.0);
        expense['type'] = 'expense';
        transactions.add(expense);
      }
      
      // Tarihe göre sırala
      transactions.sort((a, b) {
        final dateA = DateTime.parse(a['created_at']);
        final dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      setState(() {
        _todayTransactions = transactions;
        _totalRevenue = revenue - totalExpense;
        _totalOrders = orders.length; // Toplam işlem sayısı yerine sipariş adedi kalabilir
      });
    } catch (e) {
      debugPrint('Error fetching todays data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.brown,
        title: const Text(
          'GÜNÜN ÖZETİ',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchTodaysData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
          : CustomScrollView(
              slivers: [
                // İstatistik Kartları Section
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Toplam Ciro',
                            '₺${_totalRevenue.toStringAsFixed(2)}',
                            Icons.payments_rounded,
                            Colors.green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatCard(
                            'Sipariş Adedi',
                            _totalOrders.toString(),
                            Icons.receipt_long_rounded,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Sipariş Geçmişi Başlığı
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Text(
                      'Bugünün İşlemleri',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),

                // Sipariş Listesi
                // Sipariş Listesi
                _todayTransactions.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Text('Bugün henüz işlem yapılmadı.'),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = _todayTransactions[index];
                              final isOrder = item['type'] == 'order';
                              final time = DateTime.parse(item['created_at']).toLocal();

                              if (!isOrder) {
                                final desc = item['description'] as String? ?? '';
                                final isDevir = desc.startsWith('🏦 Devir:');

                                // DEVİR veya GİDER ITEM'I
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDevir ? Colors.green.shade50 : Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        isDevir ? Icons.savings : Icons.money_off,
                                        color: isDevir ? Colors.green.shade700 : Colors.red.shade700,
                                      ),
                                    ),
                                    title: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            isDevir ? desc : 'Gider: $desc',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (!isDevir)
                                          Text('-₺${(item['amount'] ?? 0.0).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.red, fontSize: 16)),
                                      ],
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                                          const SizedBox(width: 4),
                                          Text(DateFormat('HH:mm').format(time), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }

                              // SİPARİŞ ITEM'I
                              final tableName = item['tables'] != null ? item['tables']['name'] : 'Masa';
                              final waiterName = item['profiles'] != null ? item['profiles']['full_name'] : 'Bilinmiyor';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.02),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ListTile(
                                  onTap: () => _showOrderDetails(context, item),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.brown.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.receipt_rounded, color: Colors.brown),
                                  ),
                                  title: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        tableName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      Text(
                                        '+₺${(item['total_amount'] ?? 0.0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.green,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.person, size: 14, color: Colors.grey.shade400),
                                          const SizedBox(width: 4),
                                          Text(waiterName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                          const SizedBox(width: 12),
                                          Icon(Icons.access_time, size: 14, color: Colors.grey.shade400),
                                          const SizedBox(width: 4),
                                          Text(
                                            DateFormat('HH:mm').format(time),
                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded, color: Colors.brown),
                                ),
                              );
                            },
                            childCount: _todayTransactions.length,
                          ),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
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
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$tableName DETAYI', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                        Text('Garson: $waiterName | Saat: ${DateFormat('HH:mm').format(time)}', 
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
            
            // Items List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final productName = item['products'] != null ? item['products']['name'] : 'Ürün';
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
                        Expanded(child: Text(productName, style: const TextStyle(fontWeight: FontWeight.bold))),
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
            
            // Footer
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

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
