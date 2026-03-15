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
  List<Map<String, dynamic>> _todayOrders = [];

  @override
  void initState() {
    super.initState();
    _fetchTodaysData();
  }

  Future<void> _fetchTodaysData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0).toIso8601String();
      
      // Siparişleri çek (ilişkili tablo verileriyle birlikte)
      final response = await _supabase
          .from('orders')
          .select('*, tables(name), profiles(full_name)')
          .gte('created_at', todayStart)
          .order('created_at', ascending: false);
      
      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(response);

      double revenue = 0.0;
      for (var order in orders) {
        revenue += (order['total_amount'] ?? 0.0);
      }

      setState(() {
        _todayOrders = orders;
        _totalRevenue = revenue;
        _totalOrders = orders.length;
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
                _todayOrders.isEmpty
                    ? const SliverFillRemaining(
                        child: Center(
                          child: Text('Bugün henüz sipariş alınmadı.'),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final order = _todayOrders[index];
                              final time = DateTime.parse(order['created_at']).toLocal();
                              final tableName = order['tables'] != null ? order['tables']['name'] : 'Masa';
                              final waiterName = order['profiles'] != null ? order['profiles']['full_name'] : 'Bilinmiyor';

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
                                        '₺${(order['total_amount'] ?? 0.0).toStringAsFixed(2)}',
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
                                ),
                              );
                            },
                            childCount: _todayOrders.length,
                          ),
                        ),
                      ),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
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
