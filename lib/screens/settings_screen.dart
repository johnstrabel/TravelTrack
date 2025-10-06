import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/data_clear_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  String _username = '';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase
            .from('users')
            .select()
            .eq('id', user.id)
            .single();

        setState(() {
          _username = profile['username'] as String;
          _email = user.email ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('⚠️ Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );

      try {
        print('🔓 Starting logout process...');

        await _supabase.auth.signOut(scope: SignOutScope.local);
        print('✅ Supabase session cleared');

        await DataClearService.clearAllUserData();
        print('✅ All local data cleared');

        if (!mounted) return;

        Navigator.of(context).pop();

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
          (route) => false,
        );

        print('✅ Logout complete');
      } catch (e) {
        print('❌ Logout error: $e');
        if (!mounted) return;

        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: const Color(0xFF5B7C99),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF5B7C99)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF5B7C99),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            icon: Icons.person,
            title: 'Username',
            subtitle: '@$_username',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edit username - Coming soon'),
                  backgroundColor: Color(0xFF5B7C99),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.email,
            title: 'Email',
            subtitle: _email,
            onTap: null,
          ),

          const SizedBox(height: 24),

          // Privacy Section
          _buildSectionHeader('Privacy'),
          _buildSettingsTile(
            icon: Icons.lock,
            title: 'Privacy Settings',
            subtitle: 'Control who can see your profile',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy settings - Coming soon'),
                  backgroundColor: Color(0xFF5B7C99),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.visibility,
            title: 'Profile Visibility',
            subtitle: 'Public',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile visibility - Coming soon'),
                  backgroundColor: Color(0xFF5B7C99),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Data Section
          _buildSectionHeader('Data'),
          _buildSettingsTile(
            icon: Icons.cloud_sync,
            title: 'Sync Data',
            subtitle: 'Upload local data to cloud',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data sync feature coming soon'),
                  backgroundColor: Color(0xFF5B7C99),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.download,
            title: 'Export Data',
            subtitle: 'Download your travel data',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export feature coming soon'),
                  backgroundColor: Color(0xFF5B7C99),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader('About'),
          _buildSettingsTile(
            icon: Icons.info,
            title: 'Version',
            subtitle: '1.0.0',
            onTap: null,
          ),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Read our terms and conditions',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Terms of Service - Coming soon'),
                  backgroundColor: Color(0xFF5B7C99),
                ),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Privacy Policy - Coming soon'),
                  backgroundColor: Color(0xFF5B7C99),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: _logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout),
                  SizedBox(width: 8),
                  Text(
                    'Log Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String? subtitle,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF5B7C99)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              )
            : null,
        trailing: onTap != null
            ? Icon(Icons.chevron_right, color: Colors.grey[400])
            : null,
        onTap: onTap,
      ),
    );
  }
}
