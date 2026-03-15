import 'package:flutter/material.dart';
import 'table_detail_view.dart';

class OpenTableTab extends StatefulWidget {
  const OpenTableTab({Key? key}) : super(key: key);

  @override
  State<OpenTableTab> createState() => _OpenTableTabState();
}

class _OpenTableTabState extends State<OpenTableTab> {
  String _selectedSection = 'A'; // 'A' veya 'B'

  @override
  Widget build(BuildContext context) {
    // A bölümü 17, B bölümü 25 masa
    final int tableCount = _selectedSection == 'A' ? 17 : 25;

    return Column(
      children: [
        // Dinamik Bölüm Seçici (A veya B)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'A',
                label: Text('A Bölümü (17 Masa)'),
              ),
              ButtonSegment(
                value: 'B',
                label: Text('B Bölümü (25 Masa)'),
              ),
            ],
            selected: {_selectedSection},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() {
                _selectedSection = newSelection.first;
              });
            },
          ),
        ),
        
        // Masa Listesi (Dörtlü grid yapısı)
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, // 4'erli dizilim
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: tableCount,
            itemBuilder: (context, index) {
              final tableNumber = '${_selectedSection}${index + 1}';
              return InkWell(
                onTap: () {
                  // Seçilen masaya girilince ürün ve kategori ekranı açılır
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TableDetailView(tableName: tableNumber),
                    ),
                  );
                },
                child: Card(
                  color: Colors.green.shade100, // Şimdilik boş ve açılabilir renk
                  child: Center(
                    child: Text(
                      tableNumber,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
