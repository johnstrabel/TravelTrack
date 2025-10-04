import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  // Get current user
  static User? get currentUser => _supabase.auth.currentUser;

  static bool get isLoggedIn => currentUser != null;

  static String get currentUserId => currentUser?.id ?? 'local_user';

  // Sign up with email
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signUp(email: email, password: password);
  }

  // Sign in with email
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign out
  static Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Create user profile after signup
  static Future<void> createUserProfile({
    required String username,
    String? displayName,
    String? bio,
    String? profilePicUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    await _supabase.from('users').insert({
      'id': user.id,
      'email': user.email,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'profile_pic_url': profilePicUrl,
    });
  }

  // Get user profile
  static Future<AppUser?> getUserProfile(String userId) async {
    final response = await _supabase
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return AppUser.fromJson(response);
  }

  // Update user profile
  static Future<void> updateUserProfile({
    String? username,
    String? displayName,
    String? bio,
    String? profilePicUrl,
  }) async {
    final user = currentUser;
    if (user == null) throw Exception('No user logged in');

    final updates = <String, dynamic>{};
    if (username != null) updates['username'] = username;
    if (displayName != null) updates['display_name'] = displayName;
    if (bio != null) updates['bio'] = bio;
    if (profilePicUrl != null) updates['profile_pic_url'] = profilePicUrl;

    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      await _supabase.from('users').update(updates).eq('id', user.id);
    }
  }

  // Check if username is available
  static Future<bool> isUsernameAvailable(String username) async {
    final response = await _supabase
        .from('users')
        .select('username')
        .eq('username', username)
        .maybeSingle();

    return response == null;
  }
}
