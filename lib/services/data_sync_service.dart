import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/country_visit.dart';
import 'auth_service.dart';

class DataSyncService {
  static final _supabase = Supabase.instance.client;

  /// Sync all local Hive data to Supabase
  static Future<void> syncLocalDataToCloud() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    // Get local visited countries
    final visitedBox = Hive.box('visited_countries');
    final codes = visitedBox.get('codes');

    Set<String> visitedCodes = {};
    if (codes is List) {
      visitedCodes = codes.whereType<String>().toSet();
    } else if (codes is Set) {
      visitedCodes = codes.cast<String>();
    }

    // Get country data
    final countryDataBox = await Hive.openBox('country_data');

    for (final countryCode in visitedCodes) {
      final countryData = countryDataBox.get(countryCode) as Map?;
      if (countryData == null) continue;

      // Convert local data to CountryVisit model
      final visit = CountryVisit(
        userId: userId,
        countryCode: countryCode,
        mustSees: countryData['mustSees'] as String?,
        hiddenGems: countryData['hiddenGems'] as String?,
        restaurants: countryData['restaurants'] as String?,
        bars: countryData['bars'] as String?,
        photos: _convertPhotos(countryData['photos']),
        cities: (countryData['cities'] as List?)?.cast<String>() ?? [],
        rating: countryData['rating'] as int? ?? 0,
        visitedDate: countryData['visitedDate'] != null
            ? DateTime.tryParse(countryData['visitedDate'] as String)
            : null,
        dailyEntries: _convertDailyEntries(countryData['dailyEntries']),
        isPublic: false, // Default to private initially
      );

      // Upload to Supabase
      await _supabase.from('country_visits').upsert(visit.toJson());
    }
  }

  /// Pull cloud data and merge with local
  static Future<void> syncCloudDataToLocal() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Fetch user's country visits from Supabase
    final response = await _supabase
        .from('country_visits')
        .select()
        .eq('user_id', userId);

    final visits = (response as List)
        .map((json) => CountryVisit.fromJson(json))
        .toList();

    // Update local Hive storage
    final visitedBox = Hive.box('visited_countries');
    final countryDataBox = await Hive.openBox('country_data');

    final Set<String> codes = {};

    for (final visit in visits) {
      codes.add(visit.countryCode);

      // Store country data locally
      await countryDataBox.put(visit.countryCode, visit.toHiveJson());
    }

    // Update visited codes
    await visitedBox.put('codes', codes.toList());
  }

  /// Sync a single country visit to cloud
  static Future<void> syncCountryToCloud(String countryCode) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final countryDataBox = await Hive.openBox('country_data');
    final countryData = countryDataBox.get(countryCode) as Map?;
    if (countryData == null) return;

    final visit = CountryVisit(
      userId: userId,
      countryCode: countryCode,
      mustSees: countryData['mustSees'] as String?,
      hiddenGems: countryData['hiddenGems'] as String?,
      restaurants: countryData['restaurants'] as String?,
      bars: countryData['bars'] as String?,
      photos: _convertPhotos(countryData['photos']),
      cities: (countryData['cities'] as List?)?.cast<String>() ?? [],
      rating: countryData['rating'] as int? ?? 0,
      visitedDate: countryData['visitedDate'] != null
          ? DateTime.tryParse(countryData['visitedDate'] as String)
          : null,
      dailyEntries: _convertDailyEntries(countryData['dailyEntries']),
      isPublic: false,
    );

    await _supabase.from('country_visits').upsert(visit.toJson());
  }

  /// Delete country visit from cloud
  static Future<void> deleteCountryFromCloud(String countryCode) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('country_visits')
        .delete()
        .eq('user_id', userId)
        .eq('country_code', countryCode);
  }

  // Helper methods
  static List<PhotoWithCaption> _convertPhotos(dynamic photos) {
    if (photos is! List) return [];

    return photos.map((item) {
      if (item is Map) {
        return PhotoWithCaption(
          path: item['path'] as String? ?? '',
          caption: item['caption'] as String? ?? '',
          url: item['url'] as String?,
          isPublic: item['isPublic'] as bool? ?? false,
        );
      } else if (item is String) {
        // Legacy format: just path string
        return PhotoWithCaption(path: item, caption: '');
      }
      return PhotoWithCaption(path: '', caption: '');
    }).toList();
  }

  static List<DailyEntry> _convertDailyEntries(dynamic entries) {
    if (entries is! List) return [];

    return entries
        .map((item) {
          if (item is Map) {
            return DailyEntry(
              date: item['date'] as String? ?? '',
              text: item['text'] as String? ?? '',
            );
          }
          return DailyEntry(date: '', text: '');
        })
        .where((e) => e.date.isNotEmpty)
        .toList();
  }
}
