import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/data_clear_service.dart';
import 'auth_screen.dart';
import 'username_setup_screen.dart';
import 'world_map_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // Toggle this to silence logs in production if you want.
  static const bool _debugLogs = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Small splash delay for aesthetics (optional).
    await Future.delayed(const Duration(milliseconds: 600));

    final supa = Supabase.instance.client;

    // Ensure auth state is up-to-date (prevents stale sessions after app restarts).
    try {
      await supa.auth.refreshSession();
    } catch (e) {
      _log('⚠️ refreshSession error: $e');
      // If refresh fails, treat as no session.
    }

    final session = supa.auth.currentSession;
    if (session == null) {
      _log('🔓 No session → clearing local data → AuthScreen');
      await _safeClearAll();
      if (!mounted) return;
      _go(const AuthScreen());
      return;
    }

    final uid = session.user.id;
    _log('🔍 Session found for uid=$uid → fetching profile');

    try {
      final profile = await AuthService.getUserProfile(uid);

      if (!mounted) return;

      if (profile == null) {
        // No profile for this authenticated user: clear any stale local cache
        // so we don’t show prior user’s data.
        _log(
          '❌ No profile for $uid → clearing local data → UsernameSetupScreen',
        );
        await _safeClearAll();
        _go(const UsernameSetupScreen());
        return;
      }

      _log('✅ Profile exists for @$uid → WorldMapScreen');
      _go(const WorldMapScreen());
    } catch (e) {
      // Any unexpected error → fail safe: clear local and force profile creation
      _log(
        '⚠️ Error reading profile: $e → clearing local data → UsernameSetupScreen',
      );
      await _safeClearAll();
      if (!mounted) return;
      _go(const UsernameSetupScreen());
    }
  }

  Future<void> _safeClearAll() async {
    try {
      await DataClearService.clearAllUserData();
    } catch (e) {
      _log('⚠️ DataClearService error: $e (continuing)');
    }
  }

  void _go(Widget page) {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  void _log(String msg) {
    if (_debugLogs) {
      // ignore: avoid_print
      print('[Splash] $msg');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5B7C99),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.travel_explore, size: 100, color: Colors.white),
            SizedBox(height: 24),
            Text(
              'Travel Tracker',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
