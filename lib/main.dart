import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/world_map_screen.dart';

void main() async {
  // Initialize Hive
  await Hive.initFlutter();
  
  // Open the visited countries box
  await Hive.openBox('visited_countries');
  
  runApp(const TravelTrackerApp());
}

class TravelTrackerApp extends StatelessWidget {
  const TravelTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        fontFamily: 'System',
      ),
      home: const WorldMapScreen(),
    );
  }
}