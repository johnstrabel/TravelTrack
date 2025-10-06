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
    print('📝 AuthService.signUpWithEmail called');
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );
    print(
      '✅ Signup response - user: ${response.user?.id}, session: ${response.session != null}',
    );
    return response;
  }

  // Sign in with email
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    print('🔑 AuthService.signInWithEmail called');
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    print('✅ Login response - user: ${response.user?.id}');
    return response;
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

    print('👤 Creating profile for user: ${user.id}');
    print('   Username: $username');

    await _supabase.from('users').insert({
      'id': user.id,
      'email': user.email,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'profile_pic_url': profilePicUrl,
    });

    print('✅ Profile created successfully');
  }

  // Get user profile
  static Future<AppUser?> getUserProfile(String userId) async {
    print('🔍 getUserProfile called for userId: $userId');

    try {
      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      print('📊 Database query response:');
      print('   Response type: ${response.runtimeType}');
      print('   Response value: $response');

      if (response == null) {
        print('❌ No profile found in database (response is null)');
        return null;
      }

      print('🔄 Attempting to parse AppUser from JSON...');
      final profile = AppUser.fromJson(response);
      print('✅ Profile parsed successfully:');
      print('   ID: ${profile.id}');
      print('   Email: ${profile.email}');
      print('   Username: "${profile.username}"');
      print('   Display Name: ${profile.displayName}');

      return profile;
    } catch (e, stackTrace) {
      print('❌ Error in getUserProfile:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      rethrow;
    }
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
