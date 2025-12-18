import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:fl_chart/fl_chart.dart';

// Import main colors
import 'main.dart';

// --- Statistics Page ---
class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  String _selectedRange = 'All Time';
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Morales_DetergentPowder_Logs')
          .orderBy('Time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No scan data yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start scanning products to see statistics',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final documents = snapshot.data!.docs;
        
        // Calculate statistics
        final Map<String, int> productCounts = {};
        double totalAccuracy = 0;
        
        for (var doc in documents) {
          final data = doc.data() as Map<String, dynamic>;
          final classType = data['ClassType'] as String? ?? 'Unknown';
          final accuracy = data['Accuracy_Rate'] as num? ?? 0;
          
          productCounts[classType] = (productCounts[classType] ?? 0) + 1;
          totalAccuracy += accuracy;
        }
        
        final mostScanned = productCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b);
        final avgAccuracy = totalAccuracy / documents.length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your scanning insights',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              
              // Stats Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Total Scans',
                      '${documents.length}',
                      Icons.qr_code_scanner,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Avg Accuracy',
                      '${avgAccuracy.toStringAsFixed(1)}%',
                      Icons.speed,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                context,
                'Most Scanned',
                mostScanned.key,
                Icons.star,
                Colors.orange,
                subtitle: '${mostScanned.value} scans',
              ),
              
              const SizedBox(height: 32),
              
              // Product Distribution Chart
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Distribution',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 250,
                      child: PieChart(
                        PieChartData(
                          sections: _createPieChartSections(productCounts),
                          sectionsSpace: 2,
                          centerSpaceRadius: 60,
                          pieTouchData: PieTouchData(
                            touchCallback: (FlTouchEvent event, pieTouchResponse) {},
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildLegend(productCounts),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _createPieChartSections(Map<String, int> productCounts) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];
    
    int colorIndex = 0;
    return productCounts.entries.map((entry) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.value}',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(Map<String, int> productCounts) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
      Colors.indigo,
      Colors.cyan,
    ];
    
    int colorIndex = 0;
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: productCounts.entries.map((entry) {
        final color = colors[colorIndex % colors.length];
        colorIndex++;
        
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              entry.key,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// --- Export Utilities ---
class ExportUtils {
  static Future<void> exportToCSV(List<QueryDocumentSnapshot> documents) async {
    List<List<dynamic>> rows = [];
    
    // Header
    rows.add(['Product Name', 'Accuracy (%)', 'Scan Date']);
    
    // Data
    for (var doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      final classType = data['ClassType'] ?? 'Unknown';
      final accuracy = (data['Accuracy_Rate'] as num?)?.toStringAsFixed(1) ?? '0';
      final time = (data['Time'] as Timestamp?)?.toDate().toString() ?? 'N/A';
      
      rows.add([classType, accuracy, time]);
    }
    
    String csv = const ListToCsvConverter().convert(rows);
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/scan_history_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csv);
    
    // Share the file
    await Share.shareXFiles([XFile(path)], text: 'Scan History Export');
  }

  static Future<void> exportToPDF(List<QueryDocumentSnapshot> documents) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Detergent Scanner - Scan History',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Generated: ${DateTime.now().toString()}'),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                headers: ['Product Name', 'Accuracy (%)', 'Scan Date'],
                data: documents.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return [
                    data['ClassType'] ?? 'Unknown',
                    (data['Accuracy_Rate'] as num?)?.toStringAsFixed(1) ?? '0',
                    (data['Time'] as Timestamp?)?.toDate().toString() ?? 'N/A',
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
    
    // Save to file
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/scan_history_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    
    // Share the file
    await Share.shareXFiles([XFile(path)], text: 'Scan History Report');
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
