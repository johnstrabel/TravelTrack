import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await Hive.openBox('visited_countries');

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://roqzshrqrscjghvotnoq.supabase.co',
    anonKey: 'sb_publishable_z2vrpJ6aHgqxHwpCNDvbsg_4MueYA3U',
  );

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
          backgroundColor: Color(0xFF5B7C99),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        fontFamily: 'System',
      ),
      home: const SplashScreen(), // Changed from WorldMapScreen
    );
  }
}
