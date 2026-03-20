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
  String _kasaAmount = "-";
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
      // 1. Aktif Masalar (Occupied olanlar)
      final tablesResponse = await _supabase
          .from('tables')
          .select('id')
          .eq('status', 'occupied');
      
      // 2. Personel Sayısı (Sadece garsonlar)
      final personnelResponse = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'garson');

      // 3. Son Devir kaydını çek
      final devirResponse = await _supabase
          .from('devirler')
          .select()
          .order('created_at', ascending: false)
          .limit(1);
      
      final List devirList = devirResponse as List;
      
      double kasa = 0.0;
      
      if (devirList.isNotEmpty) {
        // Son devir var: kasaya o devir miktarından başla
        final lastDevir = devirList.first;
        kasa = (lastDevir['amount'] as num).toDouble();
        final devirTime = lastDevir['created_at'] as String;
        
        // Devir sonrasında ödenen siparişleri topla (kasa artışı)
        final paidAfterDevir = await _supabase
            .from('orders')
            .select('total_amount')
            .eq('status', 'odendi')
            .gte('created_at', devirTime);
        for (var o in (paidAfterDevir as List)) {
          kasa += (o['total_amount'] as num? ?? 0).toDouble();
        }
        
        // Devir sonrasındaki giderleri düş
        final expAfterDevir = await _supabase
            .from('expenses')
            .select('amount')
            .gte('created_at', devirTime);
        for (var e in (expAfterDevir as List)) {
          kasa -= (e['amount'] as num? ?? 0).toDouble();
        }
      } else {
        // Hiç devir yok: bugünün (03:00 baz) ödenen siparişleri say
        final now = DateTime.now();
        DateTime businessStart = DateTime(now.year, now.month, now.day, 3, 0, 0);
        if (now.hour < 3) businessStart = businessStart.subtract(const Duration(days: 1));
        final todayStart = businessStart.toIso8601String();
        
        final ordersRes = await _supabase
            .from('orders')
            .select('total_amount')
            .eq('status', 'odendi')
            .gte('created_at', todayStart);
        for (var o in (ordersRes as List)) {
          kasa += (o['total_amount'] as num? ?? 0).toDouble();
        }
        final expRes = await _supabase
            .from('expenses')
            .select('amount')
            .gte('created_at', todayStart);
        for (var e in (expRes as List)) {
          kasa -= (e['amount'] as num? ?? 0).toDouble();
        }
      }

      if (!mounted) return;

      setState(() {
        _activeTablesCount = (tablesResponse as List).length.toString();
        _kasaAmount = '₺${kasa.toStringAsFixed(0)}';
        _personnelCount = (personnelResponse as List).length.toString();
      });
    } catch (e) {
      debugPrint('Stat yükleme hatası: $e');
      if (mounted) {
        setState(() {
          _activeTablesCount = "0";
          _kasaAmount = "₺0";
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
        onPressed: () => _showActionMenu(context),
        backgroundColor: Colors.brown.shade800,
        child: const Icon(Icons.add, color: Colors.white),
        tooltip: 'İşlem Ekle',
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
                        _buildStatItem('Kasa', _kasaAmount, Icons.account_balance_wallet),
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

  void _showActionMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.money_off, color: Colors.red.shade700),
                ),
                title: const Text('Gider Ekle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Kasa çıkışı olarak kaydet'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddExpenseDialog(context);
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.savings, color: Colors.green.shade700),
                ),
                title: const Text('Devir Gir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Kasada bırakılan parayı kaydet (gün sonu)'),
                onTap: () {
                  Navigator.pop(context);
                  _showDevirDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDevirDialog(BuildContext context) {
    final TextEditingController amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Devir Gir', style: TextStyle(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.green.shade700, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Kasada bırakacağınız miktarı girin. Bu miktar yarın "Kasa" olarak görünecek.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Kasada Bırakılan Miktar (₺)',
                prefixText: '₺ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton.icon(
            icon: const Icon(Icons.savings),
            onPressed: () async {
              final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
              if (amount == null || amount < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir miktar girin.')));
                return;
              }

              Navigator.pop(context);

              try {
                // Devir tablosuna kaydet
                await _supabase.from('devirler').insert({
                  'amount': amount,
                  'description': 'Kasada ₺${amount.toStringAsFixed(0)} para bırakıldı',
                });
                // Günün özeti için expenses tablosuna da not düş (negatif değil, sadece log)
                await _supabase.from('expenses').insert({
                  'description': '🏦 Devir: Kasada ₺${amount.toStringAsFixed(0)} para bırakıldı',
                  'amount': 0, // Gider sayılmasın, sadece kayıt
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Devir kaydedildi! Kasada ₺${amount.toStringAsFixed(0)} bırakıldı.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadStats(); // Kasa değerini güncelle
                }
              } catch (e) {
                debugPrint('Devir kayıt hatası: $e');
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
            label: const Text('Deviri Kaydet'),
          ),
        ],
      ),
    );
  }
}
