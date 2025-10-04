import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'username_setup_screen.dart';
import 'world_map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;

    if (session != null) {
      // User is logged in - check if they have a profile
      final userId = session.user.id;
      final profile = await AuthService.getUserProfile(userId);

      if (!mounted) return;

      if (profile == null) {
        // No profile yet - go to username setup
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const UsernameSetupScreen()),
        );
      } else {
        // Profile exists - go to main app
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WorldMapScreen()),
        );
      }
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5B7C99),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.travel_explore, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'Travel Tracker',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
