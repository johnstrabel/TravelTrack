import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/data_sync_service.dart';
import 'world_map_screen.dart';

class DataMigrationScreen extends StatefulWidget {
  const DataMigrationScreen({super.key});

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  bool _isLoading = true;
  int _localCountryCount = 0;

  @override
  void initState() {
    super.initState();
    _checkLocalData();
  }

  Future<void> _checkLocalData() async {
    final visitedBox = Hive.box('visited_countries');
    final codes = visitedBox.get('codes');

    int count = 0;
    if (codes is List) {
      count = codes.length;
    } else if (codes is Set) {
      count = codes.length;
    }

    setState(() {
      _localCountryCount = count;
      _isLoading = false;
    });
  }

  Future<void> _uploadData() async {
    setState(() => _isLoading = true);

    try {
      await DataSyncService.syncLocalDataToCloud();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Data synced successfully!'),
            ],
          ),
          backgroundColor: Color(0xFF5B7C99),
        ),
      );

      _navigateToApp();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error syncing data: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  void _skipForNow() {
    _navigateToApp();
  }

  void _navigateToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WorldMapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF5B7C99)),
        ),
      );
    }

    // If no local data, skip straight to app
    if (_localCountryCount == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToApp();
      });
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF5B7C99)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8FF),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF5B7C99), width: 3),
                ),
                child: const Icon(
                  Icons.cloud_upload_outlined,
                  size: 60,
                  color: Color(0xFF5B7C99),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                '📦 Upload Your Local Data?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We found $_localCountryCount ${_localCountryCount == 1 ? 'country' : 'countries'} on your device!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5B7C99),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text(
                'Would you like to sync them to the cloud?',
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _BenefitItem(
                icon: Icons.backup,
                text: 'Backup & sync your travels',
              ),
              const SizedBox(height: 16),
              _BenefitItem(icon: Icons.devices, text: 'Access on any device'),
              const SizedBox(height: 16),
              _BenefitItem(icon: Icons.people, text: 'Share with friends'),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _uploadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B7C99),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Upload Now',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _skipForNow,
                child: const Text(
                  'Skip for Now',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5B7C99),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F8FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF5B7C99), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2C3E50),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
