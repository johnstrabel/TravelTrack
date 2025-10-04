import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/auth_service.dart';
import 'data_migration_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _profilePicturePath;
  bool _isLoading = false;
  bool _isCheckingUsername = false;
  String? _usernameError;
  bool _isUsernameAvailable = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _checkUsername(String username) async {
    if (username.isEmpty) {
      setState(() {
        _usernameError = null;
        _isUsernameAvailable = false;
      });
      return;
    }

    // Basic validation
    if (username.length < 3) {
      setState(() {
        _usernameError = 'Username must be at least 3 characters';
        _isUsernameAvailable = false;
      });
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      setState(() {
        _usernameError = 'Only letters, numbers, and underscores allowed';
        _isUsernameAvailable = false;
      });
      return;
    }

    setState(() => _isCheckingUsername = true);

    try {
      final isAvailable = await AuthService.isUsernameAvailable(username);
      setState(() {
        _isUsernameAvailable = isAvailable;
        _usernameError = isAvailable ? null : 'Username already taken';
        _isCheckingUsername = false;
      });
    } catch (e) {
      setState(() {
        _usernameError = 'Error checking username';
        _isCheckingUsername = false;
      });
    }
  }

  Future<void> _pickProfilePicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.first.path;
        if (filePath != null) {
          setState(() => _profilePicturePath = filePath);
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _continue() async {
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _usernameError = 'Username is required');
      return;
    }

    if (!_isUsernameAvailable) {
      setState(() => _usernameError = 'Please choose an available username');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Upload profile picture to Supabase Storage if provided
      String? profilePicUrl;

      await AuthService.createUserProfile(
        username: _usernameController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        profilePicUrl: profilePicUrl,
      );

      if (!mounted) return;

      // Navigate to data migration screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DataMigrationScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose Your Username',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is how friends will find you',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),

              // Profile Picture
              Center(
                child: GestureDetector(
                  onTap: _pickProfilePicture,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(
                            color: const Color(0xFF5B7C99),
                            width: 3,
                          ),
                        ),
                        child: ClipOval(
                          child: _profilePicturePath != null
                              ? Image.file(
                                  File(_profilePicturePath!),
                                  fit: BoxFit.cover,
                                )
                              : Icon(
                                  Icons.person,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B7C99),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap to upload photo (optional)',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 32),

              // Username
              const Text(
                'Username',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline),
                  hintText: 'sarah_travels',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  errorText: _usernameError,
                  suffixIcon: _isCheckingUsername
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _isUsernameAvailable
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                enabled: !_isLoading,
                onChanged: (value) {
                  // Debounce username check
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (value == _usernameController.text) {
                      _checkUsername(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Bio
              const Text(
                'Bio (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Beach lover & foodie...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 32),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading || !_isUsernameAvailable
                      ? null
                      : _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B7C99),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
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
