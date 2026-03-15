import 'package:flutter/material.dart';
import 'table_detail_view.dart';
import '../../core/services/supabase_service.dart';

class OpenTableTab extends StatefulWidget {
  const OpenTableTab({Key? key}) : super(key: key);

  @override
  State<OpenTableTab> createState() => _OpenTableTabState();
}

class _OpenTableTabState extends State<OpenTableTab> {
  final _supabase = SupabaseService.instance.client;
  String _selectedSection = 'A';
  List<Map<String, dynamic>> _tables = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTables();
  }

  Future<void> _fetchTables() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('tables')
          .select()
          .order('name');
      
      final List<Map<String, dynamic>> tables = List<Map<String, dynamic>>.from(response);
      
      // Doğal sıralama
      tables.sort((a, b) {
        String nameA = a['name'] ?? '';
        String nameB = b['name'] ?? '';
        if (nameA.isEmpty || nameB.isEmpty) return 0;
        if (nameA[0] == nameB[0]) {
          int valA = int.tryParse(nameA.substring(1)) ?? 0;
          int valB = int.tryParse(nameB.substring(1)) ?? 0;
          return valA.compareTo(valB);
        }
        return nameA.compareTo(nameB);
      });

      if (mounted) {
        setState(() {
          _tables = tables;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Masa çekme hatası: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sectionTables = _tables.where((t) => (t['name'] as String).startsWith(_selectedSection)).toList();

    return Column(
      children: [
        // Dinamik Bölüm Seçici
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              _buildSectionButton('A'),
              const SizedBox(width: 12),
              _buildSectionButton('B'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.brown),
                onPressed: _fetchTables,
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.brown))
            : sectionTables.isEmpty
               ? const Center(child: Text('Henüz masa tanımlanmamış.'))
               : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: sectionTables.length,
                  itemBuilder: (context, index) {
                    final table = sectionTables[index];
                    final String tableName = table['name'];
                    final bool isOccupied = table['status'] == 'occupied';

                    return InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TableDetailView(tableName: tableName),
                          ),
                        );
                        _fetchTables(); // Geri dönünce durumu güncelle
                      },
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isOccupied ? Colors.orange.shade50 : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: isOccupied ? Colors.orange.shade200 : Colors.grey.shade200,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              tableName,
                              style: TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.bold,
                                color: isOccupied ? Colors.orange.shade900 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isOccupied ? 'DOLU' : 'BOŞ',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: isOccupied ? Colors.orange : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSectionButton(String section) {
    bool isSelected = _selectedSection == section;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSection = section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.brown : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? Colors.brown : Colors.grey.shade300),
            boxShadow: isSelected ? [BoxShadow(color: Colors.brown.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Center(
            child: Text(
              '$section Bölümü',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
