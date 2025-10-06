// lib/main.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/splash_screen.dart';

Future<void> _initHive() async {
  await Hive.initFlutter();

  // Open all boxes used by the app
  await Hive.openBox('visited_countries');
  await Hive.openBox('user_profile');
  await Hive.openBox('profile_data');
  await Hive.openBox('country_data');

  // Normalize default structure to avoid Set/List drift later
  final visited = Hive.box('visited_countries');
  if (!visited.containsKey('codes')) {
    await visited.put('codes', <String>[]);
  } else {
    final existing = visited.get('codes');
    if (existing is Set) {
      await visited.put('codes', existing.cast<String>().toList());
    }
  }
}

Future<void> _initSupabase() async {
  // TODO: move these to .env via flutter_dotenv in production
  const supabaseUrl = 'https://roqzshrqrscjghvotnoq.supabase.co';
  const supabaseAnonKey = 'sb_publishable_z2vrpJ6aHgqxHwpCNDvbsg_4MueYA3U';

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    // You can tweak the below if you want to see auth logs during testing:
    // debug: kDebugMode,
  );
}

void main() {
  // Catch async errors too
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Init local storage & backend
      await _initHive();
      await _initSupabase();

      // Optional: surface framework errors nicely in debug
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.dumpErrorToConsole(details);
      };

      runApp(const TravelTrackerApp());
    },
    (error, stack) {
      // Last-ditch error logging; replace with Crashlytics/Sentry if desired
      if (kDebugMode) {
        // ignore: avoid_print
        print('Uncaught zone error: $error\n$stack');
      }
    },
  );
}

class TravelTrackerApp extends StatelessWidget {
  const TravelTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = const Color(0xFF5B7C99);

    return MaterialApp(
      title: 'Travel Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Keeping your color choices; you can switch to Material 3 later if you like.
        primaryColor: brand,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
          brightness: Brightness.light,
        ).copyWith(primary: brand),
        fontFamily: 'System',
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        useMaterial3: false, // set true if you migrate styles
      ),
      home: const SplashScreen(),
    );
  }
}
