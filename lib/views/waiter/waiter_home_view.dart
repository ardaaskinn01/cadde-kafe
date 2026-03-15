import 'package:flutter/material.dart';
import 'open_table_tab.dart';
import 'active_tables_tab.dart';
import '../../core/services/auth_service.dart';
import '../../auth_wrapper.dart';
import '../../core/services/supabase_service.dart';

class WaiterHomeView extends StatefulWidget {
  const WaiterHomeView({Key? key}) : super(key: key);

  @override
  State<WaiterHomeView> createState() => _WaiterHomeViewState();
}

class _WaiterHomeViewState extends State<WaiterHomeView> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final _supabase = SupabaseService.instance.client;
  late TabController _tabController;
  String _waiterName = "Garson";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getCurrentProfile();
    if (profile != null && mounted) {
      setState(() {
        _waiterName = profile['full_name'] ?? "Garson";
      });
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış Yap'),
        content: const Text('Oturum kapatılacak. Emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkış Yap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await _authService.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthWrapper()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            elevation: 0,
            backgroundColor: Colors.brown.shade800,
            pinned: true,
            title: Text(
              _waiterName.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.white),
                onPressed: _logout,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.brown,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.brown,
                  indicatorWeight: 3,
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 40),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_box_outlined),
                          SizedBox(width: 8),
                          Text('Masa Aç', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined),
                          SizedBox(width: 8),
                          Text('Açık Masalar', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            OpenTableTab(),
            ActiveTablesTab(),
          ],
        ),
      ),
    );
  }
}
