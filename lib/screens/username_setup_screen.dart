import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'data_migration_screen.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _supabase = Supabase.instance.client;

  final _usernameController = TextEditingController();
  final _bioController = TextEditingController();

  String? _profilePicturePath;
  bool _isLoading = false;

  // Username checking
  Timer? _debounce;
  bool _isCheckingUsername = false;
  bool _isUsernameAvailable = false;
  String? _usernameError;

  // Session status message (e.g., when email is not confirmed, no session yet)
  String? _inlineNotice;

  @override
  void initState() {
    super.initState();
    _evaluateSessionStatus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _evaluateSessionStatus() async {
    // If there is no current user (e.g., email confirmation pending),
    // we inform the user and disable "Continue" until they log in.
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _inlineNotice =
            'No active session detected.\nIf you just signed up, please confirm your email, then log in. After login, return here to finish your profile.';
      });
    } else {
      setState(() => _inlineNotice = null);
    }
  }

  // ---------- Username validation & debounce check ----------
  String? _validateUsernameSync(String value) {
    if (value.isEmpty) return 'Username is required';
    if (value.length < 3) return 'Username must be at least 3 characters';
    if (value.length > 20) return 'Max 20 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Only letters, numbers and underscores';
    }
    return null;
  }

  Future<void> _checkUsername(String username) async {
    final err = _validateUsernameSync(username);
    if (err != null) {
      setState(() {
        _usernameError = err;
        _isUsernameAvailable = false;
      });
      return;
    }

    setState(() {
      _isCheckingUsername = true;
      _usernameError = null;
    });

    try {
      final ok = await AuthService.isUsernameAvailable(username);
      if (!mounted) return;
      setState(() {
        _isUsernameAvailable = ok;
        _usernameError = ok ? null : 'Username already taken';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _usernameError = 'Error checking username';
        _isUsernameAvailable = false;
      });
    } finally {
      if (mounted) setState(() => _isCheckingUsername = false);
    }
  }

  void _onUsernameChanged(String value) {
    // Debounce to reduce calls
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (value == _usernameController.text) {
        _checkUsername(value.trim());
      }
    });
  }

  // ---------- Image picking ----------
  Future<void> _pickProfilePicture() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          setState(() => _profilePicturePath = path);
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

  // ---------- Storage upload ----------
  Future<String?> _uploadProfilePictureIfAny(String? localPath) async {
    if (localPath == null || localPath.isEmpty) return null;

    final user = _supabase.auth.currentUser;
    if (user == null) {
      // no session; don’t attempt upload
      return null;
    }

    final file = File(localPath);
    if (!await file.exists()) return null;

    final ext = localPath.split('.').last.toLowerCase();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final objectPath = 'profile-pictures/${user.id}-$ts.$ext';

    // Upload to Storage bucket 'user-content'
    await _supabase.storage
        .from('user-content')
        .upload(
          objectPath,
          file,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
        );

    // Get a public URL (ensure storage policy allows SELECT)
    final publicUrl = _supabase.storage
        .from('user-content')
        .getPublicUrl(objectPath);
    return publicUrl;
  }

  // ---------- Continue (create profile) ----------
  Future<void> _continue() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      // Guard if no session (email not confirmed)
      setState(() {
        _inlineNotice =
            'No active session.\nConfirm your email and log in before creating your profile.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm your email, then log in to continue.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final uname = _usernameController.text.trim();
    final unameErr = _validateUsernameSync(uname);
    if (unameErr != null) {
      setState(() => _usernameError = unameErr);
      return;
    }
    if (!_isUsernameAvailable) {
      setState(() => _usernameError = 'Please choose an available username');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Upload picture (optional)
      String? picUrl;
      if (_profilePicturePath != null) {
        try {
          picUrl = await _uploadProfilePictureIfAny(_profilePicturePath);
        } catch (e) {
          // Non-fatal: continue without picture
          // ignore: avoid_print
          print('⚠️ Profile picture upload failed: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Profile picture upload failed, continuing without it.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }

      // Create profile row
      await AuthService.createUserProfile(
        username: uname,
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        profilePicUrl: picUrl,
      );

      if (!mounted) return;
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
    final brand = const Color(0xFF5B7C99);

    final canContinue =
        _supabase.auth.currentUser != null &&
        _isUsernameAvailable &&
        !_isLoading;

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
              const SizedBox(height: 20),

              if (_inlineNotice != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: brand.withOpacity(0.08),
                    border: Border.all(color: brand.withOpacity(0.25)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _inlineNotice!,
                    style: TextStyle(color: brand, fontSize: 13.5),
                  ),
                ),

              // Profile Picture
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _pickProfilePicture,
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                          border: Border.all(color: brand, width: 3),
                        ),
                        child: ClipOval(
                          child: _profilePicturePath != null
                              ? Image.file(
                                  File(_profilePicturePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.grey[400],
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 50,
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
                            color: brand,
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
                child: TextButton(
                  onPressed: _isLoading ? null : _pickProfilePicture,
                  child: Text(
                    'Tap to add profile picture',
                    style: TextStyle(color: brand, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'johndoe',
                  prefixText: '@',
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
                      : _isUsernameAvailable &&
                            _usernameController.text.isNotEmpty
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                ),
                onChanged: _onUsernameChanged,
              ),
              const SizedBox(height: 20),

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
                enabled: !_isLoading,
                maxLines: 3,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'Beach lover & foodie...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: canContinue ? _continue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brand,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
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
