import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../auth_wrapper.dart';
import '../../core/services/supabase_service.dart';
import 'todays_status_view.dart';
import 'add_personnel_view.dart';
import 'history_view.dart';
import 'waiter_activity_view.dart';
import 'manager_cashier_view.dart';
import 'menu_management_view.dart';

class ManagerHomeView extends StatefulWidget {
  const ManagerHomeView({Key? key}) : super(key: key);

  @override
  State<ManagerHomeView> createState() => _ManagerHomeViewState();
}

class _ManagerHomeViewState extends State<ManagerHomeView> {
  final AuthService _authService = AuthService();
  final _supabase = SupabaseService.instance.client;
  
  String _managerName = "Yönetici";
  String _activeTablesCount = "-";
  String _todayRevenue = "-";
  String _personnelCount = "-";

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProfile(),
      _loadStats(),
    ]);
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getCurrentProfile();
    if (profile != null && mounted) {
      setState(() {
        _managerName = profile['full_name'] ?? "Yönetici";
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();

      // 1. Aktif Masalar (Occupied olanlar)
      final tablesResponse = await _supabase
          .from('tables')
          .select('id')
          .eq('status', 'occupied');
      
      // 2. Günün Siparişleri
      final ordersResponse = await _supabase
          .from('orders')
          .select('total_amount, status')
          .gte('created_at', todayStart)
          .inFilter('status', ['odendi']); // Sadece ödenmişleri cirodan sayalım (veya hepsini? Önceden hepsiydi ama ödenenler gelmeli. Veya iptalleri düşebiliriz. Mevcut hali korumak için filtersiz mi çeksek? Biz tüm ciroyu alıyorduk. İptalleri çıkartalım).
          
      // 3. Günün Giderleri
      final expensesResponse = await _supabase
          .from('expenses')
          .select('amount')
          .gte('created_at', todayStart);

      // 3. Personel Sayısı (Sadece garsonlar)
      final personnelResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'garson');

      if (!mounted) return;

      double revenue = 0;
      final List ordersList = ordersResponse as List;
      for (var o in ordersList) {
        if (o['status'] != 'iptal') { // İptal olanları cirodan saymıyoruz
          revenue += (o['total_amount'] ?? 0.0);
        }
      }

      double totalExpense = 0;
      final List expensesList = expensesResponse as List;
      for (var e in expensesList) {
        totalExpense += (e['amount'] ?? 0.0);
      }

      final double netRevenue = revenue - totalExpense;

      setState(() {
        _activeTablesCount = (tablesResponse as List).length.toString();
        _todayRevenue = '₺${netRevenue.toStringAsFixed(0)}';
        _personnelCount = (personnelResponse as List).length.toString();
      });
    } catch (e) {
      debugPrint('Stat yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _activeTablesCount = "0";
          _todayRevenue = "₺0";
          _personnelCount = "0";
        });
      }
    }
  }

  void _logout() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        title: const Text(
          'YÖNETİCİ PANELİ',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Verileri Yenile',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutDialog(context),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(context),
        backgroundColor: Colors.red.shade700,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'Gider Ekle',
      ),
      body: CustomScrollView(
        slivers: [
          // Header Section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.brown.shade800,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merhaba,',
                            style: TextStyle(color: Colors.brown.shade100, fontSize: 16),
                          ),
                          Text(
                            _managerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Aktif Masalar', _activeTablesCount, Icons.table_restaurant),
                        _buildStatItem('Günün Cirosu', _todayRevenue, Icons.payments),
                        _buildStatItem('Personel', _personnelCount, Icons.people),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Menu Grid
          SliverPadding(
            padding: const EdgeInsets.all(20.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildListDelegate([
                _buildMenuCard(
                  context,
                  title: 'Kasa İşlevleri',
                  subtitle: 'Masa & Adisyon',
                  icon: Icons.point_of_sale,
                  color: Colors.brown.shade800,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ManagerCashierView()));
                    _loadStats();
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'Günün Özeti',
                  subtitle: 'Satış & Detaylar',
                  icon: Icons.today,
                  color: Colors.brown.shade800,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const TodaysStatusView()));
                    _loadStats();
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'Garsonlar',
                  subtitle: 'Aktivite Takibi',
                  icon: Icons.person_search,
                  color: Colors.brown.shade800,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const WaiterActivityView()));
                    _loadStats();
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'Geçmiş Kayıtlar',
                  subtitle: 'Tüm İstatistikler',
                  icon: Icons.history,
                  color: Colors.brown.shade800,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryView())),
                ),
                _buildMenuCard(
                  context,
                  title: 'Personel Yönetimi',
                  subtitle: 'Yeni Kayıt & Yetki',
                  icon: Icons.group_add,
                  color: Colors.brown.shade800,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddPersonnelView()));
                    _loadStats();
                  },
                ),
                _buildMenuCard(
                  context,
                  title: 'Menü Yönetimi',
                  subtitle: 'Ürün & Fiyatlar',
                  icon: Icons.restaurant_menu,
                  color: Colors.brown.shade800,
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const MenuManagementView()));
                    _loadStats();
                  },
                ),
              ]),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.brown.shade100, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.brown.shade200, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturumun kapatılacak. Emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Diyalogu kapat
              _logout(); // Çıkış işlemini başlat
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final TextEditingController descController = TextEditingController();
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gider Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Açıklama (Örn: Manav, Temizlik)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Miktar (₺)', prefixText: '₺ '),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (descController.text.trim().isEmpty || amountController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen tüm alanları doldurun.')));
                return;
              }
              final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir miktar girin.')));
                return;
              }

              Navigator.pop(context); // Dialogu kapat

              // Veritabanına kaydet
              try {
                await _supabase.from('expenses').insert({
                  'description': descController.text.trim(),
                  'amount': amount,
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gider başarıyla eklendi', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green));
                }
                _loadStats(); // Ana sayfayı güncelle
              } catch (e) {
                debugPrint('Gider ekleme hatası: $e');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gider eklenirken hata: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            child: const Text('Gideri Ekle'),
          ),
        ],
      ),
    );
  }
}
