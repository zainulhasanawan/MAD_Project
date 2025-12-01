import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/map_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 Load the .env file BEFORE anything else
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://coyecfjmeutnpxqmxckx.supabase.co',
    anonKey:
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNveWVjZmptZXV0bnB4cW14Y2t4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzOTgwMjgsImV4cCI6MjA3OTk3NDAyOH0.H78wPnjrwtYHJ-wvN8ELYORFDApVTtFEyoWp9nMg6mk',
  );

  runApp(const TravelMemoryApp());
}

final supabase = Supabase.instance.client;

class TravelMemoryApp extends StatelessWidget {
  const TravelMemoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TravelMemory',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D8BFF)),
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: Colors.white,
      ),
      routes: {
        '/map': (context) => const MapScreen(),
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (supabase.auth.currentUser != null) {
          return const MainShell();
        }
        return const AuthScreen();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({Key? key}) : super(key: key);

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MapScreen(),
    TimelineScreen(),
    StatsScreen(),
    FeedScreen(),
  ];

  final List<String> _titles = const [
    'Explore Map',
    'Timeline',
    'Statistics',
    'Discover Travelers',
  ];

  void _onTap(int idx) {
    setState(() {
      _currentIndex = idx;
    });
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF3D8BFF);
    final user = supabase.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: Text(
          _titles[_currentIndex],
          style: GoogleFonts.poppins(
            color: const Color(0xFF1A1A2E),
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openProfile,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3D8BFF), Color(0xFF6A5AF9)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3D8BFF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: SafeArea(child: _pages[_currentIndex]),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTap,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: themeBlue,
          unselectedItemColor: const Color(0xFF666687),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined),
              activeIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.timeline_outlined),
              activeIcon: Icon(Icons.timeline_rounded),
              label: 'Timeline',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Stats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore_rounded),
              label: 'Feed',
            ),
          ],
        ),
      ),
    );
  }
}
