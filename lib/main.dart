import 'package:flutter/material.dart';
import 'screens/map_screen.dart';
import "screens/timeline_screen.dart";
void main() {
  runApp(const TravelMemoryApp());
}

class TravelMemoryApp extends StatelessWidget {
  const TravelMemoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TravelMemory',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3D8BFF)),
        useMaterial3: true,
      ),
      home: const TimelineScreen(),
    );
  }
}
