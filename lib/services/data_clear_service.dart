import 'package:hive_flutter/hive_flutter.dart';

class DataClearService {
  /// Clear all user-related data from local storage
  static Future<void> clearAllUserData() async {
    print('🧹 Starting complete data clear...');

    final boxesToClear = [
      'user_profile',
      'profile_data',
      'visited_countries',
      'country_data',
    ];

    for (final boxName in boxesToClear) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.clear();
          print('✅ Cleared: $boxName');
        } else {
          final box = await Hive.openBox(boxName);
          await box.clear();
          await box.close();
          print('✅ Cleared and closed: $boxName');
        }
      } catch (e) {
        print('⚠️ Error clearing $boxName: $e');
      }
    }

    print('✅ All data cleared!');
  }

  /// Clear only profile-related data (keep travel data)
  static Future<void> clearProfileDataOnly() async {
    print('🧹 Clearing profile data only...');

    final boxesToClear = ['user_profile', 'profile_data'];

    for (final boxName in boxesToClear) {
      try {
        if (Hive.isBoxOpen(boxName)) {
          final box = Hive.box(boxName);
          await box.clear();
          print('✅ Cleared: $boxName');
        } else {
          final box = await Hive.openBox(boxName);
          await box.clear();
          await box.close();
          print('✅ Cleared: $boxName');
        }
      } catch (e) {
        print('⚠️ Error clearing $boxName: $e');
      }
    }

    print('✅ Profile data cleared!');
  }
}
