// INTEGRATION GUIDE FOR NEW FEATURES
// Copy the relevant sections below into your main.dart file

// ============================================
// SECTION 1: Import the new features file
// Add this at the top of main.dart with other imports
// ============================================
import 'new_features.dart';


// ============================================
// SECTION 2: Update MainScreen to add Statistics tab
// Replace your current MainScreen class with this
// ============================================
class MainScreen extends StatefulWidget {
  final ThemeProvider? themeProvider;
  const MainScreen({super.key, this.themeProvider});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryPageEnhanced(), // Enhanced with search
    const ScanPage(),
    const StatisticsPage(), // NEW: Statistics tab
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detergent Scanner'),
        actions: [
          // NEW: Dark mode toggle button
          if (widget.themeProvider != null)
            IconButton(
              icon: Icon(
                widget.themeProvider!.isDarkMode 
                    ? Icons.light_mode 
                    : Icons.dark_mode,
              ),
              onPressed: () {
                widget.themeProvider!.toggleTheme();
              },
              tooltip: 'Toggle Dark Mode',
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: TopNavBar(
            currentIndex: _currentIndex,
            onTap: _onTabTapped,
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }
}


// ============================================
// SECTION 3: Update TopNavBar to include Statistics
// Replace the children array in TopNavBar build method
// ============================================
children: [
  _buildNavItem(Icons.home_rounded, 'Home', 0),
  _buildNavItem(Icons.history_rounded, 'History', 1),
  _buildNavItem(Icons.qr_code_scanner_rounded, 'Scan', 2),
  _buildNavItem(Icons.bar_chart_rounded, 'Stats', 3), // NEW: Stats tab
],


// ============================================
// SECTION 4: Enhanced History Page with Search & Export
// Replace your current HistoryPage with this
// ============================================
class HistoryPageEnhanced extends StatefulWidget {
  const HistoryPageEnhanced({super.key});

  @override
  State<HistoryPageEnhanced> createState() => _HistoryPageEnhancedState();
}

class _HistoryPageEnhancedState extends State<HistoryPageEnhanced> {
  String _searchQuery = '';
  
  String _getProductImageFromAssets(String classType) {
    final lowerCaseLabel = classType.toLowerCase();
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('sun fresh')) {
      return 'assets/Surf Powder Sun Fresh (2).png';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('kalamansi')) {
      return 'assets/Surf Powder Kalamansi (2).png';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('cherry blossom')) {
      return 'assets/Surf Powder Cherry Blossom (2).png';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('anti-bacterial')) {
      return 'assets/Surf Powder Anti-Bacterial.png';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('tawas')) {
      return 'assets/Surf Powder Tawas (2).png';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('purple blossom')) {
      return 'assets/Surf Powder Purple Blossom (2).png';
    } else if (lowerCaseLabel.contains('tide')) {
      return 'assets/Tide Perfect Clean (2).png';
    } else if (lowerCaseLabel.contains('ariel')) {
      return 'assets/Ariel Powder Detergent (2).png';
    } else if (lowerCaseLabel.contains('fasclean') && lowerCaseLabel.contains('fabric conditioner')) {
      return 'assets/Fasclean Fabric Conditioner (2).png';
    } else if (lowerCaseLabel.contains('fasclean') && lowerCaseLabel.contains('anti-bacterial')) {
      return 'assets/Fasclean Anti-Bacterial.png';
    }
    return '';
  }

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
          return const Center(child: Text('No scan history found.'));
        }
        
        final documents = snapshot.data!.docs;
        
        // Filter documents based on search query
        final filteredDocs = documents.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final classType = (data['ClassType'] ?? '').toString().toLowerCase();
          return classType.contains(_searchQuery.toLowerCase());
        }).toList();

        return Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Export Button
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'Export History',
                    onSelected: (value) async {
                      if (value == 'csv') {
                        await ExportUtils.exportToCSV(documents);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exported as CSV!')),
                          );
                        }
                      } else if (value == 'pdf') {
                        await ExportUtils.exportToPDF(documents);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exported as PDF!')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'csv',
                        child: Row(
                          children: [
                            Icon(Icons.table_chart),
                            SizedBox(width: 8),
                            Text('Export as CSV'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'pdf',
                        child: Row(
                          children: [
                            Icon(Icons.picture_as_pdf),
                            SizedBox(width: 8),
                            Text('Export as PDF'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Results Count
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  '${filteredDocs.length} results found',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ),
            
            // History List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final data = filteredDocs[index].data() as Map<String, dynamic>;
                  final timestamp = data['Time'] as Timestamp?;
                  final classType = data['ClassType'] ?? 'Unknown Class';
                  final accuracy = (data['Accuracy_Rate'] as num?)?.toStringAsFixed(0) ?? '0';
                  final assetImage = _getProductImageFromAssets(classType);

                  return Card(
                    color: Theme.of(context).cardColor,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      leading: _buildHistoryImage(assetImage),
                      title: Text(classType, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(timestamp != null ? 'Scanned on: ${timestamp.toDate().toLocal()}' : 'No date'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$accuracy%', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.share),
                            onPressed: () {
                              ExportUtils.shareText(
                                'Scanned: $classType\nAccuracy: $accuracy%\nDate: ${timestamp?.toDate().toLocal()}',
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ScanDetailScreen(data: data)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryImage(String assetImage) {
    if (assetImage.isNotEmpty) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        child: ClipOval(
          child: Image.asset(
            assetImage,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: 25,
        backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
        child: const Icon(Icons.image_not_supported),
      );
    }
  }
}


// ============================================
// SECTION 5: Update MyApp to pass ThemeProvider
// Replace your MyApp class
// ============================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeProvider _themeProvider = ThemeProvider();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeProvider,
      builder: (context, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Detergent Scanner',
          theme: _themeProvider.lightTheme,
          darkTheme: _themeProvider.darkTheme,
          themeMode: _themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: MainScreen(themeProvider: _themeProvider),
        );
      },
    );
  }
}
