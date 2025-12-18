
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tflite_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:fl_chart/fl_chart.dart'; // For Charts
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart'; // For dark mode & favorites
import 'package:csv/csv.dart'; // For CSV export
import 'package:pdf/pdf.dart'; // For PDF
import 'package:pdf/widgets.dart' as pw; // For PDF widgets
import 'package:share_plus/share_plus.dart'; // For sharing
import 'package:path_provider/path_provider.dart'; // For file paths
import 'new_features.dart'; // NEW FEATURES

// --- Theme Colors (Light Mode) ---
const Color beigePrimary = Color(0xFFF5F5DC);
const Color beigeBackground = Color(0xFFFAF9F6);
const Color beigeDark = Color(0xFFD3C5AA);
const Color beigeAccent = Color(0xFF8B7D6B);
const Color beigeText = Color(0xFF3D362A);

// --- Dark Theme Colors ---
const Color darkBackground = Color(0xFF1A1A1A);
const Color darkSurface = Color(0xFF2D2D2D);
const Color darkPrimary = Color(0xFF4A4A4A);
const Color darkAccent = Color(0xFFB8A88A);
const Color darkText = Color(0xFFE8E8E8);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

// --- Theme Provider for Dark Mode ---
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primaryColor: beigePrimary,
    scaffoldBackgroundColor: beigeBackground,
    colorScheme: const ColorScheme.light(
      primary: beigePrimary,
      secondary: beigeAccent,
      background: beigeBackground,
      onBackground: beigeText,
      surface: Colors.white,
      onSurface: beigeText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: beigeBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: beigeAccent),
      titleTextStyle: TextStyle(
        color: beigeText,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    iconTheme: const IconThemeData(color: beigeAccent),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: beigeText),
      bodyMedium: TextStyle(color: beigeText),
      headlineSmall: TextStyle(color: beigeText, fontWeight: FontWeight.bold),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );

  ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkAccent,
      background: darkBackground,
      onBackground: darkText,
      surface: darkSurface,
      onSurface: darkText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: darkAccent),
      titleTextStyle: TextStyle(
        color: darkText,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    iconTheme: const IconThemeData(color: darkAccent),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: darkText),
      bodyMedium: TextStyle(color: darkText),
      headlineSmall: TextStyle(color: darkText, fontWeight: FontWeight.bold),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
  );
}

// --- Favorites Manager (Local Storage) ---
class FavoritesManager {
  static const String _favoritesKey = 'favorites';

  static Future<Set<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? favoritesList = prefs.getStringList(_favoritesKey);
    return favoritesList?.toSet() ?? {};
  }

  static Future<void> addFavorite(String productName) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.add(productName);
    await prefs.setStringList(_favoritesKey, favorites.toList());
  }

  static Future<void> removeFavorite(String productName) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    favorites.remove(productName);
    await prefs.setStringList(_favoritesKey, favorites.toList());
  }

  static Future<bool> isFavorite(String productName) async {
    final favorites = await getFavorites();
    return favorites.contains(productName);
  }
}

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
    const HistoryPage(),
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

class TopNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const TopNavBar({required this.currentIndex, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: beigePrimary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, 'Home', 0),
          _buildNavItem(Icons.history_rounded, 'History', 1),
          _buildNavItem(Icons.qr_code_scanner_rounded, 'Scan', 2),
          _buildNavItem(Icons.bar_chart_rounded, 'Stats', 3), // NEW: Statistics tab
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final bool isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? beigeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? beigePrimary : beigeAccent,
            ),
            if (isSelected) const SizedBox(width: 8),
            if (isSelected)
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? beigePrimary : beigeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// --- Home Section ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Product data with images, names, and descriptions
  final List<Map<String, String>> products = const [
    {
      'image': 'assets/Surf Powder Sun Fresh (2).png',
      'name': 'Surf Sun Fresh',
      'description': 'Bright sun-fresh scent for all-day freshness',
    },
    {
      'image': 'assets/Surf Powder Kalamansi (2).png',
      'name': 'Surf Kalamansi',
      'description': 'Refreshing kalamansi fragrance for crisp wash',
    },
    {
      'image': 'assets/Surf Powder Cherry Blossom (2).png',
      'name': 'Surf Cherry Blossom',
      'description': 'Gentle cherry blossom scent for lasting freshness',
    },
    {
      'image': 'assets/Surf Powder Anti-Bacterial.png',
      'name': 'Surf Anti-Bacterial',
      'description': 'Protects clothes from bacteria effectively',
    },
    {
      'image': 'assets/Surf Powder Tawas (2).png',
      'name': 'Surf Tawas',
      'description': 'Removes tough stains and eliminates odors',
    },
    {
      'image': 'assets/Surf Powder Purple Blossom (2).png',
      'name': 'Surf Purple Blossom',
      'description': 'Soft floral scent with strong cleaning power',
    },
    {
      'image': 'assets/Tide Perfect Clean (2).png',
      'name': 'Tide Perfect Clean',
      'description': 'Deep cleaning power for tough stains',
    },
    {
      'image': 'assets/Ariel Powder Detergent (2).png',
      'name': 'Ariel Powder',
      'description': 'Powerful stain removal and brightening action',
    },
    {
      'image': 'assets/Fasclean Fabric Conditioner (2).png',
      'name': 'Fasclean Conditioner',
      'description': 'Softens fabrics for comfortable wear',
    },
    {
      'image': 'assets/Fasclean Anti-Bacterial.png',
      'name': 'Fasclean Anti-Bacterial',
      'description': 'Fights odor-causing bacteria for hygiene',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Text(
            "Product Gallery",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Explore our detergent collection",
            style: TextStyle(
              fontSize: 16,
              color: beigeAccent.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 24),
          
          // Grid Layout - 2 columns, 5 rows
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.75, // Adjust card height
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(
                context,
                products[index]['image']!,
                products[index]['name']!,
                products[index]['description']!,
                index,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    String imagePath,
    String name,
    String description,
    int index,
  ) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(
            opacity: value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: beigeDark.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Image
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Container(
                        color: beigePrimary.withOpacity(0.3),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Product Info
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: beigeText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 11,
                              color: beigeAccent.withOpacity(0.8),
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}


// --- Scan Section ---
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  String _status = 'Initializing...';
  final TFLiteHelper _tfliteHelper = TFLiteHelper();
  bool _isModelLoaded = false;
  AnimationController? _animationController;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }
  
  @override
  void dispose() {
    _cameraController?.dispose();
    _animationController?.dispose();
    _tfliteHelper.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _status = 'Initializing Camera...';
    });
    await _initializeCamera();
    if (mounted && _isInitialized) {
      _loadModel();
    }
  }

  Future<void> _loadModel() async {
    setState(() {
      _status = 'Loading Model...';
    });
    try {
      await _tfliteHelper.loadModel();
      if (mounted) {
        setState(() {
          _isModelLoaded = true;
          _status = 'Tap to Scan';
        });
      }
    } catch (e, s) {
      if (mounted) setState(() => _status = 'Error loading model: $e');
      print('Error loading model: $e\n$s');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final status = await Permission.camera.request();
      if (status != PermissionStatus.granted) {
        if (mounted) setState(() => _status = 'Camera permission denied');
        return;
      }
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        if (mounted) setState(() => _status = 'No cameras found');
        return;
      }
      _cameraController = CameraController(_cameras![0], ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _status = 'Camera error: $e');
    }
  }

  // In _ScanPageState

  Future<void> _savePredictionToFirestore(List<Map<String, dynamic>> predictions, String imagePath) async {
    if (predictions.isEmpty) { return; }

    final topPrediction = predictions[0];
    final double topConfidence = topPrediction['confidence'];

    // --- Confidence and Gap check logic ---
    const primaryThreshold = 0.90;
    if (topConfidence < primaryThreshold) {
      print("Confidence is below 90%. Not saving.");
      return;
    }
    if (predictions.length > 1) {
      final double secondConfidence = predictions[1]['confidence'];
      final double confidenceGap = topConfidence - secondConfidence;
      const gapThreshold = 0.50;
      if (confidenceGap < gapThreshold) {
        print("Confidence Gap is below 50%. Not saving.");
        return;
      }
    }
    // --- End of checks ---

    HapticFeedback.heavyImpact();

    try {
      final collection = FirebaseFirestore.instance.collection('Morales_DetergentPowder_Logs');
      await collection.add({
        'ClassType': topPrediction['label'],
        'Accuracy_Rate': (topConfidence * 100),
        'Time': FieldValue.serverTimestamp(),
      });
      print("SUCCESS: Prediction saved to Firestore.");
    } catch (e) {
      print("Error saving to Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save result: $e')));
      }
    }
  }


  // In _ScanPageState

  Future<void> _processImage(String imagePath) async {
    setState(() {
      _status = 'Processing image...';
    });

    final imageFile = File(imagePath);
    final predictions = _tfliteHelper.predictImage(imageFile);

    if (predictions != null && predictions.isNotEmpty) {
      // FIX IS HERE: Pass the imagePath to the save function
      await _savePredictionToFirestore(predictions, imagePath);
    }

    if (mounted && predictions != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultsScreen(
            imagePath: imagePath,
            predictions: predictions,
          ),
        ),
      );
      // Reset status after returning from results
      setState(() {
        _status = '';
      });
    }
  }


  Future<void> _takePicture() async {
    if (!_isInitialized || !_isModelLoaded) return;
    _animationController?.forward().then((_) => _animationController?.reverse());
    try {
      final XFile image = await _cameraController!.takePicture();
      _processImage(image.path);
    } catch (e) {
      print("Error taking picture: $e");
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (!_isModelLoaded) return;
    _animationController?.forward().then((_) => _animationController?.reverse());
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      _processImage(image.path);
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canScan = _isInitialized && _isModelLoaded;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _isInitialized
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_cameraController!),
                        if (!_isModelLoaded)
                          Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(color: Colors.white),
                                  const SizedBox(height: 10),
                                  Text(_status, style: const TextStyle(color: Colors.white, fontSize: 16))
                                ],
                              ),
                            ),
                          ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: IconButton(
                            icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                            onPressed: () {
                              if (_cameraController != null && _cameraController!.value.isInitialized) {
                                setState(() => _isFlashOn = !_isFlashOn);
                                _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
                              }
                            },
                          ),
                        )
                      ],
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [const CircularProgressIndicator(color: beigeAccent), const SizedBox(height: 16), Text(_status)],
                      ),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const SizedBox(width: 72),
                  ScaleTransition(
                    scale: Tween<double>(begin: 1.0, end: 0.9).animate(_animationController!),
                    child: GestureDetector(
                      onTap: canScan ? _takePicture : null,
                      child: Opacity(
                        opacity: canScan ? 1.0 : 0.4,
                        child: Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: beigeDark, width: 3)),
                          child: Center(child: Container(height: 60, width: 60, decoration: const BoxDecoration(shape: BoxShape.circle, color: beigePrimary))),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 72,
                    child: IconButton(
                      onPressed: canScan ? _pickImageFromGallery : null,
                      icon: Icon(Icons.photo_library_outlined, color: canScan ? beigeAccent : beigeDark, size: 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(canScan ? "Tap to Scan" : _status, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            ],
          ),
        ),
      ],
    );
  }
}

// --- History Section ---
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _searchQuery = '';

  // Helper function to get product image from assets based on ClassType
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
            // Search Bar and Export Button
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filteredDocs.length} results found',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
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
                      subtitle: Text(
                        timestamp != null 
                            ? 'Scanned on: ${timestamp.toDate().toLocal().toString().split('.')[0]}'
                            : 'No date',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$accuracy%',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, size: 20),
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

class ScanDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  const ScanDetailScreen({super.key, required this.data});

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
    final classType = data['ClassType'] as String?;
    final accuracy = data['Accuracy_Rate'] as num?;
    final time = (data['Time'] as Timestamp?)?.toDate();
    final productImage = _getProductImageFromAssets(classType ?? '');

    return Scaffold(
      appBar: AppBar(title: Text(classType ?? 'Scan Details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display product image from assets
            if (productImage.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: double.infinity,
                  height: 300,
                  color: beigePrimary.withOpacity(0.3),
                  padding: const EdgeInsets.all(24),
                  child: Image.asset(
                    productImage,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('Identified Product', style: TextStyle(color: beigeAccent.withOpacity(0.8))),
            Text(classType ?? 'N/A', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text('Confidence Score', style: TextStyle(color: beigeAccent.withOpacity(0.8))),
            Text('${accuracy?.toStringAsFixed(1) ?? '0'}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Text('Scan Date', style: TextStyle(color: beigeAccent.withOpacity(0.8))),
            Text(time?.toLocal().toString() ?? 'N/A', style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

// --- Results Screen and Widgets ---
class ResultsScreen extends StatelessWidget {
  final String imagePath;
  final List<Map<String, dynamic>> predictions;

  const ResultsScreen({super.key, required this.imagePath, required this.predictions});

  Color _getProductColor(String label) {
    // These can be updated to match the beige theme better if needed
    final lowerCaseLabel = label.toLowerCase();
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('sun fresh')) return Colors.yellow;
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('kalamansi')) return Colors.green;
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('cherry blossom')) return Colors.orange;
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('anti-bacterial')) return Colors.blueGrey;
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('tawas')) return Colors.lightBlue;
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('purple blossom')) return Colors.purple;
    if (lowerCaseLabel.contains('tide')) return Colors.red;
    if (lowerCaseLabel.contains('ariel')) return Colors.grey;
    if (lowerCaseLabel.contains('fasclean') && lowerCaseLabel.contains('fabric conditioner')) return Colors.brown;
    if (lowerCaseLabel.contains('fasclean') && lowerCaseLabel.contains('anti-bacterial')) return const Color(0xFF000080);
    return beigeDark;
  }

  String _getProductDescription(String label) {
    final lowerCaseLabel = label.toLowerCase();
    if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('sun fresh')) {
      return 'Provides powerful stain removal with a bright, sun-fresh scent that keeps clothes smelling clean and fresh all day.';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('tawas')) {
      return 'Effectively removes tough stains while helping eliminate odors, leaving clothes clean and naturally fresh.';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('kalamansi')) {
      return 'Cleans clothes deeply with a refreshing kalamansi fragrance for a crisp and revitalizing wash.';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('purple blossom')) {
      return 'Delivers strong cleaning performance with a soft floral scent that keeps clothes smelling pleasant.';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('cherry blossom')) {
      return 'Removes stains while adding a gentle cherry blossom fragrance for long-lasting freshness.';
    } else if (lowerCaseLabel.contains('surf') && lowerCaseLabel.contains('anti-bacterial')) {
      return 'Removes stains while helping protect clothes from bacteria.';
    } else if (lowerCaseLabel.contains('fasclean') && lowerCaseLabel.contains('fabric conditioner')) {
      return 'Softens fabrics and leaves clothes smooth, fresh-smelling, and comfortable to wear.';
    } else if (lowerCaseLabel.contains('fasclean') && lowerCaseLabel.contains('anti-bacterial')) {
      return 'Helps fight odor-causing bacteria for hygienic freshness.';
    } else if (lowerCaseLabel.contains('tide')) {
      return 'Offers deep cleaning power to remove tough stains, leaving clothes visibly clean and fresh.';
    } else if (lowerCaseLabel.contains('ariel')) {
      return 'Provides powerful stain removal and brightening action for cleaner, fresher-looking clothes.';
    }
    return 'No description available.';
  }

  String _getProductImageFromAssets(String label) {
    final lowerCaseLabel = label.toLowerCase();
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
    bool isPredictionConfident = false;
    if (predictions.isNotEmpty) {
      final double topConfidence = predictions[0]['confidence'];
      const primaryThreshold = 0.90;
      if (topConfidence >= primaryThreshold) {
        if (predictions.length > 1) {
          final double secondConfidence = predictions[1]['confidence'];
          final double confidenceGap = topConfidence - secondConfidence;
          const gapThreshold = 0.50;
          if (confidenceGap >= gapThreshold) {
            isPredictionConfident = true;
          }
        } else {
          isPredictionConfident = true;
        }
      }
    }
    if (!isPredictionConfident) HapticFeedback.lightImpact();

    final topPrediction = predictions.isNotEmpty ? predictions[0] : null;
    final top5Predictions = predictions.take(5).toList();
    final String topLabel = topPrediction?['label'] ?? '';
    final Color productColor = _getProductColor(topLabel);
    final String productImage = _getProductImageFromAssets(topLabel);

    return Scaffold(
      backgroundColor: beigeBackground,
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: beigeBackground,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Scanned Image
                  Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  ),
                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  // Confidence Badge
                  if (topPrediction != null)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isPredictionConfident 
                              ? productColor.withOpacity(0.9)
                              : Colors.orangeAccent.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPredictionConfident ? Icons.check_circle : Icons.warning,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(topPrediction['confidence'] * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Prediction Card - Enhanced
                  if (topPrediction != null) 
                    _buildEnhancedTopPredictionCard(
                      topPrediction, 
                      isPredictionConfident,
                      productImage,
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Confidence Chart
                  if (top5Predictions.isNotEmpty) 
                    _buildBarChart(context, top5Predictions),
                  
                  const SizedBox(height: 24),
                  
                  // All Predictions Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: beigeDark.withOpacity(0.1),
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
                            Icon(Icons.analytics_outlined, color: beigeAccent),
                            const SizedBox(width: 12),
                            const Text(
                              'All Predictions',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildEnhancedConfidenceList(predictions),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTopPredictionCard(
    Map<String, dynamic> topPrediction,
    bool isConfident,
    String productImage,
  ) {
    final double confidence = topPrediction['confidence'];
    final String label = topPrediction['label'];
    final Color productColor = _getProductColor(label);
    final String description = _getProductDescription(label);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: productColor.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with Product Image
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  productColor.withOpacity(0.1),
                  productColor.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // Product Image
                if (productImage.isNotEmpty)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(
                      productImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                const SizedBox(width: 20),
                
                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isConfident ? productColor : Colors.orangeAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isConfident ? '✓ Identified' : '⚠ Low Confidence',
                          style: TextStyle(
                            color: (isConfident ? productColor : Colors.orangeAccent)
                                    .computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isConfident ? label : 'Unable to identify',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: beigeText,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Description
          if (isConfident)
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: productColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Product Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: beigeText.withOpacity(0.8),
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEnhancedConfidenceList(List<Map<String, dynamic>> predictions) {
    return Column(
      children: predictions.asMap().entries.map((entry) {
        final int index = entry.key;
        final prediction = entry.value;
        final String label = prediction['label'];
        final double confidence = prediction['confidence'];
        final Color productColor = _getProductColor(label);
        final String productImage = _getProductImageFromAssets(label);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: productColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: productColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Rank Badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: index == 0 ? productColor : beigeDark,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: (index == 0 ? productColor : beigeDark)
                              .computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Product Image Thumbnail
              if (productImage.isNotEmpty)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.asset(
                    productImage,
                    fit: BoxFit.contain,
                  ),
                ),
              const SizedBox(width: 12),
              
              // Label
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              
              // Confidence with Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: productColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: beigePrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: confidence,
                      child: Container(
                        decoration: BoxDecoration(
                          color: productColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopPredictionCard(Map<String, dynamic> topPrediction, bool isConfident) {
    final double confidence = topPrediction['confidence'];
    final String label = topPrediction['label'];
    final Color productColor = _getProductColor(label);
    final String description = _getProductDescription(label);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isConfident ? productColor.withOpacity(0.7) : Colors.transparent, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isConfident ? productColor : Colors.orangeAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isConfident ? 'Top Match' : 'Not Identified',
                    style: TextStyle(
                      color: (isConfident ? productColor : Colors.orangeAccent).computeLuminance() > 0.5 ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isConfident ? label : 'Confidence is too low',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isConfident) const SizedBox(height: 12),
                if (isConfident)
                  Container(
                    padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                      border: Border.all(color: productColor.withOpacity(0.5)),
                       borderRadius: BorderRadius.circular(12),
                       color: productColor.withOpacity(0.05),
                     ),
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: beigeText.withOpacity(0.9),
                        height: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: ConfidenceRingPainter(
                confidence: confidence,
                backgroundColor: beigePrimary,
                foregroundColor: isConfident ? productColor : Colors.orangeAccent,
              ),
              child: Center(
                child: Text('${(confidence * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceList(List<Map<String, dynamic>> predictions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        children: predictions.asMap().entries.map((entry) {
          final int index = entry.key;
          final prediction = entry.value;
          final String label = prediction['label'];
          final double confidence = prediction['confidence'];
          final Color productColor = _getProductColor(label);
          final String description = _getProductDescription(label);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  border: index != predictions.length -1 ? Border(bottom: BorderSide(color: beigePrimary)) : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: productColor, shape: BoxShape.circle)),
                      const SizedBox(width: 16),
                      Expanded(child: Text(label, style: const TextStyle(fontSize: 16), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 16),
                      Text('${(confidence * 100).toStringAsFixed(1)}%', style: TextStyle(color: beigeText.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: productColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: productColor.withOpacity(0.5)),
                    ),
                    child: Text(
                      description,
                      style: TextStyle(
                        color: beigeText.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLegend(List<Map<String, dynamic>> predictions, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: predictions.map((pred) {
          final label = pred['label'] as String;
          final color = _getProductColor(label);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 14)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart(BuildContext context, List<Map<String, dynamic>> topPredictions) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top 5 Results', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 1.0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => beigeDark.withOpacity(0.8),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final pred = topPredictions[group.x.toInt()];
                      final label = pred['label'];
                      final confidence = (rod.toY * 100).toStringAsFixed(1);
                      return BarTooltipItem(
                        '$label\n$confidence%',
                        TextStyle(color: _getProductColor(label).computeLuminance() > 0.5 ? Colors.black : Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 0.25,
                      getTitlesWidget: (value, meta) {
                        if (value % 0.25 == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 12, color: beigeText.withOpacity(0.6))),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.25,
                  getDrawingHorizontalLine: (value) => FlLine(color: beigePrimary, strokeWidth: 1),
                ),
                barGroups: topPredictions.asMap().entries.map((entry) {
                  final color = _getProductColor(entry.value['label']);
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value['confidence'],
                        gradient: LinearGradient(colors: [color.withOpacity(0.7), color], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                        width: 18,
                        borderRadius: const BorderRadius.all(Radius.circular(4)),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          _buildLegend(topPredictions, context),
        ],
      ),
    );
  }
}

class ConfidenceRingPainter extends CustomPainter {
  final double confidence;
  final Color backgroundColor;
  final Color foregroundColor;
  ConfidenceRingPainter({required this.confidence, required this.backgroundColor, required this.foregroundColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 12.0;
    final backgroundPaint = Paint()..color = backgroundColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, backgroundPaint);
    final foregroundPaint = Paint()..color = foregroundColor..style = PaintingStyle.stroke..strokeWidth = strokeWidth..strokeCap = StrokeCap.round;
    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * confidence;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

