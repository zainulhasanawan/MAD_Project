import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/map_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/auth_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://coyecfjmeutnpxqmxckx.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNveWVjZmptZXV0bnB4cW14Y2t4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQzOTgwMjgsImV4cCI6MjA3OTk3NDAyOH0.H78wPnjrwtYHJ-wvN8ELYORFDApVTtFEyoWp9nMg6mk',
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

// Check if user is logged in
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Check if user is logged in
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
    ProfileScreen(),
  ];

  void _onTap(int idx) {
    setState(() {
      _currentIndex = idx;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF3D8BFF);
    return Scaffold(
      body: SafeArea(child: _pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: themeBlue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.timeline), label: 'Timeline'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}