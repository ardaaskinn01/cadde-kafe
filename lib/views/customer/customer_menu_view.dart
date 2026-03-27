import 'package:flutter/material.dart';
import '../../core/services/supabase_service.dart';

class CustomerMenuView extends StatefulWidget {
  const CustomerMenuView({Key? key}) : super(key: key);

  @override
  State<CustomerMenuView> createState() => _CustomerMenuViewState();
}

class _CustomerMenuViewState extends State<CustomerMenuView> {
  final _supabase = SupabaseService.instance.client;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _products = [];
  String _selectedCategoryId = '';

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    try {
      final catRes = await _supabase
          .from('categories')
          .select()
          .order('name');
      final prodRes = await _supabase
          .from('products')
          .select()
          .eq('is_available', true)
          .gt('price', 0)
          .order('name');

      if (mounted) {
        final cats = List<Map<String, dynamic>>.from(catRes);
        final prods = List<Map<String, dynamic>>.from(prodRes);
        setState(() {
          _categories = cats;
          _products = prods;
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories.first['id'].toString();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching menu: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Menü yüklenirken bir hata oluştu. Lütfen tekrar deneyin.';
        });
      }
    }
  }

  String _toTurkishUpper(String text) {
    return text
        .replaceAll('i', 'İ')
        .replaceAll('ı', 'I')
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2C1E16))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 64, color: Color(0xFF2C1E16)),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() { _isLoading = true; _errorMessage = null; });
                  _fetchMenu();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C1E16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Tekrar Dene', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    // Fırsat kategorisi tespiti - Türkçe büyük/küçük harf sorunlarını bypass etmek için
    // DB'de 'FIRSAT ÜRÜN' olarak kayıtlı. replaceAll ile I/İ farkını gidirip arıyoruz.
    bool _isFirsatCategory(Map<String, dynamic>? cat) {
      if (cat == null) return false;
      // Kategorinin adındaki tüm büyük-küçük harf varyasyonlarını normalize ediyoruz
      final normalized = cat['name']
          .toString()
          .replaceAll('I', 'i').replaceAll('İ', 'i')
          .replaceAll('ı', 'i').replaceAll('Ğ', 'ğ')
          .replaceAll('Ü', 'ü').replaceAll('Ş', 'ş')
          .replaceAll('Ö', 'ö').replaceAll('Ç', 'ç')
          .toLowerCase();
      return normalized.contains('firsat');
    }

    final offerCategory = _categories.cast<Map<String, dynamic>?>().firstWhere(
      _isFirsatCategory,
      orElse: () => null,
    );
    final offerCategoryId = offerCategory?['id']?.toString();
    final offerProducts = _products.where((p) => p['category_id'].toString() == offerCategoryId).toList();

    return DefaultTabController(
      length: _categories.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9F9), // Very clean light background
        body: NestedScrollView(
          physics: const BouncingScrollPhysics(),
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            _buildSliverAppBar(),
            _buildOffersSection(offerProducts),
            _buildSliverTabBar(),
          ],
          body: _categories.isEmpty
              ? const Center(child: Text('Henüz menü eklenmemiş.', style: TextStyle(color: Colors.grey)))
              : TabBarView(
                  physics: const BouncingScrollPhysics(),
                  children: _categories.map((cat) {
                    final catProds = _products
                        .where((p) => p['category_id'].toString() == cat['id'].toString())
                        .toList();
                    return _buildProductList(catProds);
                  }).toList(),
                ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280.0,
      stretch: true,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF1C1310), // Ultra dark rich brown
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: const Text(
          'DE\' LARA LOUNGE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
            fontSize: 20,
            shadows: [
              Shadow(color: Colors.black87, blurRadius: 15, offset: Offset(0, 2)),
            ],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Elegant subtle dark gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2E201B),
                    Color(0xFF140D0B),
                  ],
                ),
              ),
            ),
            // Background image ghosting effect (using logo as pattern)
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: Image.asset('logo.jpg', fit: BoxFit.cover),
              ),
            ),
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.15), width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                           // Fallback if logo not found
                           return Container(
                             color: Colors.white,
                             child: const Icon(Icons.coffee, size: 50, color: Color(0xFF2E201B)),
                           );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Siparişiniz İçin Seçiminizi Yapın',
                      style: TextStyle(
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30), // Offset for the title
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverTabBar() {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _TabBarDelegate(
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: const Color(0xFF2C1E16), // Premium Dark
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2C1E16).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey.shade600,
          labelPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.5),
          tabs: _categories.map((cat) {
            // Aynı normalize fonksiyonu ile sekme eşleşmesi yapıyoruz
            final normalized = cat['name'].toString()
                .replaceAll('I', 'i').replaceAll('İ', 'i')
                .replaceAll('ı', 'i').toLowerCase();
            final isOffer = normalized.contains('firsat');
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOffer) const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 18),
                  if (isOffer) const SizedBox(width: 4),
                  Text(_toTurkishUpper(cat['name'].toString()), style: isOffer ? const TextStyle(color: Colors.orange) : null),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProductList(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Bu kategoride ürün bulunmuyor.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 80),
      physics: const BouncingScrollPhysics(),
      itemCount: products.length,
      itemBuilder: (context, index) => _buildProductCard(products[index]),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final hasImage = product['image_url'] != null &&
        product['image_url'].toString().trim().isNotEmpty;
    final hasDesc = product['description'] != null &&
        product['description'].toString().trim().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // Ultra smooth corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8), // Soft floating effect
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Product Image or Logo Fallback
            if (hasImage)
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    product['image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackImage(),
                  ),
                ),
              )
            else
              _buildFallbackImage(),
              
            const SizedBox(width: 16),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    product['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF2C1E16),
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (hasDesc) ...[
                    const SizedBox(height: 6),
                    Text(
                      product['description'],
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF8F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEBE3D5), width: 1),
                        ),
                        child: Text(
                          '₺${product['price']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            color: Color(0xFF4A3424),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6), // Light warm beige
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Opacity(
          opacity: 0.3,
          child: Image.asset('logo.jpg', width: 60, height: 60, fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildOffersSection(List<Map<String, dynamic>> offerProducts) {
    if (offerProducts.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(top: 24, bottom: 20),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1310), // Aynı koyu renk (AppBar ile bütünleşmesi için)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'BUGÜNÜN FIRSATLARI',
                    style: TextStyle(
                      color: Colors.orange.shade300,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: offerProducts.length,
                itemBuilder: (context, index) {
                  return _buildOfferCard(offerProducts[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferCard(Map<String, dynamic> product) {
    final hasImage = product['image_url'] != null && product['image_url'].toString().trim().isNotEmpty;

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 16, bottom: 8, top: 8), // Gölge boşluğu
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.orange.shade700,
            Colors.red.shade800,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(3.0), // Dış çerçeve kalınlığı
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2E201B), // İç koyuluk
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                      child: hasImage
                          ? Image.network(product['image_url'], fit: BoxFit.cover, errorBuilder: (_,__,___) => _buildFallbackImage())
                          : _buildFallbackImage(),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product['name'],
                            style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Text(
                            '₺${product['price']}',
                            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.orange.shade300, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // "FIRSAT" Badge (Ateşli Kurdele)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.orange.shade500, Colors.red.shade600]),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(-2, 2)),
                ],
              ),
              child: const Text('FIRSAT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }
} // State class kapatılır

// Delegate for Sticky TabBar Layout
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height + 24;
  @override
  double get maxExtent => tabBar.preferredSize.height + 24;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        boxShadow: overlapsContent
            ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 5))]
            : null,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(child: tabBar),
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
